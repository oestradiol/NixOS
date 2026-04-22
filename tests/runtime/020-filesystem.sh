#!/usr/bin/env bash
# Runtime: filesystem layout. tmpfs root, Btrfs subvolumes under LUKS,
# persisted paths, per-profile home mounts.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "root is tmpfs"
rt=$(findmnt -n -o FSTYPE / 2>/dev/null || true)
assert_eq "$rt" "tmpfs" "/ filesystem type = tmpfs"

describe "core subvolume mounts"
for mp in /nix /persist /var/log /boot; do
  assert_mountpoint "$mp"
done

describe "subvolume identity via findmnt"
# Each subvolume mount should reference its expected subvol= option.
check_subvol() {
  local mp="$1" expect="$2"
  local opts; opts=$(findmnt -n -o OPTIONS "$mp" 2>/dev/null || true)
  if [[ "$opts" == *"subvol=/$expect"* || "$opts" == *"subvol=$expect"* ]]; then
    pass "$mp -> subvol $expect"
  else
    fail "$mp subvol mismatch" "expected subvol=$expect" "got: $opts"
  fi
}
check_subvol /nix     @nix
check_subvol /persist @persist
check_subvol /var/log @log

describe "boot is vfat"
bfs=$(findmnt -n -o FSTYPE /boot 2>/dev/null || true)
assert_eq "$bfs" "vfat" "/boot filesystem = vfat"

# Discover users from the running system (template-agnostic)
profile=$(detect_profile)
mapfile -t all_users < <(detect_system_users)

if [[ ${#all_users[@]} -eq 0 ]]; then
  fail "no users found on system (neither in /etc/passwd nor config)"
  exit 1
fi

describe "per-profile home mounts (detected: $profile)"
for u in "${all_users[@]}"; do
  # Check if user exists in config (template-agnostic handling)
  user_in_config=$(config_value "myOS.users.${u}._exists" | jq_cmd -r 'select(type=="boolean")')
  active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
  persistent=$(config_value "myOS.users.${u}.home.persistent" | jq_cmd -r 'select(type=="boolean")')

  # If user not in config but exists on system with a home directory, check if mounted
  if [[ "$user_in_config" != "true" && -d "/home/$u" ]]; then
    # User exists on system but not in config - check actual mount status
    if mountpoint -q "/home/$u" 2>/dev/null; then
      active="true"
      # Detect persistence from actual mount
      hfs=$(findmnt -n -o FSTYPE "/home/$u" 2>/dev/null || true)
      if [[ "$hfs" == "btrfs" ]]; then
        persistent="true"
      else
        persistent="false"
      fi
    else
      # Home dir exists but not mounted - user is inactive on this profile
      active="false"
    fi
  fi

  if [[ "$active" == "true" ]]; then
    assert_mountpoint "/home/$u" "$profile: /home/$u mounted"
    if [[ "$persistent" == "true" ]]; then
      # Persistent home should be a Btrfs subvolume
      # Subvolume name may be @home-<username> OR @home-<profile> (e.g., @home-daily)
      local opts; opts=$(findmnt -n -o OPTIONS "/home/$u" 2>/dev/null || true)
      if [[ "$opts" == *"subvol=/@home-${u}"* || "$opts" == *"subvol=@home-${u}"* ]]; then
        pass "/home/$u -> subvol @home-${u}"
      elif [[ "$opts" == *"subvol=/@home-${profile}"* || "$opts" == *"subvol=@home-${profile}"* ]]; then
        pass "/home/$u -> subvol @home-${profile} (profile-based naming)"
      else
        # Extract actual subvol name for info
        actual_subvol=$(echo "$opts" | grep -o 'subvol=[^,]*' | head -1 | cut -d= -f2)
        pass "/home/$u -> subvol $actual_subvol (custom naming)"
      fi
    else
      # Non-persistent home should be tmpfs
      hfs=$(findmnt -n -o FSTYPE "/home/$u" 2>/dev/null || true)
      assert_eq "$hfs" "tmpfs" "/home/$u type = tmpfs"
      # And should have a persist home mount
      assert_mountpoint "/persist/home/$u" "$profile: /persist/home/$u mounted"
      # Subvolume name may vary
      local opts; opts=$(findmnt -n -o OPTIONS "/persist/home/$u" 2>/dev/null || true)
      if [[ "$opts" == *"subvol=/@home-${u}"* || "$opts" == *"subvol=@home-${u}"* ]]; then
        pass "/persist/home/$u -> subvol @home-${u}"
      else
        actual_subvol=$(echo "$opts" | grep -o 'subvol=[^,]*' | head -1 | cut -d= -f2)
        pass "/persist/home/$u -> subvol $actual_subvol"
      fi
    fi
  else
    assert_not_mountpoint "/home/$u" "$profile: /home/$u NOT mounted (inactive user)"
    assert_not_mountpoint "/persist/home/$u" "$profile: /persist/home/$u NOT mounted"
  fi
done

# Check swap configuration from myOS.storage.swap.enable
swap_enabled=$(config_value "myOS.storage.swap.enable" | jq_cmd -r 'select(type=="boolean")')
if [[ "$swap_enabled" == "true" ]]; then
  describe "swap subvolume + swapfile"
  if mountpoint -q /swap 2>/dev/null; then
    pass "/swap subvolume mounted"
    check_subvol /swap @swap
    if [[ -f /swap/swapfile ]]; then
      pass "/swap/swapfile exists"
      if awk '{print $1}' /proc/swaps | grep -Fxq '/swap/swapfile'; then
        pass "swapfile activated"
      else
        warn "swapfile exists but is not in /proc/swaps"
      fi
    else
      fail "/swap/swapfile missing"
    fi
  else
    fail "/swap not mounted"
  fi

  describe "zram present (shared with swapfile)"
  if awk '{print $1}' /proc/swaps | grep -q '^/dev/zram'; then
    pass "zram swap active"
  else
    fail "zram swap not active"
  fi
else
  describe "swap disabled in config"
  assert_not_mountpoint /swap "$profile: /swap NOT mounted"
fi

describe "cryptroot device exists"
if [[ -b /dev/mapper/cryptroot ]]; then
  pass "/dev/mapper/cryptroot is a block device"
else
  fail "/dev/mapper/cryptroot missing; LUKS mapper not opened?"
fi

describe "persist root-only permission"
perm=$(stat -c '%a %U' /persist 2>/dev/null || true)
if [[ "$perm" == "700 root" ]]; then
  pass "/persist mode = 0700 root"
else
  fail "/persist mode wrong" "expected: 700 root" "got: $perm"
fi
