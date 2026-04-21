# Wayland-native greeter (greetd + regreet)
# Works with both Plasma and Hyprland
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.desktopEnvironment;
in {
  config = lib.mkIf (cfg != "none") {
    # ── greetd + regreet (Wayland-native greeter) ────────────────────
    # Stylix automatically configures greetd with regreet when
    # programs.regreet.enable = true, so we don't set a custom command.
    services.greetd.enable = true;
    programs.regreet.enable = true;
  };
}
