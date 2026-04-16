#!/usr/bin/env bash
# Static: both the toplevel (paranoid) and the daily specialisation must
# evaluate cleanly. Evaluation exercises the governance assertions in
# modules/security/governance.nix, so a failure here almost always means
# policy drift, not a flake-level error.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "eval: paranoid toplevel"
require_cmd nix || exit 0

out=$(nix_eval "system.build.toplevel.drvPath")
if [[ "$out" =~ ^\".*-nixos-system-nixos.*\.drv\"$ ]]; then
  pass "paranoid config evaluates to a toplevel derivation"
else
  fail "paranoid config eval returned unexpected shape" "$out"
fi

describe "eval: daily specialisation"
out=$(nix_eval_daily "system.build.toplevel.drvPath")
if [[ "$out" =~ ^\".*-nixos-system-nixos.*\.drv\"$ ]]; then
  pass "daily specialisation evaluates to a toplevel derivation"
else
  fail "daily specialisation eval returned unexpected shape" "$out"
fi

describe "profile tags"
assert_eq "$(nix_eval 'myOS.profile')"        '"paranoid"' "myOS.profile = paranoid at toplevel"
assert_eq "$(nix_eval_daily 'myOS.profile')"  '"daily"'    "myOS.profile = daily in specialisation"

describe "gpu resolution"
assert_eq "$(nix_eval 'myOS.gpu')"       '"nvidia"' "paranoid gpu = nvidia"
assert_eq "$(nix_eval_daily 'myOS.gpu')" '"nvidia"' "daily gpu = nvidia"

describe "users exist in both configs"
assert_contains "$(nix_eval 'users.users.player.description')" 'Daily desktop'     "player user declared"
assert_contains "$(nix_eval 'users.users.ghost.description')"  'Hardened workspace' "ghost user declared"
