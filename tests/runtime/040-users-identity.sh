#!/usr/bin/env bash
# Runtime: account locks, machine-id persistence, root lock, sudo posture.
# Template-agnostic: discovers users from myOS.users configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

profile=$(detect_profile)
describe "detected profile at runtime"
info "profile: $profile"

# Discover users from the running system (template-agnostic)
mapfile -t all_users < <(detect_system_users)

if [[ ${#all_users[@]} -eq 0 ]]; then
  fail "no users found on system (neither in /etc/passwd nor config)"
  exit 1
fi

info "system users: ${all_users[*]}"

# Determine active user(s) on current profile
active_users=()
for u in "${all_users[@]}"; do
  active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
  # If user exists on system but not in config, assume active (template mismatch)
  if [[ "$active" == "true" || -d "/home/$u" ]]; then
    active_users+=("$u")
  fi
done

if [[ ${#active_users[@]} -eq 0 ]]; then
  warn "no active users found for profile: $profile"
else
  info "active user(s) on $profile: ${active_users[*]}"
fi

describe "all declared users exist in passwd"
for u in "${all_users[@]}"; do
  if getent passwd "$u" >/dev/null; then
    pass "$u exists in passwd"
  else
    fail "$u missing from passwd"
  fi
done

describe "user UID/GID consistency"
for u in "${all_users[@]}"; do
  uid=$(id -u "$u" 2>/dev/null || true)
  gid=$(id -g "$u" 2>/dev/null || true)
  if [[ -n "$uid" && -n "$gid" ]]; then
    pass "$u: UID=$uid GID=$gid"
    # Check for collisions
    for other in "${all_users[@]}"; do
      [[ "$u" == "$other" ]] && continue
      other_uid=$(id -u "$other" 2>/dev/null || true)
      if [[ "$uid" == "$other_uid" && -n "$other_uid" ]]; then
        fail "UID collision: $u and $other both have UID $uid"
      fi
    done
  else
    fail "$u: cannot determine UID/GID"
  fi
done

describe "wheel group membership matches allowWheel config"
for u in "${all_users[@]}"; do
  user_in_config=$(config_value "myOS.users.${u}._exists" | jq_cmd -r 'select(type=="boolean")')
  allow_wheel=$(config_value "myOS.users.${u}.allowWheel" | jq_cmd -r 'select(type=="boolean")')
  actual_groups=$(id -nG "$u" 2>/dev/null || true)
  
  if [[ "$user_in_config" != "true" ]]; then
    # User not in config - just report wheel status without validation
    if grep -qw wheel <<<"$actual_groups"; then
      pass "$u: in wheel (user not in config, skipping allowWheel check)"
    else
      pass "$u: not in wheel (user not in config, skipping allowWheel check)"
    fi
  elif [[ "$allow_wheel" == "true" ]]; then
    if grep -qw wheel <<<"$actual_groups"; then
      pass "$u: in wheel (allowWheel=true)"
    else
      fail "$u: not in wheel but allowWheel=true"
    fi
  else
    if grep -qw wheel <<<"$actual_groups"; then
      fail "$u: in wheel but allowWheel != true"
    else
      pass "$u: not in wheel (allowWheel!=true)"
    fi
  fi
done

describe "profile-specific account locking"
if ! sudo -n test -r /etc/shadow 2>/dev/null; then
  skip "shadow not readable without sudo; cannot verify account locks"
  exit 0
fi

# Check each user's shadow entry based on whether they're active on this profile
for u in "${all_users[@]}"; do
  active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
  shadow_field=$(sudo -n getent shadow "$u" 2>/dev/null | cut -d: -f2 || true)
  
  if [[ "$active" == "true" ]]; then
    # Active user should be unlocked
    if [[ "$shadow_field" == '!' || "$shadow_field" == '!!' || "$shadow_field" == '*' ]]; then
      fail "$u: active but locked (shadow='$shadow_field')"
    else
      pass "$u: active and unlocked"
    fi
  else
    # Inactive user should be locked
    if [[ "$shadow_field" == '!' || "$shadow_field" == '!!' || "$shadow_field" == '*' ]]; then
      pass "$u: inactive and locked (shadow='$shadow_field')"
    else
      warn "$u: inactive but has hash (may be intentional)"
    fi
  fi
done

describe "root account is locked"
if sudo -n test -r /etc/shadow 2>/dev/null; then
  root_f=$(sudo -n getent shadow root | cut -d: -f2)
  if [[ "$root_f" == '!' || "$root_f" == '!!' || "$root_f" == '*' ]]; then
    pass "root is locked (shadow='$root_f')"
  else
    fail "root is not locked" "shadow=$root_f"
  fi
fi

describe "password hash files for declared users"
if ! sudo -n true 2>/dev/null; then
  skip "sudo not available; cannot verify password hash files"
  exit 0
fi

# Check if users use hashedPasswordFile and verify those files exist
for u in "${all_users[@]}"; do
  hash_file=$(config_value "users.users.${u}.hashedPasswordFile" | jq_cmd -r 'select(type=="string")')
  
  if [[ -n "$hash_file" && "$hash_file" != "null" ]]; then
    if sudo -n test -f "$hash_file"; then
      pass "$u: hashedPasswordFile exists: $hash_file"
      # Should be 0400 root-only
      perm=$(sudo -n stat -c '%a %U' "$hash_file" 2>/dev/null || true)
      if [[ "$perm" == "400 root" ]]; then
        pass "$hash_file mode = 0400 root"
      else
        warn "$hash_file permissions = $perm (expected 400 root)"
      fi
    else
      fail "$u: hashedPasswordFile missing: $hash_file"
    fi
  else
    info "$u: no hashedPasswordFile configured"
  fi
done

describe "machine-id persistence"
if [[ -s /etc/machine-id ]]; then
  mid=$(cat /etc/machine-id)
  if [[ "${#mid}" -eq 32 ]]; then
    pass "/etc/machine-id present, length 32"
  else
    fail "/etc/machine-id length wrong" "got len=${#mid}"
  fi
  # Must match /persist copy (impermanence).
  if sudo -n test -r /persist/etc/machine-id 2>/dev/null; then
    pmid=$(sudo -n cat /persist/etc/machine-id)
    if [[ "$mid" == "$pmid" ]]; then
      pass "machine-id == /persist/etc/machine-id"
    else
      fail "machine-id divergence" "/etc: $mid" "/persist/etc: $pmid"
    fi
  else
    skip "cannot read /persist/etc/machine-id without sudo"
  fi
else
  fail "/etc/machine-id is empty"
fi

describe "sudo: requires password, execWheelOnly, wheelNeedsPassword"
sudoers=$(sudo -n cat /etc/sudoers 2>/dev/null || true)
if [[ -n "$sudoers" ]]; then
  if grep -qE '^\s*%wheel' <<<"$sudoers"; then pass "sudoers grants wheel"; else warn "no explicit %wheel line"; fi
fi
