# Hardened containment for non-Flatpak desktop apps.
# Reality check: local bubblewrap wrappers reduce damage and narrow host access,
# but they are not VM-equivalent isolation.
{ config, lib, pkgs, ... }:
let
  sandbox = config.myOS.security.sandbox;
  core = import ./sandbox-core.nix { inherit lib pkgs; };

  mkSandboxedApp = {
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

  # Example usage in templates:
  #   safeMyApp = mkSandboxedApp {
  #     name = "myapp";
  #     package = pkgs.myapp;
  #     persist = [ ".config/myapp" ];
  #     network = true;
  #   };

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
  # Example usage in templates:
  #   safeMyAppDesktop = mkSandboxedDesktop {
  #     name = "MyApp";
  #     exec = "safe-myapp";
  #     icon = "myapp";
  #     comment = "MyApp with tightened containment";
  #   };
in {
  # Currently all sandboxed apps are deferred due to Electron crashes in bubblewrap.
  # The infrastructure remains for future use when bubblewrap compatibility improves.
  config = lib.mkIf sandbox.apps {
    # Apps would be added here when ready
    environment.systemPackages = [ ];
  };
}
