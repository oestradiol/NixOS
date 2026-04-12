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
  # Support both old and new option paths during transition
  vmsEnabled = config.myOS.security.sandbox.vms;
  
  # Determine KVM module based on CPU - defaults to AMD for this hardware
  kvmModule = if config.hardware.cpu.intel.updateMicrocode or false 
                then "kvm-intel" 
                else "kvm-amd";
in {
  config = lib.mkIf vmsEnabled {
    # Core virtualization stack
    # NixOS Wiki: https://wiki.nixos.org/wiki/Libvirt
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
    
    # TPM emulation for VMs (optional but recommended)
    virtualisation.libvirtd.qemu.swtpm.enable = true;
    
    # QEMU with hardened options
    # MyNixOS: virtualisation.libvirtd.qemu.verbatimConfig
    virtualisation.libvirtd.qemu.verbatimConfig = ''
      # Hardened QEMU settings
      seccomp_sandbox = 1
      spice_tls = 1
      vnc_tls = 1
      vnc_tls_x509_verify = 1
    '';
    
    # virt-manager GUI (NixOS Wiki: programs.virt-manager.enable)
    programs.virt-manager.enable = true;
    
    # KVM kernel module - auto-detect AMD vs Intel
    boot.kernelModules = [ kvmModule ];
    
    # IOMMU for device passthrough (optional, advanced use)
    # AMD Ryzen 5 3600: AMD-V supported, AMD-Vi (IOMMU) limited for PCI passthrough
    # NixOS typically enables AMD IOMMU by default; intel_iommu only for Intel CPUs
    boot.kernelParams = lib.optionals vmsEnabled (
      if kvmModule == "kvm-intel" 
      then [ "iommu=pt" "intel_iommu=on" ]
      else [ "iommu=pt" "amd_iommu=on" ]  # AMD IOMMU explicit enable
    );
    
    # User access to libvirtd (NixOS Wiki requirement)
    users.users.player.extraGroups = [ "libvirtd" ];
    users.users.ghost.extraGroups = [ "libvirtd" ];
    
    # Tools for VM management
    environment.systemPackages = with pkgs; [
      virt-viewer         # SPICE/VNC viewer
      qemu_kvm            # QEMU with KVM support
      OVMF                # UEFI firmware for VMs (TianoCore)
      # swtpm provided by virtualisation.libvirtd.qemu.swtpm.enable
    ];
    
    # SPICE for seamless VM display integration
    services.spice-vdagentd.enable = true;

    # USB redirection is DISABLED by default - enable only if you need USB passthrough
    # This reduces attack surface; USB passthrough is a potential escape vector
    virtualisation.spiceUSBRedirection.enable = lib.mkDefault false;
    
    # Firejail not used (rejected in favor of bubblewrap + VMs)
    # Flatpak remains for application packaging, not primary isolation
    
    # NOTE: This is the strongest practical isolation layer available.
    # Even if a sophisticated threat actor compromises the VM, escape requires:
    # - KVM hypervisor exploit (historically rare, quickly patched)
    # - CPU speculative execution side-channel (mitigated with L1TF/VMD patches)
    # - Malicious device passthrough (disabled by default here)
    #
    # For maximum isolation: use this + bubblewrap inside VMs + browser hardening inside VMs.
  };
}
