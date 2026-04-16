#!/usr/bin/env bash
# Static governance: docs/maps/HARDENING-TRACKER.md claims must match code.
# We take the most important knob/state pairs and verify.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

ht="$REPO_ROOT/docs/maps/HARDENING-TRACKER.md"
assert_file "$ht"

# Table entries are lines of form: | <knob> | <state> | ... |
# Quickly check each claim we care about.

claim() {
  # claim "<knob>" "<state>"  — fails if the tracker doesn't list that state.
  local knob="$1" state="$2"
  if grep -F "| $knob " "$ht" | grep -Fq "| $state |"; then
    pass "HARDENING-TRACKER: $knob -> $state"
  else
    fail "HARDENING-TRACKER drift" "$knob should be '$state'"
  fi
}

describe "HARDENING-TRACKER documented states"
claim "two-account split (\`ghost\` / \`player\`)" "baseline"
claim "root account locked" "baseline"
claim "profile-user binding via account locking" "baseline"
claim "PAM profile-binding" "rejected"
claim "stock kernel packages" "baseline"
claim "\`linux-hardened\` kernel" "absent"
claim "\`randomize_kstack_offset=on\`" "baseline"
claim "\`debugfs=off\`" "baseline"
claim "\`init_on_alloc=1\`" "baseline"
claim "\`init_on_free=1\`" "daily-softened"
claim "\`nosmt=force\`" "daily-softened"
claim "\`usbcore.authorized_default=2\`" "daily-softened"
claim "\`oops=panic\`" "staged"
claim "\`module.sig_enforce=1\`" "staged"
claim "\`kernel.modules_disabled=1\`" "staged"
claim "module blacklist (dccp/sctp/rds/tipc/firewire)" "baseline"
claim "Secure Boot via Lanzaboote" "staged"
claim "TPM-bound unlock" "staged"
claim "bubblewrap wrapper core" "baseline"
claim "wrapped paranoid browsers" "baseline"
claim "VM tooling layer" "baseline on paranoid"
claim "VM tooling on daily" "daily-softened"
claim "Firejail" "rejected"
claim "Flatpak" "baseline"
claim "Mullvad app mode (daily only)" "baseline"
claim "self-owned WireGuard path" "staged"
claim "agenix enablement" "baseline"
claim "actual age secrets payloads" "staged"
claim "audit subsystem + \`auditd\` on paranoid" "baseline"
claim "\`auditd\` on daily" "daily-softened"
claim "repo custom audit rules" "staged"
claim "AIDE" "baseline"
claim "ClamAV" "baseline"
claim "AppArmor framework enablement" "baseline"

describe "every staged knob in HARDENING-TRACKER is actually off in config"
# Pull staged rows and verify the corresponding nix attr is false/absent.
stage_attrs=(
  'myOS.security.secureBoot.enable'
  'myOS.security.tpm.enable'
  'myOS.security.wireguardMullvad.enable'
  'myOS.security.auditRules.enable'
  'myOS.security.hardenedMemory.enable'
  'myOS.security.pamProfileBinding.enable'
  'myOS.security.kernelHardening.oopsPanic'
  'myOS.security.kernelHardening.moduleSigEnforce'
  'myOS.security.kernelHardening.modulesDisabled'
)
for a in "${stage_attrs[@]}"; do
  assert_eq "$(nix_eval "$a")"       'false' "staged off (paranoid): $a"
  assert_eq "$(nix_eval_daily "$a")" 'false' "staged off (daily):    $a"
done
