{ config, lib, pkgs, ... }: {
  imports = [ ./vr.nix ];

  config = {
    # Controller support (Bluetooth/Xbox) - disabled by default, enable with myOS.controllers.enable
    hardware.xpadneo.enable = lib.mkIf config.myOS.gaming.controllers.enable true;
    
    hardware.bluetooth = lib.mkIf config.myOS.gaming.controllers.enable {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          MultiProfile = "multiple";
          FastConnectable = true;
          KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e,330859bc-7506-492d-9370-9a6f0614037f";
        };
      };
    };

    boot.extraModprobeConfig = lib.mkIf config.myOS.gaming.controllers.enable ''
      options bluetooth disable_ertm=1
    '';

    services.udev.packages = lib.mkIf config.myOS.gaming.controllers.enable [ pkgs.game-devices-udev-rules ];
    
    services.udev.extraRules = lib.mkIf config.myOS.gaming.controllers.enable ''
      SUBSYSTEMS=="usb", TAG+="uaccess"
      KERNEL=="hidraw*", TAG+="uaccess"
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="028e", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0719", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02ea", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b12", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="310b", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="6012", TAG+="uaccess"
    '';

    services.blueman.enable = lib.mkIf config.myOS.gaming.controllers.enable true;

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
