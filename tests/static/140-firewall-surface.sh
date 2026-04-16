#!/usr/bin/env bash
# Static: enforce a deliberate firewall surface on both profiles.
#
# Governance principle: every open port is an explicit, documented decision.
# Paranoid MUST have zero globally-open ports. Daily may open ports but only
# via `networking.firewall.interfaces.<iface>.allowedXxxPorts` (interface-scoped)
# and the allowed set is enumerated below.
#
# This caught:
#   - UDP 7 (echo) globally open on daily, intended for WoL but layer-2 WoL
#     doesn't need any firewall rule. (Removed 2026-04.)
#   - WiVRn `openFirewall = true` which opens TCP/UDP 9757 on every interface.
#     (Replaced with per-interface rule gated by myOS.vr.lanInterfaces, 2026-04.)
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

# Expected allowed ports (global, not scoped to an interface).
# If you need to add a port, add it here AND document why in FEATURES.md.
want_tcp_paranoid='[]'
want_udp_paranoid='[]'
want_tcp_daily='[]'
want_udp_daily='[]'

describe "firewall enablement (at least one packet filter is always active)"
fw_p=$(nix_eval 'networking.firewall.enable')
nft_p=$(nix_eval 'networking.nftables.enable')
fw_d=$(nix_eval_daily 'networking.firewall.enable')
nft_d=$(nix_eval_daily 'networking.nftables.enable')
if [[ "$fw_p" == "true" || "$nft_p" == "true" ]]; then
  pass "paranoid: firewall=$fw_p nftables=$nft_p (at least one is on)"
else
  fail "paranoid: NEITHER networking.firewall nor networking.nftables is enabled"
fi
if [[ "$fw_d" == "true" || "$nft_d" == "true" ]]; then
  pass "daily: firewall=$fw_d nftables=$nft_d (at least one is on)"
else
  fail "daily: NEITHER networking.firewall nor networking.nftables is enabled"
fi

describe "global allowed ports: paranoid is closed by default"
tcp_p=$(nix_eval 'networking.firewall.allowedTCPPorts')
udp_p=$(nix_eval 'networking.firewall.allowedUDPPorts')
assert_eq "$tcp_p" "$want_tcp_paranoid" "paranoid allowedTCPPorts == []"
assert_eq "$udp_p" "$want_udp_paranoid" "paranoid allowedUDPPorts == []"

describe "global allowed ports: daily is closed by default (LAN opens scoped)"
tcp_d=$(nix_eval_daily 'networking.firewall.allowedTCPPorts')
udp_d=$(nix_eval_daily 'networking.firewall.allowedUDPPorts')
assert_eq "$tcp_d" "$want_tcp_daily" "daily allowedTCPPorts == []"
assert_eq "$udp_d" "$want_udp_daily" "daily allowedUDPPorts == []"

describe "WiVRn upstream openFirewall is suppressed"
# Upstream wivrn.nix `openFirewall = true` opens 9757 on every interface.
# Our vr.nix sets it to false and opens 9757 ONLY on myOS.vr.lanInterfaces.
wfp=$(nix_eval 'services.wivrn.openFirewall')
wfd=$(nix_eval_daily 'services.wivrn.openFirewall')
# Paranoid doesn't import VR, so the option may be unreachable (null is ok).
case "$wfp" in
  false|null) pass "paranoid: wivrn.openFirewall=$wfp (VR not imported, or off)" ;;
  *)          fail "paranoid: services.wivrn.openFirewall=$wfp (must be false/null)" ;;
esac
assert_eq "$wfd" 'false' "daily: services.wivrn.openFirewall must be false (use per-iface rules)"

describe "WiVRn per-interface allowance is scoped"
# When daily enables WiVRn, TCP+UDP 9757 must be allowed on each declared LAN
# interface. The interfaces list is config.myOS.vr.lanInterfaces.
lan_ifaces=$(nix_eval_daily 'myOS.vr.lanInterfaces')
iface_count=$(jq_cmd 'length // 0' <<<"$lan_ifaces")
if (( iface_count > 0 )); then
  pass "daily: myOS.vr.lanInterfaces declared ($iface_count iface(s))"
  # Spot-check the first interface (current LAN is enp5s0).
  first=$(jq_cmd -r '.[0]' <<<"$lan_ifaces")
  if [[ "$first" == "enp5s0" ]]; then
    tcp_if=$(nix_eval_daily "networking.firewall.interfaces.enp5s0.allowedTCPPorts")
    udp_if=$(nix_eval_daily "networking.firewall.interfaces.enp5s0.allowedUDPPorts")
    if jq_cmd -e 'index(9757)' <<<"$tcp_if" >/dev/null 2>&1; then
      pass "daily: enp5s0 allows TCP 9757 (WiVRn)"
    else
      fail "daily: enp5s0 missing TCP 9757" "got: $tcp_if"
    fi
    if jq_cmd -e 'index(9757)' <<<"$udp_if" >/dev/null 2>&1; then
      pass "daily: enp5s0 allows UDP 9757 (WiVRn)"
    else
      fail "daily: enp5s0 missing UDP 9757" "got: $udp_if"
    fi
  else
    info "first LAN interface is '$first' (skipping enp5s0 spot-check)"
  fi
else
  fail "daily: myOS.vr.lanInterfaces is empty (at least one interface required)"
fi

describe "WoL compatibility port (UDP 9 on LAN only) — not global"
# UDP 9 (discard) is the conventional port for WoL-over-UDP; NixOS firewall
# should allow it ONLY on the LAN interface, not globally.
udp_if_daily=$(nix_eval_daily 'networking.firewall.interfaces.enp5s0.allowedUDPPorts')
if jq_cmd -e 'index(9)' <<<"$udp_if_daily" >/dev/null 2>&1; then
  pass "daily: enp5s0 allows UDP 9 (WoL compatibility, LAN only)"
else
  # Not strictly a failure — WoL magic packets are layer-2 and don't need any
  # firewall rule. We only assert the port is NOT globally open.
  info "daily: UDP 9 not allowed on enp5s0 (WoL via L2 still works)"
fi
# Regression test: UDP 9 must NEVER appear in global `allowedUDPPorts`.
if jq_cmd -e 'index(9)' <<<"$udp_d" >/dev/null 2>&1; then
  fail "daily: UDP 9 must not be globally allowed (only on the LAN interface)"
else
  pass "daily: UDP 9 not in global allowedUDPPorts"
fi
# And UDP 7 (echo) must not appear anywhere — it was removed.
if jq_cmd -e 'index(7)' <<<"$udp_d" >/dev/null 2>&1; then
  fail "daily: UDP 7 (echo) reappeared in global allowedUDPPorts" \
    "This was removed in the 2026-04 pen-test pass. Re-adding requires a FEATURES.md entry."
else
  pass "daily: UDP 7 stays removed"
fi
if jq_cmd -e 'index(7)' <<<"$udp_if_daily" >/dev/null 2>&1; then
  fail "daily: UDP 7 reappeared on enp5s0 (not expected)"
else
  pass "daily: UDP 7 not on enp5s0"
fi

describe "Steam remote-play is not opening the firewall"
assert_eq "$(nix_eval_daily 'programs.steam.enable')" 'true' "Steam is enabled on daily"
# programs.steam exposes remotePlay.openFirewall under a gating attr; our
# gaming.nix sets it to false. We only check the end effect: no Steam ports
# in the global allowed set (ports 27031-27036 are Steam's remote-play range).
for p in 27031 27032 27033 27034 27035 27036; do
  if jq_cmd -e "index($p)" <<<"$tcp_d" >/dev/null 2>&1; then
    fail "daily: TCP $p (Steam remote-play) is globally allowed"
  fi
  if jq_cmd -e "index($p)" <<<"$udp_d" >/dev/null 2>&1; then
    fail "daily: UDP $p (Steam remote-play) is globally allowed"
  fi
done
pass "daily: Steam remote-play ports stay closed"
