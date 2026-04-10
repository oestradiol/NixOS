{ config, lib, pkgs, ... }: {
  imports = [ ./vr.nix ./controllers.nix ];

  config = {
    # Steam
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = false;
      package = pkgs.steam.override {
        extraProfile = ''
          unset TZ
          export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
        '';
        extraEnv = {
          PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
        };
      };
      extraCompatPackages = with pkgs; [
        #proton-ge-bin
      ];
    };

    # Graphics
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.steam-hardware.enable = true;

    # Gamescope
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
    programs.steam.gamescopeSession = {
      enable = true;
    };

    # Feral Gamemode
    programs.gamemode.enable = true;

    # Environment
    environment.systemPackages = with pkgs; [
      #mangohud
      #protonup-qt
      #protontricks
    ];
    environment.sessionVariables = {
      PROTON_USE_NTSYNC = "1";
      ENABLE_GAMESCOPE_WSI = "1";
    };

    # xdg portal
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
  };
}
