{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.desktop.flatpak;
in {
  options.myOS.desktop.flatpak = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Flatpak containment layer for relatively trusted daily GUI apps.
        Higher-risk software should stay in bubblewrap wrappers or VMs.
      '';
    };
  };

  # Flatpak is the containment layer for relatively trusted daily GUI apps.
  # Higher-risk software should stay in bubblewrap wrappers or VMs instead.
  config = lib.mkIf cfg.enable {
  services.flatpak.enable = true;

  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "nss-lookup.target" ];
    wants = [ "network-online.target" "nss-lookup.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      # Flatpak packages must be installed manually after first boot:
      # flatpak install -y flathub org.signal.Signal
      # flatpak install -y flathub com.spotify.Client
      # flatpak install -y flathub com.bitwarden.desktop
      # flatpak install -y flathub dev.vencord.Vesktop
      # flatpak install -y flathub md.obsidian.Obsidian
    '';
    unitConfig = {
      StartLimitIntervalSec = "300s";
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/flatpak" ];
      ProtectKernelTunables = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      CapabilityBoundingSet = "";
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
  };
}
