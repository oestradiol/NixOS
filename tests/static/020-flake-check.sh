#!/usr/bin/env bash
# Static: `nix flake check` must pass.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "nix flake check"
require_cmd nix || exit 0

out=$(nix --extra-experimental-features 'nix-command flakes' \
  flake check --no-build "$REPO_ROOT" 2>&1)
rc=$?
if [[ $rc -eq 0 ]]; then
  pass "nix flake check passed"
else
  fail "nix flake check failed (rc=$rc)" "$out"
fi

describe "flake show exposes expected outputs"
_tc_ensure_jq || { skip "jq unavailable; cannot parse flake show output"; exit 0; }
# Capture stdout only; stderr may contain nix warnings that break JSON parsing.
show_err=$(mktemp)
show=$(nix --extra-experimental-features 'nix-command flakes' \
  flake show --json "$REPO_ROOT" 2>"$show_err")
rc=$?
if [[ $rc -ne 0 ]]; then
  fail "nix flake show failed" "$(cat "$show_err")"
  rm -f "$show_err"
  exit 0
fi
rm -f "$show_err"

# nixosConfigurations.nixos
if jq_cmd -e '.nixosConfigurations.nixos' <<<"$show" >/dev/null 2>&1; then
  pass "nixosConfigurations.nixos is exposed"
else
  fail "nixosConfigurations.nixos missing in flake show output"
fi

# checks.x86_64-linux.required-files
if jq_cmd -e '.checks."x86_64-linux"."required-files"' <<<"$show" >/dev/null 2>&1; then
  pass "checks.x86_64-linux.required-files is exposed"
else
  fail "checks.required-files missing in flake show output"
fi
