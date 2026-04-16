#!/usr/bin/env bash
# Static: mDNS/avahi governance.
#
# Policy: the only reason anything in this repo pulls avahi in is the upstream
# nixpkgs `services/video/wivrn.nix`, which hard-sets
#   services.avahi.enable = true
#   services.avahi.publish.userServices = true
# WITHOUT mkDefault. That broadcasts `_*._tcp.local` service records on every
# reachable LAN, which is an identity beacon that has nothing to do with VR
# functioning.
#
# modules/desktop/vr.nix gates this behaviour behind `myOS.vr.lanDiscovery.enable`
# (default false). When OFF, avahi is mkForce-disabled. When ON, avahi is
# scoped to `myOS.vr.lanInterfaces` only.
#
# This test enforces:
#  - paranoid: avahi always off (no VR stack imported anyway)
#  - daily, lanDiscovery.enable=false: avahi off, publish off
#  - daily, lanDiscovery.enable=true:  avahi on, allowInterfaces non-empty
#
# It does NOT require `lanDiscovery.enable = true` — that's operator choice.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "paranoid: avahi is always disabled"
ap=$(nix_eval 'services.avahi.enable')
# Paranoid profile does not import gaming/vr, so avahi's option may not even
# be touched. Accept false or null (option unreachable).
case "$ap" in
  false|null) pass "paranoid: services.avahi.enable=$ap" ;;
  true)       fail "paranoid: services.avahi.enable=true (no VR stack in paranoid, who enabled this?)" ;;
  *)          fail "paranoid: services.avahi.enable=$ap (unexpected)" ;;
esac

describe "daily: avahi matches myOS.vr.lanDiscovery.enable"
ad=$(nix_eval_daily 'services.avahi.enable')
pd=$(nix_eval_daily 'services.avahi.publish.enable')
usd=$(nix_eval_daily 'services.avahi.publish.userServices')
ld=$(nix_eval_daily 'myOS.vr.lanDiscovery.enable')

case "$ld" in
  false)
    assert_eq "$ad"  'false' "daily + lanDiscovery=false: services.avahi.enable must be false"
    assert_eq "$pd"  'false' "daily + lanDiscovery=false: services.avahi.publish.enable must be false"
    assert_eq "$usd" 'false' "daily + lanDiscovery=false: publish.userServices must be false"
    ;;
  true)
    assert_eq "$ad" 'true' "daily + lanDiscovery=true: services.avahi.enable must be true"
    ifaces=$(nix_eval_daily 'services.avahi.allowInterfaces')
    if [[ "$ifaces" == "null" || "$ifaces" == "[]" ]]; then
      fail "daily + lanDiscovery=true: allowInterfaces must be non-empty (broadcast scope)"
    else
      pass "daily + lanDiscovery=true: allowInterfaces=$ifaces"
    fi
    # Cross-check that allowInterfaces is a subset of myOS.vr.lanInterfaces.
    declared=$(nix_eval_daily 'myOS.vr.lanInterfaces')
    mismatch=$(jq_cmd -cn --argjson a "$ifaces" --argjson b "$declared" \
      '($a // []) - ($b // [])')
    if [[ "$mismatch" == '[]' ]]; then
      pass "daily: avahi.allowInterfaces is a subset of myOS.vr.lanInterfaces"
    else
      fail "daily: avahi advertises on un-declared interfaces" \
        "extra: $mismatch"
    fi
    ;;
  *)
    fail "daily: myOS.vr.lanDiscovery.enable is '$ld' (expected 'true' or 'false')"
    ;;
esac

describe "avahi governance is wired into the shared assertion set"
# The governance module in modules/security/governance.nix must own the invariant
# so it fires at build time, not just when this test runs.
gov="$REPO_ROOT/modules/security/governance.nix"
assert_file "$gov"
if grep -Fq 'myOS.vr.lanDiscovery' "$gov"; then
  pass "governance.nix references myOS.vr.lanDiscovery"
else
  fail "governance.nix does not reference myOS.vr.lanDiscovery" \
    "invariant should be enforced as a NixOS assertion, not only in tests"
fi
if grep -Fq 'services.avahi.enable' "$gov"; then
  pass "governance.nix enforces services.avahi.enable"
else
  fail "governance.nix does not enforce services.avahi.enable"
fi
