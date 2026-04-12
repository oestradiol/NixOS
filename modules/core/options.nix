{ lib, ... }:
{
  options.myOS = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "nvidia" "amd" ];
      default = "nvidia";
      description = "Primary GPU stack.";
    };

    profile = lib.mkOption {
      type = lib.types.enum [ "daily" "paranoid" ];
      default = "daily";
      description = "Current trust profile.";
    };

    gaming.controllers.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Bluetooth and Xbox controller support (xpadneo, game-devices-udev-rules).";
    };

    gaming.sysctls = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "SteamOS-aligned scheduler tuning and RT scheduling.";
    };

    persistence.root = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Persist mount used by impermanence.";
    };

    security = {
      # ── Staged enablement (off until post-install) ──────────────
      secureBoot.enable = lib.mkEnableOption "Secure Boot via Lanzaboote";
      tpm.enable = lib.mkEnableOption "TPM-backed LUKS enrollment workflow";

      # ── Infrastructure toggles ──────────────────────────────────
      impermanence.enable = lib.mkEnableOption "tmpfs root + explicit persistence";
      agenix.enable = lib.mkEnableOption "agenix secrets";
      mullvad.enable = lib.mkEnableOption "Mullvad daemon";
      mullvad.lockdown = lib.mkEnableOption "Mullvad strict lockdown use-case";

      # ── Profile policy ──────────────────────────────────────────
      sandboxedBrowsers.enable = lib.mkEnableOption "Use sandboxed browser wrappers exclusively (disables base Firefox). When enabled, only safe-firefox, safe-tor-browser, and safe-mullvad-browser are available. When disabled, base Firefox with moderate hardening is used.";
      disableSMT = lib.mkEnableOption "Disable SMT (nosmt=force)";
      ptraceScope = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "kernel.yama.ptrace_scope (0=classic, 1=restricted, 2=attached-only, 3=no-attach). Daily uses 1 for EAC compatibility, paranoid uses 2 for hardening.";
      };
      swappiness = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = ''
          vm.swappiness (0-200, default 30). Controls swap aggressiveness.
          With zram (RAM-compressed swap), HIGHER values are recommended
          because zram is fast (compression, not disk I/O).
          - zram setups: 150-180 recommended (Pop!_OS uses 180)
          - daily (gaming): 150 to balance zram use with avoiding compression overhead
          - paranoid (workstation): 180 for maximum zram benefit
          - traditional disk swap: 10-60 depending on RAM pressure
        '';
      };

      # ── Kernel hardening (tunable per profile) ──────────────────
      kernelHardening = {
        initOnAlloc = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Zero pages on allocation (init_on_alloc=1). <1% gaming impact.";
        };
        initOnFree = lib.mkEnableOption "Zero pages on free (init_on_free=1). 1-7% impact";
        slabNomerge = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Prevent slab cache merging (slab_nomerge). Negligible impact.";
        };
        pageAllocShuffle = lib.mkEnableOption "Randomize free page list (page_alloc.shuffle=1)";
        moduleBlacklist = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Blacklist dangerous kernel modules (dccp, sctp, rds, tipc, firewire).";
        };
        
        # Additional Madaidan-recommended kernel hardening (paranoid-tier)
        pti = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Kernel Page Table Isolation (pti=on). Mitigates Meltdown, prevents some KASLR bypasses. Negligible impact.";
        };
        vsyscallNone = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Disable vsyscalls (vsyscall=none). Prevents ROP attacks via fixed-address syscalls. May break very old binaries.";
        };
        oopsPanic = lib.mkEnableOption "Panic on kernel oops (oops=panic). Prevents exploit continuation but may crash on bad drivers.";
        moduleSigEnforce = lib.mkEnableOption "Only load signed kernel modules (module.sig_enforce=1). Breaks with custom/unsigned modules.";
        disableIcmpEcho = lib.mkEnableOption "Ignore ICMP echo requests (ping). Prevents network enumeration. May break some diagnostics.";
      };

      # ── System hardening (tunable per profile) ──────────────────
      apparmor = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "AppArmor MAC framework. ~1-3% syscall overhead. Can break proprietary applications.";
      };
      auditd = lib.mkEnableOption "Audit daemon (resource overhead, useful for forensics)";
      lockRoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Lock root account and restrict su to wheel group.";
      };
      usbRestrict = lib.mkEnableOption "USB authorized_default=2 (may block external hubs)";
      hardenedMemory.enable = lib.mkEnableOption "Graphene hardened allocator (stability risk)";

      # ── VM isolation layer (strongest practical sandbox) ───────
      vmIsolation.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable KVM/QEMU VM isolation layer for untrusted workloads.
          Provides stronger isolation than bubblewrap (separate kernel, hardware virtualization).
          Intended for paranoid profile use or specific untrusted applications.
          WARNING: Significant resource overhead. daily driver: compatible but not enabled by default.
        '';
      };

      # ── Sandboxed applications ─────────────────────────────────────
      sandboxedApps.enable = lib.mkEnableOption "Bubblewrap sandboxed applications for high-risk proprietary apps";

      # ── Machine ID persistence ────────────────────────────────────
      persistMachineId = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Persist /etc/machine-id across reboots via impermanence.
          When true (default), machine-id is stable (daily: operational stability).
          When false, machine-id is ephemeral and regenerated each boot
          (paranoid: less fingerprintable to local software).
        '';
      };

      # ── Sleep states (suspend/hibernate) ─────────────────────────
      allowSleep = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow system sleep states: suspend, hibernate, hybrid-sleep.
          Default is false (sleep disabled) because:
          - 16GB RAM + 8GB swap is insufficient for hibernation
          - NVIDIA proprietary drivers have known suspend/resume issues
          - tmpfs root + LUKS + sleep = complexity and potential data loss
          Both daily and paranoid profiles explicitly disable this.
          Enable only after testing on your specific hardware.
        '';
      };
    };
  };
}
