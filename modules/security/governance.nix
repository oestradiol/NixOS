{ config, lib, ... }:
let
  persistRoot = config.myOS.persistence.root;
  sec = config.myOS.security;

  # Posture detection from configuration properties, not profile names.
  # Hardened posture = strict sandboxing + impermanence + disabled SMT etc.
  # Relaxed posture = compatible sandboxing + may allow X11 etc.
  isHardenedPosture = sec.sandbox.browsers && sec.impermanence.enable && sec.disableSMT;
  isRelaxedPosture = !isHardenedPosture;

  # Legacy aliases for backward compatibility (deprecated, will be removed)
  isDaily = isRelaxedPosture;
  isParanoid = isHardenedPosture;

  # Debug-mode relaxations (see modules/core/debug.nix). Each flag only
  # takes effect when myOS.debug.enable is also true.
  debug = config.myOS.debug;
  paranoidWheelRelaxed = debug.enable && debug.paranoidWheel.enable;

  # Framework-driven: users active on current profile
  enabledUsers = lib.filterAttrs (_: u: u.enable) config.myOS.users;
  activeUsers = lib.filterAttrs (_: u: u._activeOn) enabledUsers;
  activeUsersList = builtins.attrValues activeUsers;

  # Structural assertions: wheel-restricted users on hardened posture
  hardenedWheelViolations = lib.filterAttrs (n: u:
    u._activeOn && !u.allowWheel && builtins.elem "wheel" config.users.users.${n}.extraGroups
  ) (lib.filterAttrs (_: u: u.enable) config.myOS.users);

  # Structural posture invariants:
  #   - relaxed posture requires a permissive user (wheel + persistent home)
  #   - hardened posture requires a locked-down user (no wheel + tmpfs home)
  relaxedPostureUsers = lib.filterAttrs (_: u:
    u._activeOn && u.allowWheel && u.home.persistent
  ) activeUsers;
  hardenedPostureUsers = lib.filterAttrs (_: u:
    u._activeOn && !u.allowWheel && !u.home.persistent
  ) activeUsers;
in {
  assertions = [
    # Structural: at least one user must be active on the current profile
    {
      assertion = activeUsersList != [];
      message = "Governance invariant: at least one user must be active on profile '${config.myOS.profile}'.";
    }
    # Structural: relaxed posture requires a permissive persistent-home user
    {
      assertion = !isRelaxedPosture || relaxedPostureUsers != {};
      message = "Governance invariant: relaxed posture (sandbox.browsers=false or impermanence disabled) requires at least one active user with allowWheel=true and home.persistent=true.";
    }
    # Structural: hardened posture requires a locked-down tmpfs-home user
    {
      assertion = !isHardenedPosture || hardenedPostureUsers != {};
      message = "Governance invariant: hardened posture (sandbox.browsers=true + impermanence + disableSMT) requires at least one active user with allowWheel=false and home.persistent=false.";
    }
    {
      assertion = !config.services.xserver.enable;
      message = "X server must be disabled system-wide (Wayland-only stack).";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.sandbox.browsers;
      message = "Hardened posture must use sandboxed browsers exclusively (no base Firefox).";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.impermanence.enable;
      message = "Hardened posture must keep impermanence enabled.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.agenix.enable;
      message = "Hardened posture must keep secrets management enabled.";
    }
    {
      assertion = !isHardenedPosture || (!config.programs.steam.enable);
      message = "Hardened posture must not enable Steam.";
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
    # Structural wheel governance: on hardened posture, no active user with
    # allowWheel=false may be in the wheel group (unless debug override).
    {
      assertion = !isHardenedPosture || paranoidWheelRelaxed || (hardenedWheelViolations == {});
      message = "Hardened posture user must not be in the wheel group by default.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.disableSMT;
      message = "Hardened posture must enable disableSMT (nosmt=force).";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.usbRestrict;
      message = "Hardened posture must enable USB restriction (authorized_default=2).";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.auditd;
      message = "Hardened posture must enable audit daemon.";
    }
    {
      assertion = !isHardenedPosture || config.security.audit.enable != false;
      message = "Hardened posture must enable the Linux audit subsystem, not just auditd.";
    }
    {
      assertion = !isHardenedPosture || !config.myOS.security.auditRules.enable || config.security.audit.rules != [ ];
      message = "When hardened posture enables repo audit rules, the resulting audit rule set must be non-empty.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.sandbox.vms;
      message = "Hardened posture must enable VM tooling layer.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.kernelHardening.initOnFree;
      message = "Hardened posture must enable initOnFree kernel hardening.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.kernelHardening.pageAllocShuffle;
      message = "Hardened posture must enable pageAllocShuffle kernel hardening.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.kernelHardening.kexecLoadDisabled;
      message = "Hardened posture must disable kexec_load (kernel.kexec_load_disabled=1).";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.kernelHardening.sysrqRestrict;
      message = "Hardened posture must restrict SysRq key (kernel.sysrq).";
    }
    {
      assertion = !isHardenedPosture || (config.myOS.security.kernelHardening.ioUring == 2);
      message = "Hardened posture must disable io_uring (kernel.io_uring_disabled=2).";
    }
    {
      assertion = !isHardenedPosture || !config.programs.gamescope.enable;
      message = "Hardened posture must not enable gamescope.";
    }
    {
      assertion = !isHardenedPosture || !config.programs.gamemode.enable;
      message = "Hardened posture must not enable gamemode.";
    }
    {
      assertion = !isHardenedPosture || !config.services.wivrn.enable;
      message = "Hardened posture must not enable wivrn.";
    }
    {
      assertion = !isRelaxedPosture || !config.myOS.security.hardenedMemory.enable;
      message = "Relaxed posture must not enable hardened memory allocator.";
    }
    {
      assertion = builtins.elem config.myOS.gpu [ "nvidia" "amd" "none" ];
      message = "GPU option must be set to 'nvidia', 'amd', or 'none'.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.persistMachineId;
      message = "Hardened posture must persist machine-id.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.machineIdValue == null;
      message = "Hardened posture must keep a unique host machine-id.";
    }
    {
      assertion = !isHardenedPosture || !config.myOS.security.sandbox.x11;
      message = "Hardened posture must keep X11 disabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isHardenedPosture || config.myOS.security.sandbox.wayland;
      message = "Hardened posture must keep Wayland enabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isRelaxedPosture || config.myOS.security.sandbox.x11;
      message = "Relaxed posture must make the X11 compatibility relaxation explicit.";
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
      # WiVRn advertises via mDNS/avahi when enabled. Hardened posture does not
      # import desktop/vr.nix, but relaxed posture must never broadcast
      # unless the operator explicitly opted in.
      assertion = !isRelaxedPosture || config.myOS.vr.lanDiscovery.enable || !config.services.avahi.enable;
      message = ''
        Governance invariant: relaxed posture must not enable avahi unless
        myOS.vr.lanDiscovery.enable = true. Upstream nixpkgs wivrn.nix hard-sets
        services.avahi.enable; the override in modules/desktop/vr.nix depends on
        myOS.vr.lanDiscovery — if you ever see this message, a new module is
        forcing avahi on without going through the knob.
      '';
    }
    {
      # Hardened posture has no VR stack and therefore no reason to run avahi.
      assertion = !isHardenedPosture || !config.services.avahi.enable;
      message = "Hardened posture must not enable avahi (no VR/mDNS use case).";
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
