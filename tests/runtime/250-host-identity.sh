#!/usr/bin/env bash
# Runtime: host identity verification. Template-agnostic: checks that
# hostname, timezone, locale match the booted configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "hostname matches configuration"
config_hostname=$(config_value "myOS.host.hostName" | jq_cmd -r 'select(type=="string")' 2>/dev/null || true)
actual_hostname=$(hostname 2>/dev/null || true)

if [[ "$config_hostname" == "null" || -z "$config_hostname" ]]; then
  info "myOS.host.hostName not set in config"
else
  assert_eq "$actual_hostname" "$config_hostname" "hostname matches myOS.host.hostName"
fi

describe "timezone matches configuration"
config_tz=$(config_value "myOS.host.timeZone" | jq_cmd -r 'select(type=="string")' 2>/dev/null || true)
# Resolve the symlink and extract the zoneinfo path
actual_tz=$(readlink -f /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || true)

if [[ "$config_tz" == "null" || -z "$config_tz" ]]; then
  info "myOS.host.timeZone not set in config"
else
  if [[ "$actual_tz" == "$config_tz" ]]; then
    pass "timezone matches myOS.host.timeZone = $config_tz"
  else
    # Try alternative: timedatectl
    timedate_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || true)
    if [[ "$timedate_tz" == "$config_tz" ]]; then
      pass "timezone matches (via timedatectl): $config_tz"
    else
      fail "timezone mismatch" "config: $config_tz" "actual: ${actual_tz:-<unknown>}"
    fi
  fi
fi

describe "locale matches configuration"
config_locale=$(config_value "myOS.host.defaultLocale" | jq_cmd -r 'select(type=="string")' 2>/dev/null || true)
actual_locale=${LANG:-}

if [[ "$config_locale" == "null" || -z "$config_locale" ]]; then
  info "myOS.host.defaultLocale not set in config"
else
  if [[ "$actual_locale" == "$config_locale" ]]; then
    pass "LANG matches myOS.host.defaultLocale = $config_locale"
  else
    # The actual locale might have encoding suffix
    if [[ "$actual_locale" == "$config_locale"* || "$config_locale" == "$actual_locale"* ]]; then
      pass "LANG compatible with myOS.host.defaultLocale: $actual_locale"
    else
      info "LANG = ${actual_locale:-<unset>}, config = $config_locale"
    fi
  fi
fi

describe "primary network interface"
config_iface=$(config_value "myOS.networking.primaryInterface" | jq_cmd -r 'select(type=="string")' 2>/dev/null || true)

if [[ "$config_iface" == "null" || -z "$config_iface" ]]; then
  info "myOS.networking.primaryInterface not set in config"
else
  # Check if the interface exists - try /sys if ip not available
  iface_found=false
  if command -v ip >/dev/null 2>&1; then
    if ip link show "$config_iface" >/dev/null 2>&1; then
      iface_found=true
    fi
  elif [[ -d "/sys/class/net/$config_iface" ]]; then
    iface_found=true
  fi
  
  if [[ "$iface_found" == true ]]; then
    pass "primary interface $config_iface exists"
    # Show its state if ip available
    if command -v ip >/dev/null 2>&1; then
      state=$(ip link show "$config_iface" 2>/dev/null | grep -oE 'state [^\s]+' | head -1 || true)
      if [[ -n "$state" ]]; then
        info "$config_iface $state"
      fi
    fi
  else
    warn "primary interface $config_iface not found on system"
    # List available interfaces for info
    if command -v ip >/dev/null 2>&1; then
      ifaces=$(ip link show 2>/dev/null | grep -oE '^[0-9]+: [^:@]+' | sed 's/^[0-9]*: //' | tr '\n' ' ' || true)
      info "available interfaces: $ifaces"
    elif [[ -d /sys/class/net ]]; then
      ifaces=$(ls /sys/class/net/ | tr '\n' ' ')
      info "available interfaces: $ifaces"
    fi
  fi
fi

describe "system state version"
# Check that stateVersion is set (important for NixOS upgrades)
state_version=$(config_value "system.stateVersion" 2>/dev/null || echo "null")
if [[ "$state_version" != "null" && -n "$state_version" ]]; then
  pass "system.stateVersion = $state_version"
else
  warn "system.stateVersion not visible in config"
fi

describe "NixOS version"
# Check the current NixOS version
if [[ -r /etc/os-release ]]; then
  nixos_version=$(grep -oP 'PRETTY_NAME=\K[^"]+' /etc/os-release 2>/dev/null || true)
  if [[ -n "$nixos_version" ]]; then
    pass "OS version: $nixos_version"
  fi
  
  # Also log the nixpkgs commit if available
  nixpkgs_commit=$(grep -oP 'VERSION_ID=[^"]*\.\K[^"]+' /etc/os-release 2>/dev/null || true)
  if [[ -n "$nixpkgs_commit" ]]; then
    info "nixpkgs commit: $nixpkgs_commit"
  fi
fi
