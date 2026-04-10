# VM Isolation Layer
# Maximum practical sandbox using hardware virtualization (KVM/QEMU)
# Provides stronger isolation than bubblewrap: separate kernel, isolated memory, hardware-enforced boundaries
#
# Research grounding:
# - Madaidan Linux Hardening Guide: VMs as strongest practical sandbox boundary
# - Mozilla Security Wiki: process isolation limits vs VM isolation
# - KVM security: hardware-assisted virtualization (Intel VT-x/AMD-V) provides MMU-level isolation
#
# Trade-offs:
# - Significant resource overhead (memory, CPU cores, disk for each VM)
# - Boot latency (VM startup time vs process spawn)
# - Compatibility (PCI passthrough complexity, especially NVIDIA)
# - Maintenance (separate VM images, updates)
#
# Use cases:
# - Untrusted browser sessions beyond bubblewrap
# - Opening suspicious documents
# - Development of untrusted code
# - paranoid profile: daily driver compatible but not enabled by default

{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.security.vmIsolation;
in {
  config = lib.mkIf cfg.enable {
    # Core virtualization stack
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
    
    # QEMU with hardened options when available
    virtualisation.libvirtd.qemu.verbatimConfig = ''
      # Hardened QEMU settings
      seccomp_sandbox = 1
      spice_tls = 1
      vnc_tls = 1
      vnc_tls_x509_verify = 1
    '';
    
    # KVM kernel module loaded by libvirtd, but ensure it's available
    boot.kernelModules = [ "kvm-amd" ]; # Adjust for Intel: "kvm-intel"
    
    # IOMMU for device passthrough (optional, advanced use)
    boot.kernelParams = lib.optionals cfg.enable [
      "iommu=pt" # Passthrough mode (no DMA remapping overhead for unused devices)
      "intel_iommu=on" # For Intel; AMD enables by default with iommu=pt
    ];
    
    # User access
    users.groups.libvirtd.members = [ 
      config.users.users.player.name 
      config.users.users.ghost.name 
    ];
    
    # Tools for VM management
    environment.systemPackages = with pkgs; [
      virt-manager        # GUI VM management
      virt-viewer         # SPICE/VNC viewer
      qemu_kvm            # QEMU with KVM support
      OVMF                # UEFI firmware for VMs
      swtpm               # Software TPM for VM testing
    ];
    
    # SPICE for seamless VM display integration
    services.spice-vdagentd.enable = true;
    
    # Firejail not used (rejected in favor of bubblewrap + VMs)
    # Flatpak remains for application packaging, not primary isolation
    
    # NOTE: This is the strongest practical isolation layer available.
    # Even if a national-level actor compromises the VM, escape requires:
    # - KVM hypervisor exploit (historically rare, quickly patched)
    # - CPU speculative execution side-channel (mitigated with L1TF/VMD patches)
    # - Malicious device passthrough (disabled by default here)
    #
    # For maximum isolation: use this + bubblewrap inside VMs + browser hardening inside VMs.
  };
}
