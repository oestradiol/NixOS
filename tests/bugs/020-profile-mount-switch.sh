#!/usr/bin/env bash
# Bug regression: switch.log captured profile-mount-invariants.service
# failing during `nixos-rebuild switch`. The failure pattern is:
#
#   "Failed to stop home-player.mount"
#   "Failed to start profile-mount-invariants.service"
#
# Root cause: the `flake-switch` alias in modules/desktop/shell.nix targets
# the flake output `.#nixos`, which is the PARANOID toplevel. When the user
# runs the alias while booted into the DAILY specialisation, the activation
# tries to switch the live system to paranoid: it stops home-player.mount
# (busy, because the user is logged in as `player`), then the paranoid copy
# of profile-mount-invariants.service runs and asserts `/home/player` is
# NOT mounted — which still fails because the stop couldn't complete.
#
# This test captures the symptoms clearly and checks whether the fix is in
# place (an alias that respects the current specialisation).
source "${BASH_SOURCE%/*}/../lib/common.sh"

shell_nix="$REPO_ROOT/modules/desktop/shell.nix"
switch_log="$REPO_ROOT/switch.log"

describe "symptoms recorded in switch.log (historical — fix landed 2026-04)"
# switch.log is a gitignored artefact of the pre-fix state. Three possible
# states:
#   (a) file absent  — operator cleared it after a clean rebuild   (PASS)
#   (b) file present, symptoms absent — log was rotated or trimmed (PASS)
#   (c) file present, symptoms present — historical evidence      (WARN)
# Never FAIL here: the bug's code fix lives in modules/desktop/shell.nix and
# is covered by the other describe blocks in this file plus bugs/030.
if [[ ! -f "$switch_log" ]]; then
  pass "switch.log absent (historical artefact cleared)"
else
  if grep -Fq 'Failed to stop home-player.mount' "$switch_log"; then
    warn "switch.log (historical) still contains: Failed to stop home-player.mount" \
         "Delete switch.log after the next successful rebuild to clear this warning."
  else
    pass "switch.log has no 'Failed to stop home-player.mount' line"
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
     || grep -Eq 'flake-switch\s*=.*/run/current-system/specialisation/daily' "$shell_nix"; then
    pass "flake-switch is specialisation-aware (direct flag OR smart-default branch)"
  else
    fail "flake-switch alias does not route by specialisation" \
         "As a result, running it from daily silently switches the live system to paranoid," \
         "which tries to stop home-player.mount while player is logged in, and" \
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

describe "profile-mount-invariants.service currently matches the booted profile"
# If we're in daily, the running service must be the daily variant.
profile=$(detect_profile)
unit_path=/etc/systemd/system/profile-mount-invariants.service
if [[ -r "$unit_path" ]]; then
  script_ref=$(awk -F'=' '/ExecStart/{print $2}' "$unit_path" | tr -d ' ')
  info "ExecStart: $script_ref"
  if [[ -r "$script_ref" ]]; then
    body=$(cat "$script_ref")
    # The daily variant asserts `! mountpoint -q /home/ghost` and `! mountpoint -q /persist/home/ghost`.
    # The paranoid variant asserts `! mountpoint -q /home/player`.
    if [[ "$profile" == "daily" ]]; then
      if grep -q '! mountpoint -q /home/ghost' <<<"$body" \
         && grep -q '! mountpoint -q /persist/home/ghost' <<<"$body"; then
        pass "daily variant of profile-mount-invariants is installed"
      else
        fail "daily variant not installed; paranoid variant would be running instead"
      fi
    else
      if grep -q '! mountpoint -q /home/player' <<<"$body"; then
        pass "paranoid variant of profile-mount-invariants is installed"
      else
        fail "paranoid variant not installed; daily variant would be running instead"
      fi
    fi
  else
    skip "could not read unit script body (may need sudo)"
  fi
fi
