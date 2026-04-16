# Hardened daily containment for non-Flatpak desktop apps.
# Scope: VRCX and Windsurf on the daily profile.
# Reality check: local bubblewrap wrappers reduce damage and narrow host access,
# but they are not VM-equivalent isolation.
{ config, lib, pkgs, ... }:
let
  sandbox = config.myOS.security.sandbox;
  inherit (config.myOS) profile;
  core = import ./sandbox-core.nix { inherit lib pkgs; };

  mkDailyApp = {
    name,
    package,
    binaryName ? name,
    persist,
    network ? true,
    gpu ? true,
    sessionBusTalk ? [ ],
  }:
    core.mkSandboxWrapper {
      inherit name package binaryName persist network;
      gpu = if sandbox.gpu then gpu else false;
      enableDbusProxy = sandbox.dbusFilter;
      wayland = sandbox.wayland;
      x11 = sandbox.x11;
      pipewire = sandbox.pipewire;
      sessionBusTalk = sessionBusTalk ++ lib.optionals (sandbox.dbusFilter && sandbox.portals) [
        "org.freedesktop.portal.*"
      ];
      sessionBusBroadcast = lib.optionals (sandbox.dbusFilter && sandbox.portals) [
        "org.freedesktop.portal.*=@/org/freedesktop/portal/*"
      ];
    };

  safeVrcxDaily = mkDailyApp {
    name = "vrcx";
    package = pkgs.vrcx;
    binaryName = "VRCX";
    persist = [
      ".config/VRCX"
      ".local/share/VRCX"
      ".cache/VRCX"
    ];
    network = true;
    gpu = true;
    sessionBusTalk = [
      "org.freedesktop.portal.FileChooser"
      "org.freedesktop.portal.Settings"
    ];
  };

  safeWindsurfDaily = mkDailyApp {
    name = "windsurf";
    package = pkgs.windsurf;
    binaryName = "windsurf";
    persist = [
      ".config/Windsurf"
      ".local/share/Windsurf"
      ".cache/Windsurf"
    ];
    network = true;
    gpu = true;
    sessionBusTalk = [
      "org.freedesktop.portal.FileChooser"
      "org.freedesktop.portal.Settings"
    ];
  };

  mkSandboxedDesktop = { name, exec, icon, comment, genericName ? null }:
    pkgs.makeDesktopItem {
      name = "safe-${name}";
      exec = "${exec} %U";
      inherit icon comment genericName;
      desktopName = "${name} (Tightened Sandbox)";
      categories = [ "Network" "Application" ];
      terminal = false;
      type = "Application";
    };

  safeVrcxDesktop = mkSandboxedDesktop {
    name = "VRCX";
    exec = "safe-vrcx";
    icon = "vrcx";
    comment = "VRCX with tightened daily containment for a non-Flatpak app";
    genericName = "VRChat Utility";
  };

  safeWindsurfDesktop = mkSandboxedDesktop {
    name = "Windsurf";
    exec = "safe-windsurf";
    icon = "windsurf";
    comment = "Windsurf with tightened daily containment for a non-Flatpak app";
    genericName = "Code Editor";
  };
in {
  # NOTE (deferred): the bwrap-wrapped daily apps below are intentionally NOT
  # exported yet. VRCX and Windsurf currently ship as plain packages via
  # home-manager/player, which was the faster path while other bugs were
  # pressing. Swap the commented list for the live one once:
  #   1. the ProtonUp-Qt / Steam / gamescope chain is stable,
  #   2. the wrapper's portal/file-chooser passthrough has been validated
  #      against both apps end-to-end,
  #   3. the operator is ready to redirect their desktop shortcuts.
  # Keep the let-bindings above — they are the shipping implementation and
  # must not be deleted. See docs/maps/TECH-DEBT.md §1 A4.
  config = lib.mkIf (sandbox.apps && profile == "daily") {
    environment.systemPackages = [
     # safeVrcxDaily
     # safeWindsurfDaily
     # safeVrcxDesktop
     # safeWindsurfDesktop
    ];
  };
}
