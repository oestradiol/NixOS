#!/usr/bin/env bash
# Static: everything documented as "staged" or "deferred" in HARDENING-TRACKER
# and POST-STABILITY must actually be off/absent in the baseline build.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "Secure Boot / TPM: staged, not baseline"
assert_eq "$(nix_eval 'myOS.security.secureBoot.enable')" 'false' "secureBoot off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.secureBoot.enable')" 'false' "secureBoot off (daily)"
assert_eq "$(nix_eval 'myOS.security.tpm.enable')" 'false' "TPM off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.tpm.enable')" 'false' "TPM off (daily)"
# Lanzaboote: the option is only evaluatable when the lanzaboote module is in
# the import list, which happens when secureBoot.enable=true. With SB staged
# off, the cache reports 'null' (option not declared) — acceptable.
lz=$(nix_eval 'boot.lanzaboote.enable')
if [[ "$lz" == 'false' || "$lz" == 'null' ]]; then
  pass "lanzaboote disabled/unreachable in paranoid (got $lz)"
else
  fail "lanzaboote leaked into paranoid" "value: $lz"
fi

describe "systemd-boot is the active bootloader"
assert_eq "$(nix_eval 'boot.loader.systemd-boot.enable')" 'false' "systemd-boot disabled in test fixture"
assert_eq "$(nix_eval 'boot.loader.grub.enable')" 'false' "GRUB disabled (never coexist with SB path)"

describe "self-owned WireGuard: staged, not baseline"
assert_eq "$(nix_eval 'myOS.security.wireguardMullvad.enable')" 'false' "WG-mullvad off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.wireguardMullvad.enable')" 'false' "WG-mullvad off (daily)"
# No wg-mullvad networking interface should materialise.
wg_keys=$(nix_eval 'networking.wireguard.interfaces.__keys')
wg_len=$(jq_cmd 'length // 0' <<<"$wg_keys")
assert_eq "$wg_len" '0' "no wireguard interfaces active (paranoid)"

describe "custom audit rules: staged off"
assert_eq "$(nix_eval 'myOS.security.auditRules.enable')" 'false' "auditRules off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.auditRules.enable')" 'false' "auditRules off (daily)"

describe "PAM profile-binding: rejected/off"
assert_eq "$(nix_eval 'myOS.security.pamProfileBinding.enable')" 'false' "PAM profile-binding off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.pamProfileBinding.enable')" 'false' "PAM profile-binding off (daily)"

describe "hardened memory allocator: staged off"
assert_eq "$(nix_eval 'myOS.security.hardenedMemory.enable')" 'false' "graphene allocator off (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.security.hardenedMemory.enable')" 'false' "graphene allocator off (daily)"

describe "staged kernel knobs stay off"
for k in \
  "myOS.security.kernelHardening.oopsPanic" \
  "myOS.security.kernelHardening.moduleSigEnforce" \
  "myOS.security.kernelHardening.modulesDisabled"; do
  assert_eq "$(nix_eval "$k")"       'false' "paranoid $k off"
  assert_eq "$(nix_eval_daily "$k")" 'false' "daily $k off"
done

describe "agenix secrets: scaffolding only (no real payload names yet)"
# age.secrets should currently be empty (options.nix ledger + secrets.nix is
# scaffolding only). If the repo adds secret entries later, update this test.
p_secrets=$(jq_cmd 'length // 0' <<<"$(nix_eval 'age.secrets.__keys')")
d_secrets=$(jq_cmd 'length // 0' <<<"$(nix_eval_daily 'age.secrets.__keys')")
if [[ "$p_secrets" == "0" ]]; then
  pass "no age.secrets in paranoid (scaffolding only)"
else
  warn "paranoid age.secrets has $p_secrets entries (update this test if intentional)"
fi
if [[ "$d_secrets" == "0" ]]; then
  pass "no age.secrets in daily (scaffolding only)"
else
  warn "daily age.secrets has $d_secrets entries (update this test if intentional)"
fi
