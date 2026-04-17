{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.desktopEnvironment;
in {
  config = lib.mkIf (cfg == "plasma") {
    # ── KDE Plasma 6 (Wayland-native) ────────────────────────────────
    services.desktopManager.plasma6.enable = true;

    # Plasma 6 (and xdg.portal's location backend) auto-enables geoclue2 via
    # mkDefault. geoclue queries Wi-Fi BSSIDs against the Mozilla Location
    # Service — an identity beacon that none of our declared features use.
    # Disable explicitly (mkForce) and document: re-enable via lib.mkOverride
    # 40 or a dedicated myOS.desktop.geolocation knob if redshift/gammastep
    # with automatic location ever becomes a requirement.
    services.geoclue2.enable = lib.mkForce false;

    # Disable drkonqi coredump processor - coredumps are already disabled via systemd.coredump.extraConfig
    # in modules/security/base.nix (Storage=none, ProcessSizeMax=0). The drkonqi service
    # tries to process stale journal entries from before that config was applied and times out.
    systemd.user.services.drkonqi-coredump-pickup.enable = false;
    systemd.user.services.drkonqi-coredump-launcher.enable = false;


    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
      ];
    };
  };
}
