{ config, lib, pkgs, ... }:
{
  # mkForce required: specialisations merge with the base config via
  # extendModules. Without mkForce, options that differ from daily.nix
  # trigger "conflicting definition values" (mergeEqualOption).
  myOS.profile = lib.mkForce "paranoid";

  # Gaming explicitly disabled for security workstation profile
  myOS.gaming = {
    controllers.enable = lib.mkForce false;   # Bluetooth/USB controllers disabled
    sysctls = lib.mkForce false;              # SteamOS scheduler tuning disabled
  };

  myOS.security = {
    # Core infrastructure
    impermanence.enable = lib.mkForce true;
    agenix.enable = lib.mkForce true;

    # Machine ID: Whonix shared ID for privacy (blends with all Whonix users)
    # Default systemd-generated ID on daily for operational stability
    # Reference: https://github.com/Whonix/dist-base-files/blob/master/etc/machine-id
    persistMachineId = lib.mkForce true;
    machineIdValue = lib.mkForce "b08dfa6083e7567a1921a715000001fb";

    # Sleep states disabled (16GB RAM + 8GB swap insufficient; NVIDIA issues)
    allowSleep = lib.mkForce false;

    # VPN: self-owned WireGuard stack (not Mullvad app)
    # Provider: Mullvad servers | Control plane: NixOS (deterministic, auditable)
    # See: docs/PRE-INSTALL.md Section 15 for WireGuard config generation
    wireguardMullvad.enable = lib.mkForce true;
    # WireGuard secrets: provide via agenix in host secrets file
    # wireguardMullvad.privateKey = "<agenix-secret-reference>";
    # wireguardMullvad.endpoint = "<your-mullvad-server>:51820";
    # wireguardMullvad.address = "10.64.x.x/32";
    # wireguardMullvad.serverPublicKey = "<mullvad-server-pubkey>";
    # wireguardMullvad.dns = "10.64.0.1";  # Mullvad DNS through tunnel

    # Browser security (sandboxed only, with D-Bus filtering)
    sandbox.browsers = lib.mkForce true;
    sandbox.dbusFilter = lib.mkForce true;  # Filtered D-Bus for stronger isolation

    # CPU/System hardening
    disableSMT = lib.mkForce true;
    usbRestrict = lib.mkForce true;
    # Memory: swappiness 180 for maximum zram benefit (workstation, not gaming)
    # With zram, higher swappiness = more aggressive compression = effectively more RAM.
    # Paranoid uses 180 (Pop!_OS default) since there's no gaming pressure requiring
    # lower values. This maximizes the benefit of zram compression.
    # Reference: https://wiki.archlinux.org/title/Zram
    swappiness = lib.mkForce 180;

    # MAC and auditing
    apparmor = lib.mkForce true;    # MAC framework enforced
    auditd = lib.mkForce true;      # Full syscall auditing
    lockRoot = lib.mkForce true;     # Root account locked

    # Debug and privilege restrictions
    ptraceScope = lib.mkForce 2;  # Strictest: attached-only

    # VM tooling enabled (libvirtd, QEMU, KVM) — capability available, not automatic enforcement
    # To actually isolate browsers/apps in VMs: manually create VMs and run workloads there
    sandbox.vms = lib.mkForce true;
    sandbox.apps = lib.mkForce true;

    # Kernel hardening - ALL paranoid-tier options enabled
    kernelHardening = {
      # Base hardening (already default true, but explicit for paranoid)
      initOnAlloc = lib.mkForce true;
      slabNomerge = lib.mkForce true;
      moduleBlacklist = lib.mkForce true;
      pti = lib.mkForce true;
      vsyscallNone = lib.mkForce true;

      # Paranoid-tier performance-costly hardening
      initOnFree = lib.mkForce true;
      pageAllocShuffle = lib.mkForce true;
      oopsPanic = lib.mkForce true;
      moduleSigEnforce = lib.mkForce true;
      disableIcmpEcho = lib.mkForce true;

      # Stronger kernel controls (Madaidan-aligned): ENABLED on paranoid
      # One-way toggles for attack surface reduction
      kexecLoadDisabled = lib.mkForce true;   # Prevent runtime kernel replacement
      sysrqRestrict = lib.mkForce true;       # Disable magic SysRq key
      modulesDisabled = lib.mkForce false;    # DEFERRED: staged to POST-STABILITY
      # modules_disabled=1 breaks late module loading; enable only after all
      # required modules (NVIDIA, wireguard, etc.) are confirmed loaded at boot
      ioUringDisabled = lib.mkForce true;     # Reduce io_uring attack surface
    };

    # Staged enablement (explicitly disabled until post-install)
    secureBoot.enable = lib.mkForce false;   # Stage 2: enable after first boot
    tpm.enable = lib.mkForce false;           # Stage 2: enable after LUKS working

    # Hardened allocator - deferred until post-install stability testing
    # Per PROJECT-STATE: enable only after verifying no stability issues
    hardenedMemory.enable = lib.mkForce false;  # Graphene allocator - test post-install
  };

  programs.steam.enable = lib.mkForce false;
  programs.gamescope.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;
  services.wivrn.enable = lib.mkForce false;

  # Keep KDE + NVIDIA at first for reliability on this hardware.
}
