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
      default = "paranoid";
      description = "Current trust profile.";
    };

    persistence.root = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Persist mount used by impermanence.";
    };

    gaming = {
      controllers.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Bluetooth and Xbox controller support (xpadneo, game-devices-udev-rules).";
      };
    };

    security = {
      secureBoot.enable = lib.mkEnableOption "Secure Boot via Lanzaboote";
      tpm.enable = lib.mkEnableOption "TPM-backed LUKS enrollment workflow";

      impermanence.enable = lib.mkEnableOption "tmpfs root + explicit persistence";
      agenix.enable = lib.mkEnableOption "agenix secrets";

      wireguardMullvad = {
        enable = lib.mkEnableOption ''
          Self-owned WireGuard tunnel to Mullvad servers.

          Provider: Mullvad (servers only)
          Control plane: NixOS (interface, routes, firewall, config)

          This removes the split-authority problem where Mullvad app owned
          connection state but the repo owned a separate firewall story.
        '';
        privateKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Path to WireGuard private key file (your key).
            Use agenix or sops to provide this securely.
          '';
        };
        presharedKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Optional WireGuard preshared key path.
          '';
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "10.64.123.45/32";
          description = "WireGuard tunnel IP address assigned by Mullvad.";
        };
        dns = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "10.64.0.1";
          description = "DNS server to use through the tunnel (Mullvad DNS).";
        };
        endpoint = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "146.70.34.211:51820";
          description = ''
            Mullvad server endpoint. Paranoid policy requires a literal pinned IP:port.
          '';
        };
        serverPublicKey = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Mullvad server public key.";
        };
        allowedIPs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "0.0.0.0/0" "::/0" ];
          description = "IPs to route through the tunnel (default: full tunnel).";
        };
        persistentKeepalive = lib.mkOption {
          type = lib.types.int;
          default = 25;
          description = "WireGuard persistent keepalive interval in seconds.";
        };
      };

      sandbox = {
        browsers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Use sandboxed browser wrappers instead of base Firefox.
            Hardened baseline defaults to wrapped browsers.
          '';
        };
        apps = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable tightened bubblewrap wrappers for non-Flatpak desktop apps.
          '';
        };
        vms = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable KVM/QEMU VM tooling layer for high-risk workloads.
          '';
        };
        dbusFilter = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable filtered D-Bus access via xdg-dbus-proxy for bubblewrap sandboxes.
          '';
        };
        x11 = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Allow X11 socket passthrough into bubblewrap sandboxes.
            Hardened baseline keeps this off because X11 is a large shared-desktop attack surface.
          '';
        };
        wayland = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow Wayland socket passthrough into bubblewrap sandboxes.";
        };
        pipewire = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow PipeWire/Pulse sockets inside bubblewrap sandboxes.";
        };
        gpu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow GPU device passthrough into bubblewrap sandboxes.";
        };
        portals = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow xdg-desktop-portal access from bubblewrap sandboxes.";
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
        default = 2;
        description = "kernel.yama.ptrace_scope (0=classic, 1=restricted, 2=attached-only, 3=no-attach).";
      };
      swappiness = lib.mkOption {
        type = lib.types.int;
        default = 180;
        description = ''
          vm.swappiness (0-200, default 180 for zram-backed hardened workstation baseline).
        '';
      };

      kernelHardening = {
        initOnAlloc = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Zero pages on allocation (init_on_alloc=1).";
        };
        initOnFree = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Zero pages on free (init_on_free=1).";
        };
        slabNomerge = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Prevent slab cache merging (slab_nomerge).";
        };
        pageAllocShuffle = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Randomize free page list (page_alloc.shuffle=1).";
        };
        moduleBlacklist = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Blacklist dangerous kernel modules (dccp, sctp, rds, tipc, firewire).";
        };
        pti = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Kernel Page Table Isolation (pti=on).";
        };
        vsyscallNone = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Disable vsyscalls (vsyscall=none).";
        };
        oopsPanic = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Panic on kernel oops (kept false for workstation stability until validated on target hardware).";
        };
        moduleSigEnforce = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Only load signed kernel modules (staged off until validated on target hardware).";
        };
        disableIcmpEcho = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Ignore ICMP echo requests (ping).";
        };
        kexecLoadDisabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Disable kexec (kernel.kexec_load_disabled=1).";
        };
        sysrqRestrict = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Restrict SysRq key to keyboard-control functions only (kernel.sysrq=4).";
        };
        modulesDisabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Disable module loading after boot. Staged off until all required modules are proven loaded at boot.";
        };
        ioUring = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Define io_uring system-wide.";
        };
      };

      apparmor = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "AppArmor MAC framework.";
      };
      auditd = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Audit daemon enabled by default on the hardened baseline.";
      };
      auditRules = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load custom NixOS audit rules (separate from running auditd). Currently defaulted off due to AppArmor + audit-rules incompatibility on affected nixpkgs revisions (see docs/POST-STABILITY.md). Re-enable only after validating on your target nixpkgs revision.";
        };
      };
      lockRoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Lock root account and restrict su to wheel group.";
      };
      usbRestrict = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "USB authorized_default=2 (may block external hubs until explicitly overridden).";
      };
      hardenedMemory.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Graphene hardened allocator (staged off until validated).";
      };

      aide.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          AIDE integrity monitoring.
        '';
      };

      pamProfileBinding.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          EXPERIMENTAL: Enforce user/profile binding via PAM (daily=player, paranoid=ghost).
        '';
      };

      persistMachineId = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Persist /etc/machine-id across reboots via impermanence.
        '';
      };
      machineIdValue = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Explicit machine-id value to set. When null, systemd generates the ID.
        '';
      };

      allowSleep = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow system sleep states: suspend, hibernate, hybrid-sleep.
        '';
      };
    };
  };
}
