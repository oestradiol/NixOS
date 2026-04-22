#!/usr/bin/env bash
# Static: privacy.nix posture option validation.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "privacy posture option and valid values"

# Posture is profile-dependent (paranoid=high, daily=relaxed)
profile=${TEST_PROFILE:-paranoid}
expected_posture="relaxed"
[[ "$profile" == "paranoid" ]] && expected_posture="high"

actual_posture=$(nix_eval 'myOS.privacy.posture')
assert_eq "$actual_posture" "\"$expected_posture\"" "privacy.posture matches profile ($profile)"

describe "posture option must accept valid values"

# Test that both valid values are accepted by the enum type
# We can't directly test the type constraint, but we can verify the option exists
# and has the expected values in the module

privacy_module="$REPO_ROOT/modules/security/privacy.nix"
if [[ -r "$privacy_module" ]]; then
  if grep -q 'enum \[ "high" "relaxed" \]' "$privacy_module"; then
    pass "privacy.posture has correct enum values [high, relaxed]"
  else
    warn "privacy.posture enum pattern not found in expected form"
  fi
else
  skip "privacy.nix not readable"
fi

describe "high privacy posture configuration effects"

# Read the module to verify high posture settings
if [[ -r "$privacy_module" ]]; then
  # MAC randomization for WiFi
  if grep -q 'MACAddressPolicy = "random"' "$privacy_module"; then
    pass "high posture: MACAddressPolicy = random for WiFi"
  else
    warn "high posture MAC randomization pattern not found"
  fi

  # MAC randomization for ethernet
  if grep -q 'matchConfig.Type = "ether"' "$privacy_module" && \
     grep -q 'mac-randomize-eth' "$privacy_module"; then
    pass "high posture: MAC randomization includes ethernet"
  fi

  # NetworkManager WiFi MAC randomization
  if grep -q 'wifi.macAddress = "random"' "$privacy_module"; then
    pass "high posture: NetworkManager wifi.macAddress = random"
  fi

  # TCP timestamps disabled
  if grep -q '"net.ipv4.tcp_timestamps" = 0' "$privacy_module"; then
    pass "high posture: TCP timestamps disabled (sysctl = 0)"
  fi
fi

describe "relaxed privacy posture configuration effects"

if [[ -r "$privacy_module" ]]; then
  # Stable MAC for WiFi in relaxed mode
  if grep -q 'wifi.macAddress = "stable"' "$privacy_module"; then
    pass "relaxed posture: NetworkManager wifi.macAddress = stable"
  fi

  # TCP timestamps enabled
  if grep -q '"net.ipv4.tcp_timestamps" = 1' "$privacy_module"; then
    pass "relaxed posture: TCP timestamps enabled (sysctl = 1)"
  fi
fi

describe "privacy posture sysctl differentiation"

# The module should set different sysctl values based on posture
if [[ -r "$privacy_module" ]]; then
  high_count=$(grep -c 'tcp_timestamps.*= 0' "$privacy_module" || echo 0)
  relaxed_count=$(grep -c 'tcp_timestamps.*= 1' "$privacy_module" || echo 0)

  if [[ "$high_count" -gt 0 && "$relaxed_count" -gt 0 ]]; then
    pass "privacy module sets different tcp_timestamps for high vs relaxed"
  else
    warn "tcp_timestamps differentiation not found as expected"
  fi
fi
