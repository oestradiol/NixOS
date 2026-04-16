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

profile=$(detect_profile)
describe "per-profile home mounts (detected: $profile)"
if [[ "$profile" == "daily" ]]; then
  assert_mountpoint /home/player     "daily: /home/player mounted"
  check_subvol /home/player @home-daily
  assert_not_mountpoint /home/ghost  "daily: /home/ghost NOT mounted"
  assert_not_mountpoint /persist/home/ghost "daily: /persist/home/ghost NOT mounted"

  describe "daily swap subvolume + swapfile"
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
    fail "/swap not mounted on daily"
  fi

  describe "zram present (shared with swapfile)"
  if awk '{print $1}' /proc/swaps | grep -q '^/dev/zram'; then
    pass "zram swap active"
  else
    fail "zram swap not active"
  fi
else
  assert_mountpoint /home/ghost            "paranoid: /home/ghost mounted (tmpfs)"
  gfs=$(findmnt -n -o FSTYPE /home/ghost 2>/dev/null || true)
  assert_eq "$gfs" "tmpfs" "/home/ghost type = tmpfs"
  assert_mountpoint /persist/home/ghost    "paranoid: /persist/home/ghost mounted"
  check_subvol /persist/home/ghost @home-paranoid
  assert_not_mountpoint /home/player       "paranoid: /home/player NOT mounted"
  assert_not_mountpoint /swap              "paranoid: /swap NOT mounted"
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
