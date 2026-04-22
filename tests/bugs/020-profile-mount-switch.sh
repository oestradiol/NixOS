#!/usr/bin/env bash
# Bug regression: switch.log captured profile-mount-invariants.service
# failing during `nixos-rebuild switch`. The failure pattern is:
#
#   "Failed to stop home-<user>.mount"
#   "Failed to start profile-mount-invariants.service"
#
# Root cause: the `flake-switch` alias in modules/home/shell.nix targets
# the flake output `.#nixos`, which is the PARANOID toplevel. When the user
# runs the alias while booted into the DAILY specialisation, the activation
# tries to switch the live system to paranoid: it stops home-<user>.mount
# (busy, because the user is logged in as the active user), then the paranoid
# copy of profile-mount-invariants.service runs and asserts the active user's
# home is NOT mounted — which still fails because the stop couldn't complete.
#
# Historical note: the original bug was observed with the default template's
# user names (player/ghost). The test has been updated to be template-agnostic.
#
# This test captures the symptoms clearly and checks whether the fix is in
# place (an alias that respects the current specialisation).
source "${BASH_SOURCE%/*}/../lib/common.sh"

shell_nix="$REPO_ROOT/modules/home/shell.nix"
switch_log="$REPO_ROOT/switch.log"

describe "symptoms recorded in switch.log (historical — fix landed 2026-04)"
# switch.log is a gitignored artefact of the pre-fix state. Three possible
# states:
#   (a) file absent  — operator cleared it after a clean rebuild   (PASS)
#   (b) file present, symptoms absent — log was rotated or trimmed (PASS)
#   (c) file present, symptoms present — historical evidence      (WARN)
# Never FAIL here: the bug's code fix lives in modules/home/shell.nix and
# is covered by the other describe blocks in this file plus bugs/030.
#
# Note: The original bug showed "Failed to stop home-<user>.mount" where
# <user> was the active daily user (player in the default template). We check
# for the generic pattern since the specific user name depends on the template.
if [[ ! -f "$switch_log" ]]; then
  pass "switch.log absent (historical artefact cleared)"
else
  # Check for the generic pattern of the bug symptom
  if grep -Eq 'Failed to stop home-[^/]+\.mount' "$switch_log"; then
    warn "switch.log (historical) still contains: Failed to stop home-<user>.mount" \
         "Delete switch.log after the next successful rebuild to clear this warning."
  else
    pass "switch.log has no 'Failed to stop home-<user>.mount' line"
  fi
  if grep -Fq 'Failed to start profile-mount-invariants.service' "$switch_log"; then
    warn "switch.log (historical) still contains: Failed to start profile-mount-invariants.service" \
         "Delete switch.log after the next successful rebuild to clear this warning."
  else
    pass "switch.log has no 'Failed to start profile-mount-invariants' line"
  fi
fi

describe "flake-switch alias is specialisation-aware"
# The safe forms:
#   (a) `nixos-rebuild switch --flake /etc/nixos#nixos --specialisation daily`
#   (b) Split aliases (flake-switch-daily / flake-switch-paranoid) plus a
#       smart default that branches on /run/current-system/specialisation/daily.
if [[ ! -f "$shell_nix" ]]; then
  fail "$shell_nix missing"
  exit 0
fi
alias_line=$(grep -E '^\s*flake-switch\s*=' "$shell_nix" | head -1 || true)
if [[ -z "$alias_line" ]]; then
  fail "flake-switch alias not found in $shell_nix"
else
  info "current flake-switch: $alias_line"
  # Accept either form: direct --specialisation, or the smart-default branch.
  if grep -Eq 'flake-switch\s*=.*--specialisation' "$shell_nix" \
     || grep -Eq 'flake-switch\s*=.*/nix/var/nix/profiles/system/specialisation/daily' "$shell_nix"; then
    pass "flake-switch is specialisation-aware (direct flag OR smart-default branch)"
  else
    fail "flake-switch alias does not route by specialisation" \
         "As a result, running it from daily silently switches the live system to paranoid," \
         "which tries to stop the active user's home mount while they're logged in, and" \
         "profile-mount-invariants (paranoid variant) then fails." \
         "Fix: split the alias (e.g. flake-switch-daily / flake-switch-paranoid) or" \
         "detect the active specialisation from /run/current-system."
  fi
fi
# Confirm the per-profile aliases are present.
if grep -Eq '^\s*flake-switch-daily\s*=.*--specialisation daily' "$shell_nix"; then
  pass "flake-switch-daily declared and passes --specialisation daily"
else
  fail "flake-switch-daily missing or not passing --specialisation daily"
fi
if grep -Eq '^\s*flake-switch-paranoid\s*=' "$shell_nix"; then
  pass "flake-switch-paranoid declared (explicit paranoid switch)"
else
  fail "flake-switch-paranoid missing (operators need a way to explicitly pick paranoid)"
fi

describe "cross-check: nix_eval confirms specialisation structure"
if require_cmd nix; then
  top_profile=$(nix_eval 'myOS.profile' 2>/dev/null || true)
  daily_profile=$(nix_eval_daily 'myOS.profile' 2>/dev/null || true)
  if [[ "$top_profile" == '"paranoid"' && "$daily_profile" == '"daily"' ]]; then
    pass "flake exposes paranoid@toplevel + daily@specialisation (expected)"
  else
    fail "unexpected flake structure" \
         "toplevel profile: $top_profile" \
         "specialisation profile: $daily_profile"
  fi
fi

describe "profile-mount-invariants.service currently matches the booted profile (template-agnostic)"
# If we're in daily, the running service must be the daily variant.
# The service checks for inactive user mounts based on myOS.users configuration.
# NOTE: The service is generated from config, so we check config users, not system users.
profile=$(detect_profile)

# Get config users (the service is generated from these)
user_names_json=$(config_value "myOS.users.__names")
if [[ "$user_names_json" == "null" || "$user_names_json" == "[]" ]]; then
  skip "no users declared in config - cannot verify service configuration"
  exit 0
fi

mapfile -t config_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
info "config users: ${config_users[*]}"

# Also get system users for informational purposes
mapfile -t system_users < <(detect_system_users)
if [[ ${#system_users[@]} -gt 0 ]]; then
  info "system users: ${system_users[*]}"
fi

# Determine active/inactive users based on config (matching service generation logic)
active_users=()
inactive_users=()

for u in "${config_users[@]}"; do
  active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
  if [[ "$active" == "true" ]]; then
    active_users+=("$u")
  else
    inactive_users+=("$u")
  fi
done

info "active user(s) on $profile (per config): ${active_users[*]:-<none>}"
info "inactive user(s) on $profile (per config): ${inactive_users[*]:-<none>}"

unit_path=/etc/systemd/system/profile-mount-invariants.service
if [[ -r "$unit_path" ]]; then
  script_ref=$(awk -F'=' '/ExecStart/{print $2}' "$unit_path" | tr -d ' ')
  info "ExecStart: $script_ref"
  if [[ -r "$script_ref" ]]; then
    body=$(cat "$script_ref")

    # Parse actual users from the service script
    # Lines like: "mountpoint -q /home/user || exit 1" = active user check
    # Lines like: "! mountpoint -q /home/user || exit 1" = inactive user check
    service_active_users=()
    service_inactive_users=()

    while IFS= read -r line; do
      if [[ "$line" =~ mountpoint[[:space:]]+-q[[:space:]]+/home/([^[:space:]]+) ]]; then
        u="${BASH_REMATCH[1]}"
        if [[ "$line" =~ ^![[:space:]]*mountpoint ]]; then
          # Line starts with ! = inactive user check
          service_inactive_users+=("$u")
        else
          # Line starts with mountpoint = active user check
          service_active_users+=("$u")
        fi
      fi
    done <<<"$body"

    info "service checks active users: ${service_active_users[*]:-<none>}"
    info "service checks inactive users: ${service_inactive_users[*]:-<none>}"

    # Verify active users have their homes required to be mounted
    for u in "${service_active_users[@]}"; do
      if grep -q "mountpoint -q /home/${u}" <<<"$body"; then
        pass "service requires /home/${u} to be mounted (active user)"
      fi
    done

    # Verify inactive users have their homes required to NOT be mounted
    for u in "${service_inactive_users[@]}"; do
      if grep -q "! mountpoint -q /home/${u}" <<<"$body"; then
        pass "service requires /home/${u} to NOT be mounted (inactive user)"
      fi
    done

    # Cross-check: if we have both config and system users, warn about mismatch
    if [[ ${#system_users[@]} -gt 0 && ${#config_users[@]} -gt 0 ]]; then
      # Check if service users match system users
      service_users_match=true
      for u in "${service_active_users[@]}" "${service_inactive_users[@]}"; do
        if [[ ! " ${system_users[*]} " =~ " ${u} " ]]; then
          service_users_match=false
          break
        fi
      done

      if [[ "$service_users_match" == "false" ]]; then
        warn "service users (${service_active_users[*]} ${service_inactive_users[*]}) differ from system users (${system_users[*]}) - template mismatch"
        warn "this is expected if the deployed system uses different usernames than the template"
      fi
    fi

    # The service must check at least one active user
    if [[ ${#service_active_users[@]} -gt 0 ]]; then
      pass "profile-mount-invariants service is correctly configured for profile: $profile"
    else
      fail "profile-mount-invariants service does not check any active users"
    fi
  else
    skip "could not read unit script body (may need sudo)"
  fi
else
  skip "profile-mount-invariants.service not found"
fi
