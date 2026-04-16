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
    extraBwrapArgs ? [ ],
    args ? [ ],
  }:
    core.mkSandboxWrapper {
      inherit name package binaryName persist network extraBwrapArgs args;
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
    binaryName = "vrcx";
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
    extraBwrapArgs = [
      "--bind" "/tmp" "/tmp"
      "--bind" "/dev/shm" "/dev/shm"
    ];
    args = [ "--no-sandbox" ];
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
  config = lib.mkIf (sandbox.apps && profile == "daily") {
    environment.systemPackages = [
      # safeVrcxDaily  # Deferred: Electron app crashes in bubblewrap despite --no-sandbox, /dev/shm, /tmp access
      # safeWindsurfDaily  # Deferred: Electron app fails to launch GUI in bubblewrap despite --no-sandbox, /dev/shm, /tmp access
      # safeVrcxDesktop
      # safeWindsurfDesktop
    ];
  };
}
