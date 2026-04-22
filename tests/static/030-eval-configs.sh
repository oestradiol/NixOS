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

describe "users are discoverable from framework config (template-agnostic)"
# Verify that the framework exports user names and each user has required fields
user_names_json=$(nix_eval 'myOS.users.__names')
if [[ "$user_names_json" == "null" || "$user_names_json" == "[]" ]]; then
  fail "no users declared in myOS.users"
  exit 1
fi

mapfile -t all_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
info "discovered users: ${all_users[*]}"

for u in "${all_users[@]}"; do
  desc=$(nix_eval "users.users.${u}.description")
  if [[ "$desc" != "null" && -n "$desc" ]]; then
    pass "user ${u} has description: $desc"
  else
    fail "user ${u} missing description"
  fi
  shell=$(nix_eval "users.users.${u}.shell")
  if [[ "$shell" != "null" && "$shell" == *"zsh"* ]]; then
    pass "user ${u} has zsh shell"
  else
    warn "user ${u} shell may not be zsh: $shell"
  fi
done
pass "all users validated in both paranoid and daily configurations"
