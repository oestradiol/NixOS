#!/usr/bin/env bash
# Runtime: privacy posture enforcement verification. Tests that MAC
# randomization, TCP timestamps, and other privacy settings match config.
source "${BASH_SOURCE%/*}/../lib/common.sh"

posture=$(config_value "myOS.privacy.posture" | jq_cmd -r 'select(type=="string")')

if [[ -z "$posture" || "$posture" == "null" ]]; then
  info "privacy.posture not set, checking default behavior"
  posture="relaxed"  # Default per module
fi

describe "privacy posture = $posture"

describe "NetworkManager MAC randomization"

# Check NetworkManager WiFi MAC settings via nmcli if available
if command -v nmcli >/dev/null 2>&1; then
  wifi_mac=$(nmcli -g 802-11-wireless.cloned-mac-address connection show 2>/dev/null | head -1 || true)
  if [[ -n "$wifi_mac" ]]; then
    info "NetworkManager WiFi cloned-mac-address: $wifi_mac"

    if [[ "$posture" == "high" ]]; then
      if [[ "$wifi_mac" == "random" || "$wifi_mac" == "stable-ssid" ]]; then
        pass "High posture: WiFi MAC is randomized/randomized per SSID"
      else
        warn "High posture: WiFi MAC is $wifi_mac (expected random or stable-ssid)"
      fi
    else
      if [[ "$wifi_mac" == "preserve" || "$wifi_mac" == "permanent" || "$wifi_mac" == "stable-ssid" ]]; then
        pass "Relaxed posture: WiFi MAC is stable"
      else
        info "Relaxed posture: WiFi MAC is $wifi_mac"
      fi
    fi
  else
    info "Could not read NetworkManager WiFi MAC setting"
  fi
else
  skip "nmcli not available"
fi

describe "TCP timestamps sysctl"

# Read the current sysctl value
tcp_timestamps=$(sysctl -n net.ipv4.tcp_timestamps 2>/dev/null || echo "unknown")
info "Current net.ipv4.tcp_timestamps = $tcp_timestamps"

if [[ "$posture" == "high" ]]; then
  if [[ "$tcp_timestamps" == "0" ]]; then
    pass "High posture: TCP timestamps are disabled (0)"
  else
    warn "High posture: TCP timestamps are $tcp_timestamps (expected 0)"
  fi
else
  if [[ "$tcp_timestamps" == "1" ]]; then
    pass "Relaxed posture: TCP timestamps are enabled (1)"
  else
    info "Relaxed posture: TCP timestamps are $tcp_timestamps (expected 1)"
  fi
fi

describe "systemd MAC address policy"

# Check systemd.link files if they exist
link_dir="/etc/systemd/network"
if [[ -d "$link_dir" ]]; then
  # Look for MAC randomization link files
  if [[ -r "$link_dir/mac-randomize.link" ]]; then
    info "MAC randomization link file exists"
    if grep -q 'MACAddressPolicy=random' "$link_dir"/*.link 2>/dev/null; then
      pass "systemd MACAddressPolicy set to random"
    fi
  fi

  if [[ -r "$link_dir/mac-randomize-eth.link" ]]; then
    info "Ethernet MAC randomization link file exists"
  fi
else
  info "systemd network directory not present (ok for initrd-only systems)"
fi

describe "IPv6 privacy extensions"

# Check IPv6 privacy extensions
use_tempaddr=$(sysctl -n net.ipv6.conf.all.use_tempaddr 2>/dev/null || echo "unknown")
info "IPv6 use_tempaddr = $use_tempaddr"

if [[ "$use_tempaddr" == "2" ]]; then
  pass "IPv6 privacy extensions enabled (prefer temporary addresses)"
elif [[ "$use_tempaddr" == "1" ]]; then
  pass "IPv6 privacy extensions enabled (use temporary addresses)"
elif [[ "$use_tempaddr" == "0" ]]; then
  info "IPv6 privacy extensions disabled"
else
  info "Could not determine IPv6 privacy extensions state"
fi

describe "Network interface MAC addresses"

# List network interfaces and their MAC addresses
if command -v ip >/dev/null 2>&1; then
  ifaces=$(ip link show 2>/dev/null | grep -oE '^[0-9]+: [^:@]+' | sed 's/^[0-9]*: //' | grep -v '^lo$' || true)
  if [[ -n "$ifaces" ]]; then
    info "Network interfaces found:"
    for iface in $ifaces; do
      mac=$(ip link show "$iface" 2>/dev/null | grep -oE 'link/ether [^ ]+' | sed 's/link.ether //' || true)
      state=$(ip link show "$iface" 2>/dev/null | grep -oE 'state [^ ]+' | sed 's/state //' || true)
      if [[ -n "$mac" ]]; then
        info "  $iface: $mac ($state)"
      fi
    done
  fi
else
  skip "ip command not available"
fi

describe "privacy posture configuration summary"

cat <<EOF | while read line; do info "$line"; done
Privacy posture settings:
  - Configured posture: $posture
  - TCP timestamps: $tcp_timestamps
  - IPv6 privacy: $use_tempaddr
EOF

# Final posture verification
if [[ "$posture" == "high" ]]; then
  if [[ "$tcp_timestamps" == "0" ]]; then
    pass "High privacy posture verified: TCP timestamps disabled"
  fi
elif [[ "$posture" == "relaxed" ]]; then
  if [[ "$tcp_timestamps" == "1" ]]; then
    pass "Relaxed privacy posture verified: TCP timestamps enabled"
  fi
fi
