#!/usr/bin/env bash
# Static: verify that the flake-* shell aliases are specialisation-aware.
#
# Background: previously `flake-switch` was a single alias targeting the
# paranoid toplevel. Running it from a booted daily session silently swapped
# the live config to paranoid, which tripped profile-mount-invariants (see
# tests/bugs/020-profile-mount-switch.sh and switch.log:49-67).
#
# The alias family is now:
#   flake-switch-daily     → --specialisation daily
#   flake-switch-paranoid  → toplevel
#   flake-switch           → auto-detect via /run/current-system/specialisation/daily
#   flake-test-*, flake-boot-*, flake-rollback, flake-dry, etc.
#
# Every alias must carry --show-trace during the debug phase so failures are
# actionable.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd grep || exit 0

shell_nix="$REPO_ROOT/modules/desktop/shell.nix"
assert_file "$shell_nix"

describe "per-profile switch aliases are declared"
for a in flake-switch-daily flake-switch-paranoid flake-switch \
         flake-test-daily flake-test-paranoid flake-test \
         flake-boot-daily flake-boot-paranoid flake-boot \
         flake-dry flake-rollback \
         flake-update nix-update; do
  if grep -Fq "$a " "$shell_nix" || grep -Fq "$a=" "$shell_nix" || grep -Fq "$a " "$shell_nix"; then
    pass "alias declared: $a"
  else
    fail "alias missing: $a" "file: $shell_nix"
  fi
done

describe "daily aliases pass --specialisation daily"
for a in flake-switch-daily flake-test-daily; do
  # Extract the value of this alias from shell.nix: anything after `$alias = "` up to `";`
  line=$(grep -E "^\s*${a}\s*=" "$shell_nix" | head -1)
  if [[ -z "$line" ]]; then
    fail "could not locate alias line for $a"
    continue
  fi
  if [[ "$line" == *'--specialisation daily'* ]]; then
    pass "$a carries --specialisation daily"
  else
    fail "$a does NOT pass --specialisation daily" "line: $line"
  fi
done

describe "boot-daily does NOT pass --specialisation (boot builds all specialisations)"
line=$(grep -E "^\s*flake-boot-daily\s*=" "$shell_nix" | head -1)
if [[ -z "$line" ]]; then
  fail "could not locate alias line for flake-boot-daily"
elif [[ "$line" == *'--specialisation'* ]]; then
  fail "flake-boot-daily wrongly carries --specialisation" "line: $line"
else
  pass "flake-boot-daily does NOT pass --specialisation (boot already builds all)"
fi

describe "paranoid aliases do NOT pass --specialisation daily"
for a in flake-switch-paranoid flake-test-paranoid flake-boot-paranoid; do
  line=$(grep -E "^\s*${a}\s*=" "$shell_nix" | head -1)
  if [[ -z "$line" ]]; then
    fail "could not locate alias line for $a"
    continue
  fi
  if [[ "$line" == *'--specialisation'* ]]; then
    fail "$a wrongly carries --specialisation" "line: $line"
  else
    pass "$a targets the toplevel (no --specialisation)"
  fi
done

describe "smart default routes by booted specialisation"
for a in flake-switch flake-test flake-boot; do
  line=$(grep -E "^\s*${a}\s*=" "$shell_nix" | head -1)
  if [[ -z "$line" ]]; then
    fail "could not locate alias line for $a"
    continue
  fi
  if [[ "$line" == *'/run/current-system/specialisation/daily'* ]]; then
    pass "$a branches on /run/current-system/specialisation/daily"
  else
    fail "$a does not route by booted specialisation" "line: $line"
  fi
done

describe "debug-phase: rebuild aliases carry --show-trace"
for a in flake-switch-daily flake-switch-paranoid \
         flake-test-daily flake-test-paranoid \
         flake-boot-daily flake-boot-paranoid \
         flake-dry; do
  line=$(grep -E "^\s*${a}\s*=" "$shell_nix" | head -1)
  [[ -z "$line" ]] && continue
  if [[ "$line" == *'--show-trace'* ]]; then
    pass "$a carries --show-trace"
  else
    fail "$a missing --show-trace (debug phase requirement)" "line: $line"
  fi
done

describe "panic-button: flake-rollback re-applies the booted generation"
line=$(grep -E '^\s*flake-rollback\s*=' "$shell_nix" | head -1)
if [[ "$line" == *'/run/current-system/bin/switch-to-configuration switch'* ]]; then
  pass "flake-rollback re-applies /run/current-system"
else
  fail "flake-rollback does not re-apply the booted generation" "line: $line"
fi
