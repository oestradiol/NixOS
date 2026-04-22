#!/usr/bin/env bash
# Static: storage-layout.nix filesystem generation verification.
# Note: Individual storage options are not in eval-cache; we test generated outputs.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "filesystem configuration generation"

# Check that fileSystems are generated for enabled test users
# Users are profile-specific; test based on which users exist in the eval

# Get list of enabled users from cache
enabled_users=$(nix_eval 'myOS.users.__names' | jq_cmd -r '.[]' 2>/dev/null || true)

for user in $enabled_users; do
  home_fs=$(nix_eval "fileSystems./home/${user}.fsType")
  home_persistent=$(nix_eval "myOS.users.${user}.home.persistent")
  
  if [[ "$home_fs" == "null" ]]; then
    info "User $user: no home filesystem configured (may use default)"
    continue
  fi
  
  if [[ "$home_persistent" == "true" ]]; then
    assert_eq "$home_fs" '"btrfs"' "User $user (persistent) gets btrfs home"
    home_opts=$(nix_eval "fileSystems./home/${user}.options")
    if [[ "$home_opts" == *"subvol="* && "$home_opts" == *"compress=zstd"* ]]; then
      pass "User $user btrfs has subvol and zstd compression"
    else
      fail "User $user btrfs missing expected options" "$home_opts"
    fi
  else
    assert_eq "$home_fs" '"tmpfs"' "User $user (non-persistent) gets tmpfs home"
    home_opts=$(nix_eval "fileSystems./home/${user}.options")
    if [[ "$home_opts" == *"size="* && "$home_opts" == *"mode=700"* ]]; then
      pass "User $user tmpfs has size and mode=700"
    else
      fail "User $user tmpfs missing expected options" "$home_opts"
    fi
  fi
done

describe "root filesystem type"

root_fs=$(nix_eval 'fileSystems./.fsType')
assert_eq "$root_fs" '"tmpfs"' "root (/) filesystem is tmpfs by default"

root_opts=$(nix_eval 'fileSystems./.options')
if [[ "$root_opts" == *"mode=755"* && "$root_opts" == *"size="* ]]; then
  pass "root tmpfs has mode=755 and size"
else
  fail "root tmpfs missing expected options" "$root_opts"
fi

describe "nix and persist filesystems"

nix_fs=$(nix_eval 'fileSystems./nix.fsType')
assert_eq "$nix_fs" '"btrfs"' "/nix is btrfs"

persist_fs=$(nix_eval 'fileSystems./persist.fsType')
assert_eq "$persist_fs" '"btrfs"' "/persist is btrfs"

describe "swap conditional filesystem"

# When swap is disabled (default), /swap should not exist as a fileSystem
swap_fs=$(nix_eval 'fileSystems./swap.fsType')
if [[ "$swap_fs" == "null" ]]; then
  pass "swap filesystem is null when swap.disabled (default)"
else
  info "swap filesystem present (may be enabled in test config): $swap_fs"
fi

describe "home backing store for tmpfs users"

# Check backing stores for tmpfs-enabled users
for user in $enabled_users; do
  home_persistent=$(nix_eval "myOS.users.${user}.home.persistent")
  if [[ "$home_persistent" == "false" ]]; then
    # User has tmpfs home, check for backing store
    backing_path="/persist/home/${user}"
    backing_fs=$(nix_eval "fileSystems.\"${backing_path}\".fsType")
    if [[ "$backing_fs" == "null" ]]; then
      info "User $user: backing store not at $backing_path (may use different persist root)"
    else
      assert_eq "$backing_fs" '"btrfs"' "User $user tmpfs backing store is btrfs"
    fi
  fi
done
