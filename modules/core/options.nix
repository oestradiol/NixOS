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

      # ── Self-owned WireGuard stack (paranoid: recommended over Mullvad app) ──
      wireguardMullvad.enable = lib.mkEnableOption ''
        Self-owned WireGuard tunnel to Mullvad servers (paranoid profile).
        
        Provider: Mullvad (servers only)
        Control plane: NixOS (interface, routes, firewall, config)
        
        This removes the split-authority problem where Mullvad app owned
        connection state but the repo owned a separate firewall story.
        
        With this option:
        - No Mullvad app daemon (services.mullvad-vpn disabled)
        - WireGuard config is the single source of truth
        - Firewall rules are generated from the same config
        - NixOS owns tunnel state AND firewall policy
        - Deterministic, auditable, self-owned enforcement
        
        Required: wireguardMullvad.privateKeyFile, endpoint, address, serverPublicKey
      '';
      wireguardMullvad.privateKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Path to WireGuard private key file (your key).
          Use agenix or sops to provide this securely.
          Generate via: wg genkey | tee privatekey | wg pubkey > publickey
          Example: config.age.secrets.wg-private-key.path
        '';
      };
      wireguardMullvad.presharedKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Path to optional preshared key file for additional symmetric encryption layer.
          Provides post-quantum resistance to the handshake.
          Generate via: wg genpsk > presharedkey
          Example: config.age.secrets.wg-preshared-key.path
        '';
      };
      wireguardMullvad.address = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "10.64.123.45/32";
        description = ''
          WireGuard tunnel IP address assigned by Mullvad.
          Found in your Mullvad WireGuard config file.
        '';
      };
      wireguardMullvad.dns = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "10.64.0.1";
        description = ''
          DNS server to use through the tunnel (Mullvad's DNS).
          Leave empty to use system default (not recommended for paranoid).
        '';
      };
      wireguardMullvad.endpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "146.70.34.211:51820";
        description = ''
          Mullvad server endpoint.
          Repo policy for paranoid: use a literal pinned IP:port, not a hostname.
          Resolve and pin it from a trusted environment before install.
          Choose relay details from: https://mullvad.net/en/servers/
        '';
      };
      wireguardMullvad.serverPublicKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Mullvad server's WireGuard public key.
          Found in your Mullvad WireGuard config file.
        '';
      };
      wireguardMullvad.allowedIPs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "0.0.0.0/0" "::/0" ];
        description = ''
          IPs to route through the tunnel (default: all traffic / full killswitch).
          0.0.0.0/0 and ::/0 routes ALL traffic through VPN.
          Use specific subnets for split tunneling (not recommended for paranoid).
        '';
      };
      wireguardMullvad.persistentKeepalive = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = ''
          Keepalive interval in seconds (default: 25).
          Important for NAT traversal and maintaining connection.
          Set to 0 to disable, but this may cause NAT timeout issues.
        '';
      };

      # ── Sandboxing (unified group) ──────────────────────────────
      sandbox = {
        browsers = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Use sandboxed browser wrappers exclusively instead of base Firefox.
            When enabled, only safe-firefox, safe-tor-browser, and safe-mullvad-browser are available.
            When disabled, base Firefox with moderate hardening is used.

            This provides tightened local browser containment via bubblewrap:
            dedicated user namespace, filtered D-Bus when enabled, exact runtime socket binds,
            and no broad home or /var exposure. Host networking is still shared.
          '';
        };
        apps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable tightened bubblewrap wrappers for non-Flatpak desktop apps.
            Current scope: VRCX and Windsurf on the daily profile only.
            These wrappers use exact persistence binds, private runtime directories,
            and filtered D-Bus when enabled. They are not VM-equivalent isolation.
          '';
        };
        vms = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable KVM/QEMU VM tooling layer for untrusted workloads.
            Provides stronger isolation than same-kernel bubblewrap paths.
            Repo policy defines four workflow classes: trusted-work-vm,
            risky-browser-vm, malware-research-vm, and throwaway-untrusted-file-vm.
            The host tooling layer will define helper networks and class-aware launch helpers,
            but guest images and some workflow validation still remain an operator task.
          '';
        };
        dbusFilter = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable filtered D-Bus access via xdg-dbus-proxy for bubblewrap sandboxes.
            Applies to both browser wrappers and daily app wrappers.
            When false, no D-Bus proxy socket is exposed by these wrappers.
          '';
        };
      };



      vm = {
        storageRoot = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/libvirt/repo-vm";
          description = "Root directory for repo-managed VM disks, overlays, state, and helper assets.";
        };
        natNetworkName = lib.mkOption {
          type = lib.types.str;
          default = "repo-nat";
          description = "Name of the repo-managed libvirt NAT network for VM classes that permit outbound connectivity.";
        };
        isolatedNetworkName = lib.mkOption {
          type = lib.types.str;
          default = "repo-isolated";
          description = "Name of the repo-managed libvirt isolated network for staged research traffic with no external connectivity.";
        };
        defaultBaseImageDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/libvirt/repo-vm/base";
          description = "Directory containing operator-supplied base qcow2 images used by the VM class helper.";
        };
      };

      disableSMT = lib.mkEnableOption "Disable SMT (nosmt=force)";
      ptraceScope = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "kernel.yama.ptrace_scope (0=classic, 1=restricted, 2=attached-only, 3=no-attach). Default 1 for EAC/daily compatibility; paranoid forces 2 for hardening.";
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
        pageAllocShuffle = lib.mkOption {
          type = lib.types.bool;
          default = true; # Negligible impact
          description = "Randomize free page list (page_alloc.shuffle=1)";
        };
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

        # Stronger kernel controls (Madaidan-aligned)
        kexecLoadDisabled = lib.mkEnableOption ''
          Disable kexec (kernel.kexec_load_disabled=1). Prevents loading a new kernel
          from userland at runtime. One-way toggle; requires reboot to re-enable.
        '';
        sysrqRestrict = lib.mkEnableOption ''
          Restrict SysRq key (kernel.sysrq). 0=disable, 4=only sync/reboot.
          Prevents debugging/inspection via magic SysRq key.
        '';
        modulesDisabled = lib.mkEnableOption ''
          Disable module loading after boot (kernel.modules_disabled=1).
          One-way toggle; breaks loading any new modules after boot.
          Only useful with all required modules built-in or loaded at boot.
        '';
        ioUringDisabled = lib.mkEnableOption ''
          Disable io_uring system-wide (kernel.io_uring_disabled=1).
          Reduces attack surface; io_uring has had multiple CVEs.
          May break applications using io_uring (high-performance I/O).
        '';
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

      aide.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          AIDE integrity monitoring (file hash-based change detection).
          Complements ClamAV: AIDE catches unknown malware/rootkits by detecting
          file changes, while ClamAV catches known malware via signatures.
          Weekly scans of persisted directories. Set false for ClamAV-only.
        '';
      };

      # ── PAM profile-binding (high-risk, opt-in) ────────────────────
      pamProfileBinding.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          EXPERIMENTAL: Enforce user/profile binding via PAM (daily=player, paranoid=ghost).
          WARNING: This modifies PAM service files directly (.text override) which is a
          high-risk implementation. May cause authentication lockouts if misconfigured.
          Only enable after post-stability testing and document the recovery path first. See docs/POST-STABILITY.md.
        '';
      };

      # ── Machine ID configuration ────────────────────────────────────
      persistMachineId = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Persist /etc/machine-id across reboots via impermanence.
          Both profiles use a unique persisted host ID for operational stability and
          to follow systemd guidance that machine-id should be locally unique.
        '';
      };
      machineIdValue = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Explicit machine-id value to set. When null, systemd generates the ID.
          Recommended policy for both profiles: null, then persist the generated ID.

          Set a literal value only for an exceptional operational reason and document it in
          PROJECT-STATE.md, TEST-PLAN.md, and RECOVERY.md.
        '';
      };

      # ── Sleep states (suspend/hibernate) ─────────────────────────
      allowSleep = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow system sleep states: suspend, hibernate, hybrid-sleep.
          Disabled by default due to tmpfs+LUKS complexity and 16GB RAM + 8GB swap being insufficient for hibernation.
        '';
      };
    };
  };
}
