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

describe "flake.nix: required-files check covers the governance truth surfaces"
# flake.nix has an inline `required-files` check. Make sure it still lists
# the files PROJECT-STATE says are canonical.
flake="$REPO_ROOT/flake.nix"
for f in docs/governance/PROJECT-STATE.md flake.nix hosts/nixos/default.nix \
         docs/maps/SECURITY-SURFACES.md; do
  if grep -Fq "$f" "$flake"; then
    pass "flake required-files includes $f"
  else
    fail "flake required-files drift: $f no longer required by checks"
  fi
done

describe "user expectations match profile"
# PROJECT-STATE says /home/player persistent daily, /home/ghost tmpfs paranoid.
# Stage 4b moved the Btrfs subvol names into accounts/*.nix as the
# `home.btrfsSubvol` attribute; fs-layout.nix reads them via the
# framework. Grep across both surfaces so the check stays accurate.
fs="$REPO_ROOT/hosts/nixos/fs-layout.nix"
accounts="$REPO_ROOT/accounts"
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
