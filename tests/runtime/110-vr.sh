#!/usr/bin/env bash
# Runtime: WiVRn VR layer (daily only).
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_profile daily

describe "wivrn service declared + state"
# services.wivrn enables a system unit; it may be inactive until a VR client
# connects. Accept active OR loaded-but-inactive as long as the unit exists.
if systemctl cat wivrn.service >/dev/null 2>&1; then
  pass "wivrn.service unit is defined"
  state=$(systemctl is-active wivrn.service 2>&1 || true)
  case "$state" in
    active) pass "wivrn.service active" ;;
    inactive|failed) warn "wivrn.service state: $state (may be on-demand)" ;;
    *) info "wivrn.service state: $state" ;;
  esac
else
  fail "wivrn.service unit missing"
fi

describe "wivrn listening port (UDP 9757 by default)"
# WiVRn opens firewall via openFirewall=true. Check nftables for the port.
if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
  if sudo -n nft list ruleset 2>/dev/null | grep -qE 'udp.*(9757|wivrn)'; then
    pass "nftables mentions wivrn/9757"
  else
    warn "could not locate wivrn port in nftables rules (may use dynamic port)"
  fi
fi

describe "realtime-priority constraints for VR"
# security.pam.loginLimits must grant memlock=unlimited and @realtime rtprio.
limits=/etc/security/limits.conf
if [[ -r $limits ]]; then
  if grep -q 'memlock.*unlimited' "$limits"; then pass "memlock unlimited in limits.conf"; else warn "memlock=unlimited not in limits.conf"; fi
  if grep -q '@realtime.*rtprio.*99' "$limits"; then pass "@realtime rtprio=99 in limits.conf"; else warn "@realtime rtprio=99 not in limits.conf"; fi
fi

describe "user wivrn unit has RT priority overrides"
if systemctl --user cat wivrn.service 2>/dev/null | grep -qE 'LimitRTPRIO=99'; then
  pass "user wivrn.service has LimitRTPRIO=99"
else
  info "user wivrn.service override not observable (may need user scope)"
fi

describe "wayvr (overlay) shipped as part of gaming stack"
if command -v wayvr >/dev/null 2>&1 || find /run/current-system/sw -name 'wayvr*' 2>/dev/null | grep -q .; then
  pass "wayvr binary present"
else
  warn "wayvr not found in system environment"
fi
