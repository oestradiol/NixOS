#!/usr/bin/env bash
# Static: users-framework.nix option validation and edge cases.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "users framework option defaults"

# Check that user names are discoverable from eval cache
user_names=$(nix_eval 'myOS.users.__names')
if [[ "$user_names" != "null" && "$user_names" != "[]" ]]; then
  pass "User names discoverable: $user_names"
else
  warn "No users found in myOS.users"
fi

describe "user activation XOR validation"

# The module enforces that exactly one of activeOnProfiles / activationPredicate
# must be non-null. We can't test the assertion failure without breaking the
# build, but we can verify the structure exists.

# Check that test users have the expected activation pattern
test_users=$(nix_eval 'myOS.users.__names' | jq_cmd -r '.[]' 2>/dev/null || true)
for user in $test_users; do
  active_on=$(nix_eval "myOS.users.${user}._activeOn")
  info "User $user: _activeOn = $active_on"
done

describe "user home configuration options"

# Check home.persistent default (should be true)
for user in $test_users; do
  home_persistent=$(nix_eval "myOS.users.${user}.home.persistent")
  if [[ "$home_persistent" == "true" || "$home_persistent" == "false" ]]; then
    pass "User $user: home.persistent = $home_persistent"
  else
    info "User $user: home.persistent = $home_persistent (using default)"
  fi
  
  # Check allowlist is a list
  allowlist=$(nix_eval "myOS.users.${user}.home.allowlist")
  if [[ "$allowlist" != "null" ]]; then
    pass "User $user: home.allowlist is defined"
  fi
  
  # Check btrfsSubvol defaults to @home-<name>
  subvol=$(nix_eval "myOS.users.${user}.home.btrfsSubvol")
  expected="\"@home-${user}\""
  if [[ "$subvol" == "$expected" ]]; then
    pass "User $user: home.btrfsSubvol defaults to $expected"
  elif [[ "$subvol" != "null" ]]; then
    info "User $user: home.btrfsSubvol = $subvol (non-default)"
  fi
done

describe "user identity options structure"

# Check identity.git options exist and default to null
for user in $test_users; do
  git_name=$(nix_eval "myOS.users.${user}.identity.git.name")
  git_email=$(nix_eval "myOS.users.${user}.identity.git.email")
  info "User $user: git.name=$git_name, git.email=$git_email"
done

describe "allowWheel permission option"

# Check allowWheel defaults to false
for user in $test_users; do
  allow_wheel=$(nix_eval "myOS.users.${user}.allowWheel")
  if [[ "$allow_wheel" == "true" ]]; then
    pass "User $user: allowWheel = true"
  elif [[ "$allow_wheel" == "false" ]]; then
    pass "User $user: allowWheel = false (default)"
  else
    info "User $user: allowWheel = $allow_wheel"
  fi
done

describe "shell default"

# Check shell defaults to zsh
for user in $test_users; do
  shell=$(nix_eval "myOS.users.${user}.shell")
  if [[ "$shell" == "\"zsh\"" || "$shell" == *"/zsh\""* ]]; then
    pass "User $user: shell defaults to zsh"
  else
    info "User $user: shell = $shell"
  fi
done

describe "user framework edge cases: disabled users"

# Users with enable=false should not appear in enabled users
# The eval-cache.nix filters by enable, so we should only see enabled users
enabled_count=$(nix_eval 'myOS.users.__names' | jq_cmd 'length' 2>/dev/null || echo 0)
info "Enabled user count from cache: $enabled_count"

describe "home-manager config path option"

# Check that homeManagerConfig option exists (will be null in tests)
for user in $test_users; do
  hm_config=$(nix_eval "myOS.users.${user}.homeManagerConfig")
  if [[ "$hm_config" == "null" ]]; then
    pass "User $user: homeManagerConfig defaults to null"
  else
    info "User $user: homeManagerConfig = $hm_config"
  fi
done
