{ config, lib, pkgs, ... }:
{
  # DAILY PROFILE: Maximally hardened within gaming/VR/socialization constraints
  #
  # Philosophy: Enable ALL security features that don't break gaming, VRChat,
  # Discord, streaming, or common social platforms. Document every compromise.
  #
  # Practical Limits (intentionally disabled due to high friction):
  # - WebRTC: ENABLED (required for Discord video, VRChat, streaming)
  # - ptraceScope: 1 (not 2) - EAC anti-cheat requirement
  # - disableSMT: false - 30-40% CPU performance loss unacceptable for gaming
  # - mullvad.lockdown: false - Gaming without VPN is common/expected
  # - sandboxedBrowsers: false - Base Firefox with maximal prefs instead
  # - auditd: false - Performance overhead, noise for daily use
  # - usbRestrict: false - External hubs/docks need to work
  # - vmIsolation: false - Significant resource overhead
  # - Kernel: base tier only (initOnFree/pageAllocShuffle/oopsPanic disabled)
  #
  # What IS maximally enabled:
  # - All base kernel hardening (initOnAlloc, slabNomerge, pti, vsyscallNone, moduleBlacklist)
  # - Paranoid-tier kernel: 3 of 5 enabled (pageAllocShuffle, moduleSigEnforce, disableIcmpEcho)
  #   Only initOnFree (perf) and oopsPanic (stability) disabled
  # - AppArmor MAC framework (monitor for game breakage)
  # - Impermanence + agenix (infrastructure)
  # - Mullvad VPN (non-lockdown)
  # - Sandboxed apps (VRCX, Windsurf wrapped)
  # - Firefox: 60+ hardening prefs including FPP (gaming is Steam/VRCX, not browser)
  # - Zram-optimized memory settings
  # - Gaming features (controllers, SteamOS sysctls)
  #
  myOS.profile = "daily";
  myOS.gpu = "nvidia";

  # Gaming features enabled for daily use
  myOS.gaming = {
    controllers.enable = true;  # Bluetooth/Xbox controller support
    sysctls = true;               # SteamOS scheduler tuning
  };

  myOS.security = {
    # Core infrastructure
    impermanence.enable = true;
    agenix.enable = true;

    # Staged enablement (disabled until post-install enrollment)
    # These require manual key enrollment after first successful boot
    secureBoot.enable = false;
    tpm.enable = false;

    # VPN enabled but NOT lockdown (allows gaming without VPN)
    mullvad.enable = true;
    mullvad.lockdown = false;

    # Browser: base Firefox with moderate hardening (not sandboxed wrappers)
    # Compromise: sandboxedBrowsers.enable = false for gaming/streaming convenience
    sandboxedBrowsers.enable = false;

    # CPU: SMT enabled for gaming performance (nosmt would cost 30-40% throughput)
    disableSMT = false;

    # Memory: swappiness 150 for zram optimization (16GB RAM)
    # With zram (RAM-compressed swap), HIGHER swappiness is better - it encourages
    # compressing idle pages rather than keeping them uncompressed. zram is fast
    # (orders of magnitude faster than disk), so aggressive swapping is beneficial.
    # Pop!_OS uses 180; we use 150 for gaming to balance zram use with avoiding
    # compression overhead during intense VR/gaming loads.
    # Reference: https://wiki.archlinux.org/title/Zram
    swappiness = 150;

    # Debug: ptraceScope 1 for EAC anti-cheat compatibility
    # Compromise: ptraceScope 2 would break VRChat and many games
    ptraceScope = 1;

    # USB: not restricted (allows external hubs, docks, new peripherals)
    # Compromise: usbRestrict would block external USB devices
    usbRestrict = false;

    # Auditing: disabled by default (performance, noise)
    # Compromise: auditd would log all syscalls for forensics
    auditd = false;

    # Base security (enabled despite conservative defaults)
    # Compromise: apparmor could break some proprietary games but provides MAC protection
    apparmor = true;     # MAC framework - monitor for breakage with specific games
    lockRoot = true;     # Locked root account - no compromise here

    # VM/App sandboxing: enabled for untrusted apps
    vmIsolation.enable = false;   # Significant overhead, manual enable if needed
    sandboxedApps.enable = true;  # VRCX, Windsurf wrapped

    # Kernel hardening (maximal for daily - only disable what breaks apps or severe perf)
    kernelHardening = {
      # Base tier - always enabled (negligible impact)
      initOnAlloc = true;      # Zero pages on allocation
      slabNomerge = true;      # Prevent slab merging
      moduleBlacklist = true;  # Blacklist dangerous modules
      pti = true;              # Meltdown mitigation
      vsyscallNone = true;     # Disable vsyscalls

      # Paranoid-tier: ENABLED (no app breakage, acceptable overhead)
      # pageAllocShuffle: minor overhead, no gaming impact
      pageAllocShuffle = true;
      # moduleSigEnforce: no custom modules needed for gaming
      moduleSigEnforce = true;
      # disableIcmpEcho: only breaks ping, not gaming/VRChat
      disableIcmpEcho = true;

      # Paranoid-tier: DISABLED (performance or stability impact)
      # initOnFree: 1-7% performance cost - measurable in gaming
      initOnFree = false;
      # oopsPanic: GPU driver bugs (common with VRChat/NVIDIA) become crashes
      oopsPanic = false;
    };

    # Hardened allocator: DISABLED (stability risk)
    # Per PROJECT-STATE: deferred until post-install testing
    hardenedMemory.enable = false;
  };

  imports = [ ../modules/desktop/gaming.nix ];
}
