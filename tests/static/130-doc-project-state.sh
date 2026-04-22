#!/usr/bin/env bash
# Static governance: PROJECT-STATE.md baseline claims must match the live Nix configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

ps="$REPO_ROOT/docs/governance/PROJECT-STATE.md"
assert_file "$ps"

describe "PROJECT-STATE baseline split"
for claim in \
    "\`paranoid\`: the default hardened workstation profile with strongest workstation-safe settings" \
    "\`daily\`: the explicit relaxation specialization for gaming/social/recovery-friendly use" \
    "one encrypted LUKS2 root device" \
    "Btrfs subvolumes under LUKS" \
    "tmpfs root" \
    "impermanence-managed persisted state under \`/persist\`" \
    "Firefox Sync remains disabled by policy"; do
  if grep -Fq "$claim" "$ps"; then
    pass "PROJECT-STATE claim: ${claim:0:80}"
  else
    fail "PROJECT-STATE drift" "$claim"
  fi
done

describe "PROJECT-STATE user model (template-agnostic)"
# Documentation should describe the two-axis model, not hardcode specific
# template user names (the default template uses example user names, but docs
# should describe the framework in template-agnostic terms)
doc_has_two_axis_model=false
if grep -Fq "two-axis" "$ps" || grep -Fq "myOS.users" "$ps" || grep -Fq "profile-user binding" "$ps"; then
  doc_has_two_axis_model=true
  pass "PROJECT-STATE describes framework user model (two-axis or myOS.users)"
fi

# Framework docs should NOT contain ghost/player - those are template-specific
if grep -Fq "ghost" "$ps" || grep -Fq "player" "$ps"; then
  fail "PROJECT-STATE contains template-specific user names (ghost/player); use template-agnostic language"
fi

if [[ "$doc_has_two_axis_model" == "false" ]]; then
  fail "PROJECT-STATE missing user model description (should describe two-axis framework)"
fi

describe "user expectations match profile (templates/default reference implementation)"
# The default template demonstrates the two-axis model with one persistent daily
# user and one tmpfs-based paranoid user. The btrfsSubvol names are defined in
# accounts/*.nix and read by the framework storage module.
accounts="$REPO_ROOT/templates/default/accounts"
if grep -rFq 'btrfsSubvol = "@home-daily"' "$accounts" 2>/dev/null; then
  pass "accounts/ declares @home-daily"
else
  fail "accounts/ missing @home-daily subvol binding"
fi
if grep -rFq 'btrfsSubvol = "@home-paranoid"' "$accounts" 2>/dev/null; then
  pass "accounts/ declares @home-paranoid"
else
  fail "accounts/ missing @home-paranoid subvol binding"
fi
assert_eq "$(nix_eval 'fileSystems./.fsType')" '"tmpfs"' "tmpfs root present"

describe "audit status: paranoid baseline audit + staged custom rules"
as="$REPO_ROOT/docs/maps/AUDIT-STATUS.md"
assert_file "$as"
if grep -Fq "paranoid baseline keeps the Linux audit subsystem and \`auditd\`" "$REPO_ROOT/docs/pipeline/POST-STABILITY.md" \
   || grep -Fq "audit subsystem + \`auditd\` on paranoid" "$REPO_ROOT/docs/maps/HARDENING-TRACKER.md"; then
  pass "auditd on paranoid documented"
else
  fail "auditd-on-paranoid documentation missing"
fi
if grep -Fq "repo custom audit rules" "$as"; then
  pass "AUDIT-STATUS tracks repo custom audit rules as a separate surface"
else
  fail "AUDIT-STATUS lost the repo custom audit rules row"
fi
