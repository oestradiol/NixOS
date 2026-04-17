{ config, lib, ... }:
let
  persistRoot = config.myOS.persistence.root;
  isDaily = config.myOS.profile == "daily";
  isParanoid = config.myOS.profile == "paranoid";
  # Debug-mode relaxations (see modules/core/debug.nix). Each flag only
  # takes effect when myOS.debug.enable is also true.
  debug = config.myOS.debug;
  paranoidWheelRelaxed = debug.enable && debug.paranoidWheel.enable;
in {
  assertions = [
    {
      assertion = config.users.users ? "player";
      message = "Governance invariant: daily user 'player' must exist.";
    }
    {
      assertion = config.users.users ? "ghost";
      message = "Governance invariant: paranoid user 'ghost' must exist.";
    }
    {
      assertion = !config.services.xserver.enable;
      message = "X server must be disabled system-wide (Wayland-only stack).";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.browsers;
      message = "Paranoid profile must use sandboxed browsers exclusively (no base Firefox).";
    }
    {
      assertion = !isParanoid || config.myOS.security.impermanence.enable;
      message = "Paranoid profile must keep impermanence enabled.";
    }
    {
      assertion = !isParanoid || config.myOS.security.agenix.enable;
      message = "Paranoid profile must keep secrets management enabled.";
    }
    {
      assertion = !isParanoid || (!config.programs.steam.enable);
      message = "Paranoid profile must not enable Steam.";
    }
    {
      assertion = !(config.myOS.security.secureBoot.enable && config.boot.loader.grub.enable);
      message = "Secure Boot path must not coexist with GRUB.";
    }
    {
      assertion = !config.myOS.security.secureBoot.enable || config.boot.loader.efi.canTouchEfiVariables;
      message = "Secure Boot path requires EFI variable access.";
    }
    {
      assertion = !config.myOS.security.tpm.enable || config.boot.initrd.systemd.enable;
      message = "TPM-bound unlock requires systemd in the initrd.";
    }
    {
      assertion = config.services.greetd.enable;
      message = "This design assumes greetd is enabled as the Wayland-native display manager.";
    }
    {
      # Relaxed by myOS.debug.paranoidWheel.enable when the master debug
      # gate is also on. The relaxation is surfaced as an activation warning
      # by modules/core/debug.nix.
      assertion = !isParanoid || paranoidWheelRelaxed || !(builtins.elem "wheel" config.users.users."ghost".extraGroups);
      message = "Paranoid user must not be in the wheel group by default.";
    }
    {
      assertion = !isParanoid || config.myOS.security.disableSMT;
      message = "Paranoid profile must enable disableSMT (nosmt=force).";
    }
    {
      assertion = !isParanoid || config.myOS.security.usbRestrict;
      message = "Paranoid profile must enable USB restriction (authorized_default=2).";
    }
    {
      assertion = !isParanoid || config.myOS.security.auditd;
      message = "Paranoid profile must enable audit daemon.";
    }
    {
      assertion = !isParanoid || config.security.audit.enable != false;
      message = "Paranoid profile must enable the Linux audit subsystem, not just auditd.";
    }
    {
      assertion = !isParanoid || !config.myOS.security.auditRules.enable || config.security.audit.rules != [ ];
      message = "When paranoid profile enables repo audit rules, the resulting audit rule set must be non-empty.";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.vms;
      message = "Paranoid profile must enable VM tooling layer.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.initOnFree;
      message = "Paranoid profile must enable initOnFree kernel hardening.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.pageAllocShuffle;
      message = "Paranoid profile must enable pageAllocShuffle kernel hardening.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.kexecLoadDisabled;
      message = "Paranoid profile must disable kexec_load (kernel.kexec_load_disabled=1).";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.sysrqRestrict;
      message = "Paranoid profile must restrict SysRq key (kernel.sysrq).";
    }
    {
      assertion = !isParanoid || (config.myOS.security.kernelHardening.ioUring == 2);
      message = "Paranoid profile must disable io_uring (kernel.io_uring_disabled=2).";
    }
    {
      assertion = !isParanoid || !config.programs.gamescope.enable;
      message = "Paranoid profile must not enable gamescope.";
    }
    {
      assertion = !isParanoid || !config.programs.gamemode.enable;
      message = "Paranoid profile must not enable gamemode.";
    }
    {
      assertion = !isParanoid || !config.services.wivrn.enable;
      message = "Paranoid profile must not enable wivrn.";
    }
    {
      assertion = !isDaily || !config.myOS.security.hardenedMemory.enable;
      message = "Daily profile must not enable hardened memory allocator.";
    }
    {
      assertion = config.myOS.gpu == "nvidia" || config.myOS.gpu == "amd";
      message = "GPU option must be set to either 'nvidia' or 'amd'.";
    }
    {
      assertion = !isParanoid || config.myOS.security.persistMachineId;
      message = "Paranoid profile must persist machine-id.";
    }
    {
      assertion = !isParanoid || config.myOS.security.machineIdValue == null;
      message = "Paranoid profile must keep a unique host machine-id.";
    }
    {
      assertion = !isParanoid || !config.myOS.security.sandbox.x11;
      message = "Paranoid profile must keep X11 disabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.wayland;
      message = "Paranoid profile must keep Wayland enabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isDaily || config.myOS.security.sandbox.x11;
      message = "Daily profile must make the X11 compatibility relaxation explicit.";
    }
    # ── Network-surface invariants (pen-test pass 2026-04) ────────
    {
      # One of the two packet filters must be active at all times. wireguard.nix
      # hard-sets networking.firewall.enable = false when using the self-owned
      # tunnel and drives nftables instead; networking.nix enables the nixpkgs
      # firewall otherwise. This assertion catches any future edit that leaves
      # the box with BOTH off.
      assertion = config.networking.firewall.enable || config.networking.nftables.enable;
      message = ''
        Governance invariant: either networking.firewall.enable OR
        networking.nftables.enable must be true. Check the coupling between
        modules/security/networking.nix and modules/security/wireguard.nix.
      '';
    }
    {
      # WiVRn advertises via mDNS/avahi when enabled. Paranoid profile does not
      # import desktop/vr.nix, but the daily profile must never broadcast
      # unless the operator explicitly opted in.
      assertion = !isDaily || config.myOS.vr.lanDiscovery.enable || !config.services.avahi.enable;
      message = ''
        Governance invariant: daily profile must not enable avahi unless
        myOS.vr.lanDiscovery.enable = true. Upstream nixpkgs wivrn.nix hard-sets
        services.avahi.enable; the override in modules/desktop/vr.nix depends on
        myOS.vr.lanDiscovery — if you ever see this message, a new module is
        forcing avahi on without going through the knob.
      '';
    }
    {
      # Paranoid profile has no VR stack and therefore no reason to run avahi.
      assertion = !isParanoid || !config.services.avahi.enable;
      message = "Paranoid profile must not enable avahi (no VR/mDNS use case).";
    }
    {
      # Daily LAN discovery (if enabled) must be scoped to declared interfaces.
      # This prevents someone flipping lanDiscovery.enable without also declaring
      # lanInterfaces, which would let avahi pick an interface on its own.
      assertion = !config.myOS.vr.lanDiscovery.enable || (config.myOS.vr.lanInterfaces != [ ]);
      message = ''
        Governance invariant: myOS.vr.lanDiscovery.enable requires at least one
        interface in myOS.vr.lanInterfaces (avahi broadcast must be scoped).
      '';
    }
  ];
}
