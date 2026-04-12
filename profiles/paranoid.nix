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

    # Machine ID: random on paranoid for privacy (less fingerprintable to local software)
    # daily keeps it persistent for operational stability (D-Bus, systemd state)
    persistMachineId = lib.mkForce false;

    # Sleep states disabled (16GB RAM + 8GB swap insufficient; NVIDIA issues)
    allowSleep = lib.mkForce false;

    # VPN and networking (strict)
    mullvad.enable = lib.mkForce true;
    mullvad.nftablesFallback = lib.mkForce true;  # Option B: Emergency fail-closed local fallback

    # Browser security (sandboxed only, with D-Bus filtering)
    sandboxedBrowsers.enable = lib.mkForce true;
    sandboxedBrowsers.dbusFilter = lib.mkForce true;  # Filtered D-Bus for stronger isolation

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
    vmIsolation.enable = lib.mkForce true;
    sandboxedApps.enable = lib.mkForce true;

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
