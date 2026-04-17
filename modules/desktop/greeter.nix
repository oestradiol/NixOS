# Wayland-native greeter (greetd + regreet)
# Works with both Plasma and Hyprland
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.desktopEnvironment;
in {
  config = lib.mkIf (cfg != "none") {
    # ── greetd + regreet (Wayland-native greeter) ────────────────────
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.regreet}/bin/regreet";
          user = "greeter";
        };
      };
    };

    programs.regreet.enable = true;
  };
}
