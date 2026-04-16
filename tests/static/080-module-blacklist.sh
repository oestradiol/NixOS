#!/usr/bin/env bash
# Static: dangerous modules blacklisted, desired modules loaded per profile.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "blacklisted kernel modules"
required=( dccp sctp rds tipc firewire-core firewire_core firewire-ohci )
bl=$(nix_eval 'boot.blacklistedKernelModules' 2>/dev/null | jq_cmd -r '.[]' 2>/dev/null || true)
for m in "${required[@]}"; do
  if grep -Fxq "$m" <<<"$bl"; then pass "paranoid blacklists $m"; else fail "paranoid missing blacklist for $m"; fi
done
bl=$(nix_eval_daily 'boot.blacklistedKernelModules' 2>/dev/null | jq_cmd -r '.[]' 2>/dev/null || true)
for m in "${required[@]}"; do
  if grep -Fxq "$m" <<<"$bl"; then pass "daily blacklists $m"; else fail "daily missing blacklist for $m"; fi
done

describe "kernelModules per profile"
# ntsync is only loaded on daily (desktop/gaming.nix adds it).
p_km=$(nix_eval 'boot.kernelModules' 2>/dev/null | jq_cmd -r '.[]' 2>/dev/null || true)
d_km=$(nix_eval_daily 'boot.kernelModules' 2>/dev/null | jq_cmd -r '.[]' 2>/dev/null || true)

if grep -Fxq ntsync <<<"$d_km"; then pass "daily loads ntsync"; else fail "daily missing ntsync module"; fi
if ! grep -Fxq ntsync <<<"$p_km"; then pass "paranoid does not load ntsync"; else fail "paranoid should not load ntsync"; fi

# kvm-amd from hardware-target.nix, should be present on both.
if grep -Fxq kvm-amd <<<"$p_km"; then pass "paranoid loads kvm-amd"; else fail "paranoid missing kvm-amd"; fi
if grep -Fxq kvm-amd <<<"$d_km"; then pass "daily loads kvm-amd"; else fail "daily missing kvm-amd"; fi

describe "extraModprobeConfig: bluetooth ERTM tweak lives only on daily controllers module"
p_mp=$(nix_eval 'boot.extraModprobeConfig' 2>/dev/null | jq_cmd -r '.' 2>/dev/null || true)
d_mp=$(nix_eval_daily 'boot.extraModprobeConfig' 2>/dev/null | jq_cmd -r '.' 2>/dev/null || true)
if [[ "$d_mp" == *"disable_ertm=1"* ]]; then
  pass "daily disables bluetooth ERTM (controllers.nix)"
else
  fail "daily missing bluetooth disable_ertm=1 modprobe line"
fi
if [[ "$p_mp" != *"disable_ertm=1"* ]]; then
  pass "paranoid does not touch bluetooth modprobe (no controllers)"
else
  fail "paranoid unexpectedly configures bluetooth ERTM"
fi
