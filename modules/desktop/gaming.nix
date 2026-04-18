{ config, lib, pkgs, ... }: {
  # vr.nix and controllers.nix are imported unconditionally via
  # modules/desktop/base.nix so their options are visible on every
  # profile. They self-gate their own configs.
  config = {
    # Kernel module for NT sync (Wine gaming)
    boot.kernelModules = [ "ntsync" ];

    boot.kernel.sysctl = {
      # Fix Ubisoft Connect and similar services
      "net.ipv4.tcp_mtu_probing" = 1;
      # Gaming scheduler tuning (from steamos-customizations-jupiter)
      # Note: The following CFS scheduler tunables were removed from sysctl in kernel 5.13+
      # and moved to debugfs (/sys/kernel/debug/sched/). They have no sysctl equivalents:
      # - sched_latency_ns, sched_min_granularity_ns, sched_wakeup_granularity_ns
      # - sched_migration_cost_ns, sched_nr_migrate, sched_tunable_scaling
      # The kernel now calculates these values automatically. The remaining tunables below
      # are still available via sysctl and are relevant for gaming performance.
      "kernel.sched_cfs_bandwidth_slice_us" = 3000;
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
      # Proton builds are managed via protonup-qt (see environment.systemPackages
      # below) rather than pinned in extraCompatPackages. This keeps the choice
      # of GE / Luxtorpeda / SteamTinkerLaunch / etc. a runtime decision owned
      # by the operator, not a rebuild.
      extraCompatPackages = [ ];
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
      protonup-qt  # GUI manager for custom Proton builds (GE, Luxtorpeda, …)
      # mangohud     # FPS/temps overlay. Deferred — enable when actually needed.
      # protontricks # Wine-tricks wrapper for Proton prefixes. Deferred.
    ];
    environment.sessionVariables = {
      PROTON_USE_NTSYNC = "1";
      ENABLE_GAMESCOPE_WSI = "1";
    };
  };
}
