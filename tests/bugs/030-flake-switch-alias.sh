#!/usr/bin/env bash
# Regression test for Bug B1: `flake-switch` not specialisation-aware.
#
# Symptom: from inside a booted daily session, running `flake-switch` silently
# swaps the live config to paranoid, which tries to stop home-player.mount
# while player is logged in. profile-mount-invariants then fails and the
# activation exits rc=4 (see switch.log:49-67).
#
# Root cause: a single alias `flake-switch = nixos-rebuild switch --flake .#nixos`
# always targets the paranoid toplevel, regardless of the booted specialisation.
#
# Fix: split aliases (flake-switch-daily, flake-switch-paranoid), plus a smart
# default that picks based on /nix/var/nix/profiles/system/specialisation/daily.
#
# This test complements tests/bugs/020-profile-mount-switch.sh which documents
# the historical switch.log evidence.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd grep || exit 0

shell_nix="$REPO_ROOT/modules/desktop/shell.nix"
assert_file "$shell_nix"

describe "symptom: ambiguous flake-switch without --specialisation (the original bug)"
# The old alias looked exactly like:
#   flake-switch = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
# Searching for that SPECIFIC pattern asserts we never regress to it.
#
# Whitelisted aliases: *-paranoid aliases are ALLOWED to target the toplevel
# (they are the explicit paranoid switch). The ambiguous form is one whose
# NAME does not disambiguate (e.g. `flake-switch`, `flake-test`, `flake-boot`)
# AND whose VALUE is a bare `nixos-rebuild switch ... #nixos` without either
# --specialisation OR a conditional.
regressed=0
while IFS= read -r line; do
  # Extract alias name and value.
  name=$(echo "$line" | sed -E 's/^\s*//; s/\s*=.*//')
  val=$(echo  "$line" | sed -E 's/^[^=]*=\s*"//; s/";\s*$//')

  # Skip aliases that are explicitly named *-paranoid (they legitimately
  # target the paranoid toplevel without --specialisation).
  if [[ "$name" == *-paranoid ]]; then
    continue
  fi
  # Skip aliases that do not invoke nixos-rebuild switch.
  if [[ "$val" != *'nixos-rebuild switch'* ]]; then
    continue
  fi
  # Accept aliases that pass --specialisation directly.
  if [[ "$val" == *'--specialisation'* ]]; then
    continue
  fi
  # Accept aliases that branch on the booted specialisation.
  if [[ "$val" == *'if ['* || "$val" == *'specialisation/daily'* ]]; then
    continue
  fi
  # Anything left is the regression pattern.
  fail "regression: ambiguous flake-switch-ish alias without specialisation routing" \
    "alias: $line" \
    "fix: either add --specialisation daily OR wrap in a booted-specialisation conditional"
  regressed=1
done < <(grep -E '^\s*flake-[a-z-]+\s*=' "$shell_nix")
if (( !regressed )); then
  pass "no ambiguous bare nixos-rebuild switch alias remains"
fi

describe "fix: specialisation-aware aliases"
# Mirror of the checks in tests/static/160-flake-aliases.sh so that operators
# reading tests/bugs/ see the regression coverage end-to-end without having to
# chase multiple files. If either the static or the bugs version drifts, the
# other will still catch the regression.
line_sd=$(grep -E '^\s*flake-switch-daily\s*=' "$shell_nix" | head -1)
line_sp=$(grep -E '^\s*flake-switch-paranoid\s*=' "$shell_nix" | head -1)
line_s=$( grep -E '^\s*flake-switch\s*='          "$shell_nix" | head -1)

assert_ne "$line_sd" '' "flake-switch-daily declared"
assert_ne "$line_sp" '' "flake-switch-paranoid declared"
assert_ne "$line_s"  '' "flake-switch (smart default) declared"

[[ "$line_sd" == *'--specialisation daily'* ]] && pass "flake-switch-daily → daily specialisation" \
  || fail "flake-switch-daily not targeting daily specialisation" "line: $line_sd"

[[ "$line_sp" != *'--specialisation'* ]] && pass "flake-switch-paranoid → toplevel (no --specialisation)" \
  || fail "flake-switch-paranoid incorrectly passes --specialisation" "line: $line_sp"

[[ "$line_s" == *'/nix/var/nix/profiles/system/specialisation/daily'* ]] && pass "flake-switch branches on booted specialisation" \
  || fail "flake-switch does not branch on /nix/var/nix/profiles/system/specialisation/daily" "line: $line_s"

describe "debug-mode ergonomics: --show-trace required everywhere during test phase"
for a in flake-switch-daily flake-switch-paranoid flake-test-daily flake-test-paranoid \
         flake-boot flake-dry; do
  line=$(grep -E "^\s*${a}\s*=" "$shell_nix" | head -1)
  [[ -z "$line" ]] && { fail "alias missing: $a"; continue; }
  if [[ "$line" == *'--show-trace'* ]]; then
    pass "$a carries --show-trace"
  else
    fail "$a missing --show-trace" "line: $line"
  fi
done

describe "panic button: flake-rollback reapplies the booted generation"
line=$(grep -E '^\s*flake-rollback\s*=' "$shell_nix" | head -1)
if [[ "$line" == *'/run/current-system/bin/switch-to-configuration switch'* ]]; then
  pass "flake-rollback re-applies the booted gen"
else
  fail "flake-rollback does not re-apply /run/current-system" "line: $line"
fi

describe "dry-activate alias is present"
line=$(grep -E '^\s*flake-dry\s*=' "$shell_nix" | head -1)
if [[ "$line" == *'dry-activate'* ]]; then
  pass "flake-dry uses dry-activate (no changes applied)"
else
  fail "flake-dry missing or not using dry-activate" "line: $line"
fi

describe "cross-reference: switch.log shows the historical failure"
# switch.log is gitignored and purely evidentiary. See bugs/020 for the
# same check as pass/warn assertions — this section is an info-only hint.
if [[ -f "$REPO_ROOT/switch.log" ]]; then
  if grep -q 'profile-mount-invariants' "$REPO_ROOT/switch.log" 2>/dev/null; then
    info "switch.log still contains the historical failure (expected — it is an artefact, not live state)"
  else
    info "switch.log present but no longer mentions profile-mount-invariants"
  fi
else
  info "switch.log absent (historical artefact cleared)"
fi
