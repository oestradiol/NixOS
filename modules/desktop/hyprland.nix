{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.desktopEnvironment;
in {
  config = lib.mkIf (cfg == "hyprland") {
    # ── Hyprland (Wayland compositor) ─────────────────────────────────
    programs.hyprland = {
      enable = true;
      xwayland.enable = false;  # Wayland-only, no X11 support
    };

    # Required for Hyprland to work properly
    hardware.graphics.enable = true;

    # Enable xdg-desktop-portal for Hyprland
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ];
    };
  };
}
