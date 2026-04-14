{ config, lib, pkgs, ... }: {
  imports = [ ./vr.nix ./controllers.nix ];

  config = {
    # Kernel module for NT sync (Wine gaming)
    boot.kernelModules = [ "ntsync" ];

    boot.kernel.sysctl = {
      # Fix Ubisoft Connect and similar services
      "net.ipv4.tcp_mtu_probing" = 1;
      # Gaming scheduler tuning (from steamos-customizations-jupiter)
      "kernel.sched_cfs_bandwidth_slice_u" = 3000;
      "kernel.sched_latency_ns" = 3000000;
      "kernel.sched_min_granularity_ns" = 300000;
      "kernel.sched_wakeup_granularity_ns" = 500000;
      "kernel.sched_migration_cost_ns" = 50000;
      "kernel.sched_nr_migrate" = 128;
      "kernel.split_lock_mitigate" = 0;
      "kernel.sched_rt_runtime_us" = -1;
    };

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
