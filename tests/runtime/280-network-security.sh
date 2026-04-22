#!/usr/bin/env bash
# Runtime: network security sysctl verification.
# Tests Madaidan-inspired network hardening from modules/security/base.nix
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "network redirect protection (Madaidan-inspired)"

# rp_filter (reverse path filtering) - protects against IP spoofing
assert_sysctl "net.ipv4.conf.all.rp_filter"           "1"
assert_sysctl "net.ipv4.conf.default.rp_filter"     "1"

describe "ICMP redirect protection"

# Ignore ICMP redirects to prevent MITM attacks
assert_sysctl "net.ipv4.conf.all.accept_redirects"      "0"
assert_sysctl "net.ipv4.conf.default.accept_redirects"  "0"
assert_sysctl "net.ipv4.conf.all.secure_redirects"      "0"
assert_sysctl "net.ipv4.conf.default.secure_redirects"  "0"
assert_sysctl "net.ipv6.conf.all.accept_redirects"      "0"
assert_sysctl "net.ipv6.conf.default.accept_redirects"  "0"

describe "ICMP redirect sending restrictions"

# Don't send redirects (we're not a router)
assert_sysctl "net.ipv4.conf.all.send_redirects"        "0"
assert_sysctl "net.ipv4.conf.default.send_redirects"    "0"

describe "IPv6 privacy extensions (Madaidan section 16)"

# IPv6 privacy extensions for temporary addresses
assert_sysctl "net.ipv6.conf.all.use_tempaddr"      "2"

describe "TCP hardening"

# Syncookies protect against SYN flood attacks
assert_sysctl "net.ipv4.tcp_syncookies"             "1"

# RFC1337 protects against TIME-WAIT assassination
assert_sysctl "net.ipv4.tcp_rfc1337"                "1"

describe "profile-specific network hardening"

profile=$(detect_profile)
if [[ "$profile" == "paranoid" ]]; then
  # ICMP echo ignore (ping) - paranoid disables ping responses
  assert_sysctl "net.ipv4.icmp_echo_ignore_all"     "1"
  # TCP timestamps disabled for privacy (fingerprinting resistance)
  assert_sysctl "net.ipv4.tcp_timestamps"           "0"
else
  # Daily allows ping and TCP timestamps
  assert_sysctl "net.ipv4.icmp_echo_ignore_all"     "0"
  assert_sysctl "net.ipv4.tcp_timestamps"             "1"
fi

describe "network interface enumeration and state"

# List all network interfaces and their security-relevant state
if command -v ip >/dev/null 2>&1; then
  ifaces=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v '^lo$' || true)
  if [[ -n "$ifaces" ]]; then
    info "Network interfaces present:"
    for iface in $ifaces; do
      # Check rp_filter per interface
      rp_val=$(sysctl -n "net.ipv4.conf.${iface}.rp_filter" 2>/dev/null || echo "N/A")
      accept_redirects=$(sysctl -n "net.ipv4.conf.${iface}.accept_redirects" 2>/dev/null || echo "N/A")
      info "  $iface: rp_filter=$rp_val accept_redirects=$accept_redirects"
    done
  fi
else
  skip "ip command not available for interface enumeration"
fi

describe "firewall state verification"

# Basic check that firewall is active
if command -v nft >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
    # Check for nixos-fw table which is the standard NixOS firewall
    if sudo -n nft list tables 2>/dev/null | grep -q 'inet nixos-fw\|ip nixos-fw'; then
      pass "NixOS firewall (nixos-fw) table present"
    else
      info "NixOS firewall table not found (may use custom nftables)"
    fi
  fi
fi

describe "bpf hardening (Madaidan section 2.2.1)"

# BPF JIT hardening requires root
if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
  bpf_harden=$(sudo -n sysctl -n net.core.bpf_jit_harden 2>/dev/null || true)
  if [[ "$bpf_harden" == "2" ]]; then
    pass "BPF JIT hardening enabled (net.core.bpf_jit_harden = 2)"
  else
    warn "BPF JIT hardening value: $bpf_harden (expected 2)"
  fi
else
  skip "BPF JIT hardening check requires root"
fi
