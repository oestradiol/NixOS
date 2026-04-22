#!/usr/bin/env bash
# Runtime: VM network isolation verification. Tests that libvirt networks
# are properly configured when VM tooling is enabled.
source "${BASH_SOURCE%/*}/../lib/common.sh"

# Check if VM tooling is enabled
vms_enabled=$(config_value "myOS.security.sandbox.vms")
if [[ "$vms_enabled" != "true" ]]; then
  skip "VM tooling not enabled (myOS.security.sandbox.vms != true)"
  exit 0
fi

describe "libvirtd service state"

if has_unit libvirtd.service; then
  pass "libvirtd.service unit exists"
  state=$(systemctl is-active libvirtd.service 2>&1 || true)
  info "libvirtd state: $state"
else
  warn "libvirtd.service unit not found"
fi

describe "repo-managed network definitions"

# Get configured network names from config
nat_name=$(config_value "myOS.security.vm.natNetworkName" | jq_cmd -r 'select(type=="string")')
isolated_name=$(config_value "myOS.security.vm.isolatedNetworkName" | jq_cmd -r 'select(type=="string")')

# Default to expected values if not configured
[[ -z "$nat_name" || "$nat_name" == "null" ]] && nat_name="repo-nat"
[[ -z "$isolated_name" || "$isolated_name" == "null" ]] && isolated_name="repo-isolated"

info "Configured NAT network: $nat_name"
info "Configured isolated network: $isolated_name"

describe "network XML definitions in /etc"

# Check that network XML files are deployed
nat_xml="/etc/libvirt/repo-networks/${nat_name}.xml"
isolated_xml="/etc/libvirt/repo-networks/${isolated_name}.xml"

if [[ -r "$nat_xml" ]]; then
  pass "NAT network XML deployed: $nat_xml"
  # Verify it has the expected bridge name
  if grep -q 'virbr-repo-nat' "$nat_xml"; then
    pass "NAT XML contains expected bridge name (virbr-repo-nat)"
  fi
else
  info "NAT network XML not found at $nat_xml (may be created by service at runtime)"
fi

if [[ -r "$isolated_xml" ]]; then
  pass "Isolated network XML deployed: $isolated_xml"
  if grep -q 'virbr-repo-iso' "$isolated_xml"; then
    pass "Isolated XML contains expected bridge name (virbr-repo-iso)"
  fi
else
  info "Isolated network XML not found at $isolated_xml (may be created by service at runtime)"
fi

describe "repo-libvirt-networks service"

if has_unit repo-libvirt-networks.service; then
  pass "repo-libvirt-networks.service exists"
  state=$(systemctl is-active repo-libvirtd-networks.service 2>&1 || true)
  info "repo-libvirt-networks state: $state"
else
  info "repo-libvirt-networks.service not found (networks may be managed differently)"
fi

describe "virsh network status (if available)"

if command -v virsh >/dev/null 2>&1; then
  # List all networks
  networks=$(virsh net-list --all 2>/dev/null || true)
  if [[ -n "$networks" ]]; then
    info "virsh networks:\n$networks"

    # Check for our specific networks
    if echo "$networks" | grep -q "$nat_name"; then
      pass "NAT network ($nat_name) visible in virsh"
    else
      info "NAT network ($nat_name) not visible (may need to be defined)"
    fi

    if echo "$networks" | grep -q "$isolated_name"; then
      pass "Isolated network ($isolated_name) visible in virsh"
    else
      info "Isolated network ($isolated_name) not visible (may need to be defined)"
    fi
  else
    info "virsh net-list produced no output (libvirtd may not be running)"
  fi
else
  skip "virsh not available"
fi

describe "repo-vm-class helper availability"

if command -v repo-vm-class >/dev/null 2>&1; then
  pass "repo-vm-class helper in PATH"

  # Test the help/policy command
  if repo-vm-class help >/dev/null 2>&1; then
    pass "repo-vm-class help command works"
  fi

  # Check that policy command works for all classes
  for class in trusted-work-vm risky-browser-vm malware-research-vm throwaway-untrusted-file-vm; do
    if repo-vm-class policy "$class" >/dev/null 2>&1; then
      pass "repo-vm-class policy $class works"
    else
      warn "repo-vm-class policy $class failed"
    fi
  done
else
  warn "repo-vm-class helper not in PATH"
fi

describe "VM network isolation verification"

# Verify that malware-research-vm and throwaway-untrusted-file-vm
# have correct network isolation via the policy command

if command -v repo-vm-class >/dev/null 2>&1; then
  # Check malware-research-vm policy
  malware_policy=$(repo-vm-class policy malware-research-vm 2>/dev/null || true)
  if [[ "$malware_policy" == *"none by default"* || "$malware_policy" == *"Network: none"* ]]; then
    pass "malware-research-vm policy specifies no network by default"
  fi

  # Check throwaway-untrusted-file-vm policy
  throwaway_policy=$(repo-vm-class policy throwaway-untrusted-file-vm 2>/dev/null || true)
  if [[ "$throwaway_policy" == *"none by default"* || "$throwaway_policy" == *"Network: none"* ]]; then
    pass "throwaway-untrusted-file-vm policy specifies no network by default"
  fi

  # Check that NAT is rejected for malware-research-vm
  # This is enforced by the create command, not visible in policy output
  # but we check that the policy mentions the restriction
  if [[ "$malware_policy" == *"isolated only"* || "$malware_policy" == *"no external connectivity"* ]]; then
    pass "malware-research-vm policy mentions network restrictions"
  fi
fi

describe "virt-manager availability"

if command -v virt-manager >/dev/null 2>&1; then
  pass "virt-manager in PATH"
else
  info "virt-manager not in PATH (may be desktop entry only)"
fi

describe "VM storage directory structure"

storage_root=$(config_value "myOS.security.vm.storageRoot" | jq_cmd -r 'select(type=="string")')
[[ -z "$storage_root" || "$storage_root" == "null" ]] && storage_root="/var/lib/libvirt/repo-vm"

if [[ -d "$storage_root" ]]; then
  pass "VM storage root exists: $storage_root"

  # Check for expected subdirectories
  for subdir in base persistent transient; do
    if [[ -d "$storage_root/$subdir" ]]; then
      pass "VM storage subdirectory exists: $subdir"
    else
      info "VM storage subdirectory missing: $subdir (may be created on demand)"
    fi
  done
else
  info "VM storage root does not exist: $storage_root"
fi
