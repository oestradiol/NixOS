#!/usr/bin/env bash
# Static governance: PROJECT-STATE.md baseline claims must match the live Nix configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

ps="$REPO_ROOT/docs/governance/PROJECT-STATE.md"
assert_file "$ps"

describe "PROJECT-STATE baseline split"
for claim in \
    "\`paranoid\`: instantiates that shared base as the default hardened workstation baseline" \
    "\`daily\`: instantiates that shared base as the explicit relaxation layer" \
    "one encrypted LUKS2 root device" \
    "Btrfs subvolumes under LUKS" \
    "tmpfs root" \
    "impermanence-managed persisted state under \`/persist\`" \
    "\`player\` is the normal daily account" \
    "\`ghost\` is the hardened workspace account" \
    "Firefox Sync remains disabled by policy"; do
  if grep -Fq "$claim" "$ps"; then
    pass "PROJECT-STATE claim: ${claim:0:80}"
  else
    fail "PROJECT-STATE drift" "$claim"
  fi
done

describe "user expectations match profile (templates/default reference implementation)"
# PROJECT-STATE says /home/player persistent daily, /home/ghost tmpfs paranoid.
# Stage 4b moved the Btrfs subvol names into accounts/*.nix as the
# `home.btrfsSubvol` attribute; fs-layout.nix reads them via the
# framework. The reference implementation is now in templates/default/.
fs="$REPO_ROOT/templates/default/hosts/nixos/fs-layout.nix"
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
if grep -Fq 'fsType = "tmpfs"' "$fs"; then pass "tmpfs root present"; else fail "tmpfs root missing"; fi

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
