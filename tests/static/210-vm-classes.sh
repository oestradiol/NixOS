#!/usr/bin/env bash
# Static: vm-tooling.nix VM class definitions and option validation.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "VM tooling option defaults"

# VM configuration paths
storage_root=$(nix_eval 'myOS.security.vm.storageRoot')
assert_eq "$storage_root" '"/var/lib/libvirt/repo-vm"' "VM storage root uses expected default"

nat_network=$(nix_eval 'myOS.security.vm.natNetworkName')
assert_eq "$nat_network" '"repo-nat"' "NAT network name defaults to repo-nat"

isolated_network=$(nix_eval 'myOS.security.vm.isolatedNetworkName')
assert_eq "$isolated_network" '"repo-isolated"' "Isolated network name defaults to repo-isolated"

base_dir=$(nix_eval 'myOS.security.vm.defaultBaseImageDir')
assert_eq "$base_dir" '"/var/lib/libvirt/repo-vm/base"' "Base image dir uses expected default"

describe "VM tooling module structure"

vm_module="$REPO_ROOT/modules/security/vm-tooling.nix"
if [[ -r "$vm_module" ]]; then
  # Check for the four VM class definitions
  classes=(
    "trusted-work-vm"
    "risky-browser-vm"
    "malware-research-vm"
    "throwaway-untrusted-file-vm"
  )

  for class in "${classes[@]}"; do
    if grep -q "$class" "$vm_module"; then
      pass "VM class defined: $class"
    else
      fail "VM class missing: $class"
    fi
  done
else
  skip "vm-tooling.nix not readable"
fi

describe "VM class policy command"

# The helper script should have a policy command that outputs class definitions
if [[ -r "$vm_module" ]]; then
  if grep -q 'policy)' "$vm_module" && grep -q 'print_policy' "$vm_module"; then
    pass "repo-vm-class has policy command"
  else
    warn "policy command pattern not found"
  fi
fi

describe "VM class security properties"

if [[ -r "$vm_module" ]]; then
  # malware-research-vm should default to no network
  if grep -A5 'malware-research-vm)' "$vm_module" | grep -q 'CLASS_NETWORK="none"'; then
    pass "malware-research-vm defaults to no network"
  fi

  # throwaway-untrusted-file-vm should also default to no network
  if grep -A5 'throwaway-untrusted-file-vm)' "$vm_module" | grep -q 'CLASS_NETWORK="none"'; then
    pass "throwaway-untrusted-file-vm defaults to no network"
  fi

  # risky-browser-vm should be transient by default
  if grep -A10 'risky-browser-vm)' "$vm_module" | grep -q 'CLASS_TRANSIENT="yes"'; then
    pass "risky-browser-vm is transient by default"
  fi

  # malware-research-vm should reject NAT network
  if grep -q 'malware-research-vm.*may not use NAT' "$vm_module"; then
    pass "malware-research-vm has NAT rejection enforcement"
  fi
fi

describe "VM network XML definitions"

if [[ -r "$vm_module" ]]; then
  # Check that both NAT and isolated network XML are defined
  if grep -q 'virbr-repo-nat' "$vm_module"; then
    pass "NAT network bridge (virbr-repo-nat) defined"
  fi

  if grep -q 'virbr-repo-iso' "$vm_module"; then
    pass "Isolated network bridge (virbr-repo-iso) defined"
  fi

  # Check for the repo-libvirt-networks service
  if grep -q 'repo-libvirt-networks' "$vm_module"; then
    pass "repo-libvirt-networks service defined"
  fi
fi

describe "VM tooling conditional enablement"

# VM tooling is gated by myOS.security.sandbox.vms
vms_enabled=$(nix_eval 'myOS.security.sandbox.vms')
if [[ "$vms_enabled" == "false" || "$vms_enabled" == "null" ]]; then
  info "VM tooling disabled by default (myOS.security.sandbox.vms = $vms_enabled)"
else
  info "VM tooling enabled in test config: $vms_enabled"
fi

# Check libvirtd is conditional on sandbox.vms
libvirtd_enabled=$(nix_eval 'virtualisation.libvirtd.enable')
if [[ "$libvirtd_enabled" == "true" ]]; then
  pass "libvirtd.enable is true in evaluated config"
else
  info "libvirtd.enable is $libvirtd_enabled (may depend on sandbox.vms setting)"
fi
