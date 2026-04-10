{ config, lib, pkgs, ... }: {
  imports = [ ./vr.nix ]; #./controllers.nix

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false; # For Steam Link

    package = pkgs.steam.override {
      extraProfile = ''
        unset TZ
        export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
      '';

      # Expose WiVRn IPC socket to Steam's pressure-vessel sandbox.
      extraEnv = {
        PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
      };
    };

    # Proton-GE for better game compatibility + umu-launcher
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
    # Creates /run/wrappers/bin/gamescope with cap_sys_nice capability.
    # Required for Steam to function inside gamescope.
    # Also sets security.wrappers.bwrap with setuid.
    capSysNice = true;
  };
  programs.steam.gamescopeSession = {
    enable = true;
  };

  # Feral Gamemode
  programs.gamemode.enable = true;

  # Environment
  environment.systemPackages = with pkgs; [
    #mangohud     # Vulkan + OpenGL system monitoring overlay
    #protonup-qt   # GUI for managing Proton-GE and other custom Proton versions
    #protontricks  # Run winetricks commands inside Proton prefixes
  ];
  environment.sessionVariables = {
    PROTON_USE_NTSYNC = "1";
    ENABLE_GAMESCOPE_WSI = "1";
    #STEAM_MULTIPLE_XWAYLANDS = "1"; # Great but makes VRChat not open :(
  };

  # xdg portal for Flatpak and Wayland app integration
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
