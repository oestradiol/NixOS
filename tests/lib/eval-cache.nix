# Single-call batch evaluator. Evaluates every attribute the static test
# suite wants from one configuration (paranoid OR daily) and returns them
# as a single JSON-serializable attrset.
#
# Each value is wrapped in `tryEval` so a missing option becomes `{ ok =
# false; }` instead of aborting the whole eval. Tests that care about
# "absent" vs "false" can distinguish by looking at `ok`.
{ flakePath ? toString ./../..
, profile ? "paranoid"   # "paranoid" or "daily"
}:
let
  flake = builtins.getFlake flakePath;
  topCfg = flake.outputs.nixosConfigurations.nixos.config;
  dailyCfg = topCfg.specialisation.daily.configuration;
  cfg = if profile == "daily" then dailyCfg else topCfg;

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
in
{
  # ── myOS options ────────────────────────────────────────────────────
  "myOS.profile"                                       = try cfg.myOS.profile;
  "myOS.gpu"                                           = try cfg.myOS.gpu;
  "myOS.debug.enable"                                  = try cfg.myOS.debug.enable;
  "myOS.debug.crossProfileLogin.enable"                = try cfg.myOS.debug.crossProfileLogin.enable;
  "myOS.debug.paranoidWheel.enable"                    = try cfg.myOS.debug.paranoidWheel.enable;
  "myOS.debug.warnings.enable"                         = try cfg.myOS.debug.warnings.enable;
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
  "users.users.player.description"                     = try cfg.users.users.player.description;
  "users.users.ghost.description"                      = try cfg.users.users.ghost.description;
  "users.users.player.shell"                           = try (cfg.users.users.player.shell.pname
                                                              or cfg.users.users.player.shell.name
                                                              or "");
  "users.users.ghost.shell"                            = try (cfg.users.users.ghost.shell.pname
                                                              or cfg.users.users.ghost.shell.name
                                                              or "");
  # Account locking surface. hashedPasswordFile is null when the mkIf
  # condition evaluated to false; hashedPassword is null when its mkIf
  # evaluated to false. Stage 1 uses these to assert the debug-off default.
  "users.users.player.hashedPasswordFile"              = try cfg.users.users.player.hashedPasswordFile;
  "users.users.player.hashedPassword"                  = try cfg.users.users.player.hashedPassword;
  "users.users.ghost.hashedPasswordFile"               = try cfg.users.users.ghost.hashedPasswordFile;
  "users.users.ghost.hashedPassword"                   = try cfg.users.users.ghost.hashedPassword;
  "users.users.player.extraGroups"                     = try cfg.users.users.player.extraGroups;
  "users.users.ghost.extraGroups"                      = try cfg.users.users.ghost.extraGroups;

  # ── misc ─────────────────────────────────────────────────────────────
  "age.secrets.__keys"                                 = attrKeys (cfg.age.secrets or {});

  # Also include the toplevel drv path for sanity.
  "system.build.toplevel.drvPath"                      = try cfg.system.build.toplevel.drvPath;
}
