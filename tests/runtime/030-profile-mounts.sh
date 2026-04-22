#!/usr/bin/env bash
# Runtime: profile-mount-invariants.service must have succeeded, and the
# invariants it checks must still hold.
# Template-agnostic: discovers users from myOS.users config.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "profile-mount-invariants.service status"
# oneshot + RemainAfterExit → `active (exited)` when successful.
if systemctl is-active --quiet profile-mount-invariants.service; then
  pass "profile-mount-invariants.service is active"
else
  state=$(systemctl is-active profile-mount-invariants.service 2>&1 || true)
  fail "profile-mount-invariants.service state: $state" \
    "$(systemctl status profile-mount-invariants.service --no-pager -l 2>&1 | head -20)"
fi
assert_unit_enabled profile-mount-invariants.service

# Discover users from the running system (template-agnostic)
profile=$(detect_profile)
mapfile -t system_users < <(detect_system_users)

if [[ ${#system_users[@]} -eq 0 ]]; then
  fail "no users found on system"
  exit 1
fi

# For active users, check who has their home mounted (actual runtime state)
active_users=()
for u in "${system_users[@]}"; do
  if mountpoint -q "/home/$u" 2>/dev/null; then
    active_users+=("$u")
  fi
done

# For inactive users, check config users that are NOT active on this profile
# These are users defined in config but their homes should NOT be mounted
inactive_users=()
user_names_json=$(config_value "myOS.users.__names")
if [[ "$user_names_json" != "null" && "$user_names_json" != "[]" ]]; then
  mapfile -t config_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
  for u in "${config_users[@]}"; do
    active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
    if [[ "$active" != "true" ]]; then
      inactive_users+=("$u")
    fi
  done
fi

describe "invariant predicates: active user homes mounted"
for u in "${active_users[@]}"; do
  assert_mountpoint "/home/$u" "$profile: /home/$u mounted"
done

describe "invariant predicates: inactive user homes NOT mounted"
for u in "${inactive_users[@]}"; do
  assert_not_mountpoint "/home/$u" "$profile: /home/$u NOT mounted"
done

describe "invariant predicates: inactive user persist homes NOT mounted"
for u in "${inactive_users[@]}"; do
  assert_not_mountpoint "/persist/home/$u" "$profile: /persist/home/$u NOT mounted"
done

describe "cross-profile home paths cleanly absent from /proc/self/mounts"
# Check that inactive user homes are not mounted as filesystem mountpoints.
for u in "${inactive_users[@]}"; do
  if awk -v home="/home/$u" '$2 == home {found=1} END {exit !found}' /proc/self/mounts; then
    fail "$profile profile leaks a /home/$u mount into /proc/self/mounts"
  else
    pass "no /home/$u mount on $profile"
  fi
done
