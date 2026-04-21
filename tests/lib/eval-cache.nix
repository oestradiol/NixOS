# Single-call batch evaluator. Evaluates every attribute the static test
# suite wants from one configuration (paranoid OR daily) and returns them
# as a single JSON-serializable attrset.
#
# Each value is wrapped in `tryEval` so a missing option becomes `{ ok =
# false; }` instead of aborting the whole eval. Tests that care about
# "absent" vs "false" can distinguish by looking at `ok`.
#
# NOTE: Uses root flake with inline test fixture. The root flake is pure
# framework (library only) so we construct a minimal host config here.
{ flakePath ? toString ./../..
, profile ? "paranoid"   # "paranoid" or "daily"
}:
let
  flake = builtins.getFlake flakePath;
  nixpkgs = flake.inputs.nixpkgs;
  lib = nixpkgs.lib;
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  
  # Import framework modules from the root flake outputs
  hardening = flake.outputs.nixosModules;
  agenix = flake.inputs.agenix;
  impermanence = flake.inputs.impermanence;
  lanzaboote = flake.inputs.lanzaboote;
  home-manager = flake.inputs.home-manager;
  stylix = flake.inputs.stylix;
    # Build a test configuration using the framework modules
  testConfig = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      # Minimal mock config for testing (no disk dependencies)
      {
        nixpkgs.config.allowUnfree = true;
        boot.loader.grub.enable = false;
        boot.loader.systemd-boot.enable = nixpkgs.lib.mkForce false;
        boot.kernelModules = [ "kvm-amd" ];
        system.stateVersion = "26.05";

        # Test users matching the old ghost/player structure
        myOS.users.player = {
          activeOnProfiles = [ "daily" ];
          description = "Daily desktop";
          shell = pkgs.zsh;
          extraGroups = [ "networkmanager" "video" "audio" "input" "render" ];
          allowWheel = true;
          home.persistent = true;
        };

        myOS.users.ghost = {
          activeOnProfiles = [ "paranoid" ];
          description = "Hardened workspace";
          uid = 1001;
          shell = pkgs.zsh;
          extraGroups = [ "networkmanager" "video" "audio" "input" "render" ];
          allowWheel = false;
          home.persistent = false;
        };
      }
      # Required flake input modules
      agenix.nixosModules.default
      impermanence.nixosModules.impermanence
      lanzaboote.nixosModules.lanzaboote
      home-manager.nixosModules.home-manager
      stylix.nixosModules.stylix
      # Use default module (includes core + all feature modules)
      hardening.default
      hardening.profile-paranoid
    ] ++ nixpkgs.lib.optionals (profile == "daily") [ hardening.profile-daily ];
  };
  
  cfg = testConfig.config;

  # Safe lookup: evaluate an expression; on error, return { ok = false; }.
  try = expr:
    let r = builtins.tryEval expr; in
    if r.success then { ok = true; value = r.value; }
    else { ok = false; };

  # For options like `age.secrets` where the attrset may be empty, also
  # collect the key count separately so tests don't need to parse nested
  # attrsets.
  attrKeys = a: try (builtins.attrNames a);

  # Bare attr access helpers.
  inherit (builtins) hasAttr;

  # Stage 4c: per-user attributes are generated dynamically from
  # `cfg.myOS.users`, so tests and helpers never need to hardcode names.
  # Any `myOS.users.<name>` declared by the accounts/*.nix files (or by an
  # integrator flake) will automatically appear in the cache under
  # `users.users.<name>.*` entries.
  enabledUserNames =
    let r = builtins.tryEval (builtins.attrNames cfg.myOS.users);
    in if r.success then r.value else [];
  activeUserNames =
    let r = builtins.tryEval (builtins.filter
      (n: cfg.myOS.users.${n}._activeOn or false)
      enabledUserNames);
    in if r.success then r.value else [];

  # Per-user entries generated for every declared account, whether active
  # or inactive on the current profile.
  perUserEntries = builtins.listToAttrs (builtins.concatMap (n: [
    { name = "users.users.${n}.description";
      value = try cfg.users.users.${n}.description; }
    { name = "users.users.${n}.shell";
      value = try (cfg.users.users.${n}.shell.pname
                    or cfg.users.users.${n}.shell.name
                    or ""); }
    { name = "users.users.${n}.hashedPasswordFile";
      value = try cfg.users.users.${n}.hashedPasswordFile; }
    { name = "users.users.${n}.hashedPassword";
      value = try cfg.users.users.${n}.hashedPassword; }
    { name = "users.users.${n}.extraGroups";
      value = try cfg.users.users.${n}.extraGroups; }
    { name = "fileSystems./home/${n}.fsType";
      value = try (lib.attrByPath [ "/home/${n}" "fsType" ] null cfg.fileSystems); }
    { name = "fileSystems./home/${n}.options";
      value = try (lib.attrByPath [ "/home/${n}" "options" ] null cfg.fileSystems); }
    { name = "fileSystems.${cfg.myOS.persistence.root}/home/${n}.fsType";
      value = try (lib.attrByPath [ "${cfg.myOS.persistence.root}/home/${n}" "fsType" ] null cfg.fileSystems); }
    { name = "fileSystems.${cfg.myOS.persistence.root}/home/${n}.options";
      value = try (lib.attrByPath [ "${cfg.myOS.persistence.root}/home/${n}" "options" ] null cfg.fileSystems); }
    { name = "myOS.users.${n}._activeOn";
      value = try cfg.myOS.users.${n}._activeOn; }
    { name = "myOS.users.${n}.allowWheel";
      value = try cfg.myOS.users.${n}.allowWheel; }
    { name = "myOS.users.${n}.home.persistent";
      value = try cfg.myOS.users.${n}.home.persistent; }
  ]) enabledUserNames);
in
perUserEntries //
{
  # Framework-level indexes: every declared user, and the subset active
  # on the currently-evaluated profile. Tests iterate these instead of
  # hardcoding `player` / `ghost`.
  "myOS.users.__names"       = try enabledUserNames;
  "myOS.users.__activeNames" = try activeUserNames;
  # ── myOS options ────────────────────────────────────────────────────
  "myOS.profile"                                       = try cfg.myOS.profile;
  "myOS.gpu"                                           = try cfg.myOS.gpu;
  "myOS.debug.enable"                                  = try cfg.myOS.debug.enable;
  "myOS.debug.crossProfileLogin.enable"                = try cfg.myOS.debug.crossProfileLogin.enable;
  "myOS.debug.paranoidWheel.enable"                    = try cfg.myOS.debug.paranoidWheel.enable;
  "myOS.debug.warnings.enable"                         = try cfg.myOS.debug.warnings.enable;
  "myOS.storage.enable"                                = try cfg.myOS.storage.enable;
  "myOS.storage.rootTmpfs.size"                        = try cfg.myOS.storage.rootTmpfs.size;
  "myOS.storage.swap.enable"                           = try cfg.myOS.storage.swap.enable;
  "myOS.storage.swap.sizeMiB"                          = try cfg.myOS.storage.swap.sizeMiB;
  "myOS.storage.tmpTmpfs.options"                      = try cfg.myOS.storage.tmpTmpfs.options;
  "myOS.security.secureBoot.enable"                    = try cfg.myOS.security.secureBoot.enable;
  "myOS.security.tpm.enable"                           = try cfg.myOS.security.tpm.enable;
  "myOS.security.impermanence.enable"                  = try cfg.myOS.security.impermanence.enable;
  "myOS.security.agenix.enable"                        = try cfg.myOS.security.agenix.enable;
  "myOS.security.persistMachineId"                     = try cfg.myOS.security.persistMachineId;
  "myOS.security.machineIdValue"                       = try cfg.myOS.security.machineIdValue;
  "myOS.security.allowSleep"                           = try cfg.myOS.security.allowSleep;
  "myOS.security.wireguardMullvad.enable"              = try cfg.myOS.security.wireguardMullvad.enable;
  "myOS.security.sandbox.browsers"                     = try cfg.myOS.security.sandbox.browsers;
  "myOS.security.sandbox.apps"                         = try cfg.myOS.security.sandbox.apps;
  "myOS.security.sandbox.vms"                          = try cfg.myOS.security.sandbox.vms;
  "myOS.security.sandbox.dbusFilter"                   = try cfg.myOS.security.sandbox.dbusFilter;
  "myOS.security.sandbox.x11"                          = try cfg.myOS.security.sandbox.x11;
  "myOS.security.sandbox.wayland"                      = try cfg.myOS.security.sandbox.wayland;
  "myOS.security.sandbox.pipewire"                     = try cfg.myOS.security.sandbox.pipewire;
  "myOS.security.sandbox.gpu"                          = try cfg.myOS.security.sandbox.gpu;
  "myOS.security.sandbox.portals"                      = try cfg.myOS.security.sandbox.portals;
  "myOS.security.disableSMT"                           = try cfg.myOS.security.disableSMT;
  "myOS.security.ptraceScope"                          = try cfg.myOS.security.ptraceScope;
  "myOS.security.swappiness"                           = try cfg.myOS.security.swappiness;
  "myOS.security.apparmor"                             = try cfg.myOS.security.apparmor;
  "myOS.security.auditd"                               = try cfg.myOS.security.auditd;
  "myOS.security.auditRules.enable"                    = try cfg.myOS.security.auditRules.enable;
  "myOS.security.lockRoot"                             = try cfg.myOS.security.lockRoot;
  "myOS.security.usbRestrict"                          = try cfg.myOS.security.usbRestrict;
  "myOS.security.hardenedMemory.enable"                = try cfg.myOS.security.hardenedMemory.enable;
  "myOS.security.scanners.aide.enable"                 = try cfg.myOS.security.scanners.aide.enable;
  "myOS.security.scanners.clamav.enable"               = try cfg.myOS.security.scanners.clamav.enable;
  "myOS.security.pamProfileBinding.enable"             = try cfg.myOS.security.pamProfileBinding.enable;
  "myOS.security.kernelHardening.initOnAlloc"          = try cfg.myOS.security.kernelHardening.initOnAlloc;
  "myOS.security.kernelHardening.initOnFree"           = try cfg.myOS.security.kernelHardening.initOnFree;
  "myOS.security.kernelHardening.slabNomerge"          = try cfg.myOS.security.kernelHardening.slabNomerge;
  "myOS.security.kernelHardening.pageAllocShuffle"     = try cfg.myOS.security.kernelHardening.pageAllocShuffle;
  "myOS.security.kernelHardening.moduleBlacklist"      = try cfg.myOS.security.kernelHardening.moduleBlacklist;
  "myOS.security.kernelHardening.pti"                  = try cfg.myOS.security.kernelHardening.pti;
  "myOS.security.kernelHardening.vsyscallNone"         = try cfg.myOS.security.kernelHardening.vsyscallNone;
  "myOS.security.kernelHardening.oopsPanic"            = try cfg.myOS.security.kernelHardening.oopsPanic;
  "myOS.security.kernelHardening.moduleSigEnforce"     = try cfg.myOS.security.kernelHardening.moduleSigEnforce;
  "myOS.security.kernelHardening.disableIcmpEcho"      = try cfg.myOS.security.kernelHardening.disableIcmpEcho;
  "myOS.security.kernelHardening.kexecLoadDisabled"    = try cfg.myOS.security.kernelHardening.kexecLoadDisabled;
  "myOS.security.kernelHardening.sysrqRestrict"        = try cfg.myOS.security.kernelHardening.sysrqRestrict;
  "myOS.security.kernelHardening.modulesDisabled"      = try cfg.myOS.security.kernelHardening.modulesDisabled;
  "myOS.security.kernelHardening.ioUring"              = try cfg.myOS.security.kernelHardening.ioUring;
  "myOS.gaming.enable"                                 = try cfg.myOS.gaming.enable;
  "myOS.gaming.steam.enable"                           = try cfg.myOS.gaming.steam.enable;
  "myOS.gaming.gamescope.enable"                       = try cfg.myOS.gaming.gamescope.enable;
  "myOS.gaming.gamemode.enable"                        = try cfg.myOS.gaming.gamemode.enable;
  "myOS.gaming.vr.enable"                              = try cfg.myOS.gaming.vr.enable;
  "myOS.gaming.controllers.enable"                     = try cfg.myOS.gaming.controllers.enable;
  "myOS.vr.lanDiscovery.enable"                        = try cfg.myOS.vr.lanDiscovery.enable;
  "myOS.vr.lanInterfaces"                              = try cfg.myOS.vr.lanInterfaces;
  "myOS.desktop.flatpak.enable"                        = try cfg.myOS.desktop.flatpak.enable;
  "myOS.i18n.japanese.enable"                          = try cfg.myOS.i18n.japanese.enable;
  "myOS.i18n.japanese.inputMethod.enable"              = try cfg.myOS.i18n.japanese.inputMethod.enable;
  "myOS.i18n.japanese.fonts.enable"                    = try cfg.myOS.i18n.japanese.fonts.enable;
  "myOS.i18n.brazilian.enable"                         = try cfg.myOS.i18n.brazilian.enable;
  "myOS.i18n.brazilian.locale.enable"                  = try cfg.myOS.i18n.brazilian.locale.enable;
  "myOS.i18n.brazilian.keyboard.enable"                = try cfg.myOS.i18n.brazilian.keyboard.enable;
  "myOS.host.hostName"                                 = try cfg.myOS.host.hostName;
  "myOS.host.timeZone"                                 = try cfg.myOS.host.timeZone;
  "myOS.host.defaultLocale"                            = try cfg.myOS.host.defaultLocale;
  "myOS.networking.primaryInterface"                   = try cfg.myOS.networking.primaryInterface;
  "myOS.autoUpdate.enable"                             = try cfg.myOS.autoUpdate.enable;
  "myOS.autoUpdate.repoPath"                           = try cfg.myOS.autoUpdate.repoPath;

  # ── boot ─────────────────────────────────────────────────────────────
  "boot.kernelParams"                                  = try cfg.boot.kernelParams;
  "boot.kernelModules"                                 = try cfg.boot.kernelModules;
  "boot.blacklistedKernelModules"                      = try cfg.boot.blacklistedKernelModules;
  "boot.extraModprobeConfig"                           = try cfg.boot.extraModprobeConfig;
  "boot.kernel.sysctl"                                 = try cfg.boot.kernel.sysctl;
  "boot.loader.systemd-boot.enable"                    = try cfg.boot.loader.systemd-boot.enable;
  "boot.loader.grub.enable"                            = try cfg.boot.loader.grub.enable;
  "boot.lanzaboote.enable"                             = try cfg.boot.lanzaboote.enable;
  "fileSystems./.fsType"                               = try (lib.attrByPath [ "/" "fsType" ] null cfg.fileSystems);
  "fileSystems./.options"                              = try (lib.attrByPath [ "/" "options" ] null cfg.fileSystems);
  "fileSystems./boot.device"                           = try (lib.attrByPath [ "/boot" "device" ] null cfg.fileSystems);
  "fileSystems./nix.fsType"                            = try (lib.attrByPath [ "/nix" "fsType" ] null cfg.fileSystems);
  "fileSystems./nix.options"                           = try (lib.attrByPath [ "/nix" "options" ] null cfg.fileSystems);
  "fileSystems./persist.fsType"                        = try (lib.attrByPath [ "/persist" "fsType" ] null cfg.fileSystems);
  "fileSystems./persist.options"                       = try (lib.attrByPath [ "/persist" "options" ] null cfg.fileSystems);
  "fileSystems./tmp.fsType"                            = try (lib.attrByPath [ "/tmp" "fsType" ] null cfg.fileSystems);
  "fileSystems./tmp.options"                           = try (lib.attrByPath [ "/tmp" "options" ] null cfg.fileSystems);
  "fileSystems./swap.fsType"                           = try (lib.attrByPath [ "/swap" "fsType" ] null cfg.fileSystems);
  "systemd.services.profile-mount-invariants.script"   = try cfg.systemd.services.profile-mount-invariants.script;

  # ── security + services ──────────────────────────────────────────────
  "security.apparmor.enable"                           = try cfg.security.apparmor.enable;
  "services.xserver.enable"                            = try cfg.services.xserver.enable;
  "myOS.desktopEnvironment"                            = try cfg.myOS.desktopEnvironment;
  "services.desktopManager.plasma6.enable"             = try cfg.services.desktopManager.plasma6.enable;
  "services.greetd.enable"                             = try cfg.services.greetd.enable;
  "services.pipewire.enable"                           = try cfg.services.pipewire.enable;
  "services.pulseaudio.enable"                         = try cfg.services.pulseaudio.enable;
  "services.resolved.enable"                           = try cfg.services.resolved.enable;
  "services.flatpak.enable"                            = try cfg.services.flatpak.enable;
  "services.clamav.updater.enable"                     = try cfg.services.clamav.updater.enable;
  "services.mullvad-vpn.enable"                        = try cfg.services.mullvad-vpn.enable;
  "services.wivrn.enable"                              = try cfg.services.wivrn.enable;
  "services.wivrn.openFirewall"                        = try cfg.services.wivrn.openFirewall;
  "services.avahi.enable"                              = try cfg.services.avahi.enable;
  "services.avahi.publish.enable"                      = try cfg.services.avahi.publish.enable;
  "services.avahi.publish.userServices"                = try cfg.services.avahi.publish.userServices;
  "services.avahi.allowInterfaces"                     = try cfg.services.avahi.allowInterfaces;
  "services.geoclue2.enable"                           = try cfg.services.geoclue2.enable;
  "virtualisation.libvirtd.enable"                     = try cfg.virtualisation.libvirtd.enable;
  "networking.networkmanager.enable"                   = try cfg.networking.networkmanager.enable;
  "networking.firewall.enable"                         = try cfg.networking.firewall.enable;
  "networking.firewall.allowedTCPPorts"                = try cfg.networking.firewall.allowedTCPPorts;
  "networking.firewall.allowedUDPPorts"                = try cfg.networking.firewall.allowedUDPPorts;
  "networking.firewall.interfaces.__keys"              = attrKeys (cfg.networking.firewall.interfaces or {});
  "networking.firewall.interfaces.enp5s0.allowedTCPPorts" = try (cfg.networking.firewall.interfaces.enp5s0.allowedTCPPorts or []);
  "networking.firewall.interfaces.enp5s0.allowedUDPPorts" = try (cfg.networking.firewall.interfaces.enp5s0.allowedUDPPorts or []);
  "networking.nftables.enable"                         = try cfg.networking.nftables.enable;
  "networking.wireguard.interfaces.__keys"             = attrKeys (cfg.networking.wireguard.interfaces or {});
  "xdg.portal.enable"                                  = try cfg.xdg.portal.enable;
  "i18n.inputMethod.enable"                            = try cfg.i18n.inputMethod.enable;
  "programs.firefox.enable"                            = try cfg.programs.firefox.enable;
  "programs.steam.enable"                              = try cfg.programs.steam.enable;
  "programs.gamescope.enable"                          = try cfg.programs.gamescope.enable;
  "programs.gamemode.enable"                           = try cfg.programs.gamemode.enable;
  "programs.regreet.enable"                            = try cfg.programs.regreet.enable;

  # ── users ────────────────────────────────────────────────────────────
  # Per-user entries (users.users.<name>.{description,shell,
  # hashedPasswordFile,hashedPassword,extraGroups} and
  # myOS.users.<name>.{_activeOn,allowWheel,home.persistent}) are
  # generated dynamically from `myOS.users.__names` above via
  # `perUserEntries`. See the `let` binding at the top of this file.

  # ── misc ─────────────────────────────────────────────────────────────
  "age.secrets.__keys"                                 = attrKeys (cfg.age.secrets or {});

  # Also include the toplevel drv path for sanity.
  "system.build.toplevel.drvPath"                      = try cfg.system.build.toplevel.drvPath;
}
