# Gaming stack — Steam, gamescope, gamemode, NT sync, Proton plumbing.
#
# Stage 3 introduces knob-gated sub-features:
#   - myOS.gaming.enable       — master gate (default false; daily sets true)
#   - myOS.gaming.steam.enable       (default = gaming.enable)
#   - myOS.gaming.gamescope.enable   (default = gaming.enable)
#   - myOS.gaming.gamemode.enable    (default = gaming.enable)
#   - myOS.gaming.vr.enable          (default = gaming.enable, consumed by desktop/vr.nix)
#   - myOS.gaming.controllers.enable — declared in modules/desktop/controllers.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.gaming;
in {
  options.myOS.gaming = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Master gate for the gaming stack. Pulls in Steam + gamescope +
        gamemode + NT sync + Proton plumbing. Disabled by default so
        forkers and paranoid-profile users do not carry the gaming
        attack surface unless they opt in. The daily profile flips this
        on via lib.mkForce.
      '';
    };
    steam.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Enable Steam (programs.steam) when gaming.enable is true.";
    };
    gamescope.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Enable gamescope compositor with cap_sys_nice wrapper.";
    };
    gamemode.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Enable Feral Gamemode for per-process performance tuning.";
    };
    vr.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = ''
        Enable the VR stack (WiVRn + avahi policy) from modules/desktop/vr.nix.
        Consumed by vr.nix to gate its config block.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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

    # Steam (merged with gamescopeSession so Nix doesn't complain about
    # programs.steam being defined twice at the top level).
    programs.steam = lib.mkMerge [
      (lib.mkIf cfg.steam.enable {
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
      })
      (lib.mkIf (cfg.steam.enable && cfg.gamescope.enable) {
        gamescopeSession.enable = true;
      })
    ];

    # Graphics
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.steam-hardware.enable = lib.mkIf cfg.steam.enable true;

    # Gamescope
    programs.gamescope = lib.mkIf cfg.gamescope.enable {
      enable = true;
      capSysNice = true;
    };

    # Feral Gamemode
    programs.gamemode.enable = cfg.gamemode.enable;

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
