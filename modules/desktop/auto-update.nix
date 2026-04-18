# Automatic system-rebuild timer.
#
# Extracted from modules/desktop/base.nix in Stage 3. Runs `nix flake
# update` + `nixos-rebuild boot` daily so the next boot picks up fresh
# nixpkgs without operator action. Self-gated on `myOS.autoUpdate.enable`
# (default true; preserves pre-Stage-3 behaviour).
#
# `repoPath` is the directory the flake lives in. Default points at the
# operator's clone; integrators / forkers override it via
# hosts/<host>/local.nix or an integrator flake.
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.autoUpdate;
in {
  options.myOS.autoUpdate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the daily flake-update + rebuild-boot timer.
      '';
    };
    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/player/dotfiles";
      description = ''
        Filesystem path to the flake that should be updated and rebuilt.
        The update runs as `sudo -u <invokingUser>` via the systemd unit,
        so the path must be a clone owned by the invoking user.
      '';
    };
    invokingUser = lib.mkOption {
      type = lib.types.str;
      default = "player";
      description = ''
        Unix user whose identity is assumed for the `nix flake update`
        half of the rebuild (the rebuild-boot half runs as root). The
        user must own `repoPath`.
      '';
    };
    flakeAttr = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "nixosConfiguration attribute name passed to `nixos-rebuild boot --flake .#<flakeAttr>`.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nix-auto-update = {
      description = "Daily automatic Nix flake update and boot entry rebuild";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/sh -c 'cd ${cfg.repoPath} && sudo -u ${cfg.invokingUser} ${pkgs.nix}/bin/nix flake update --flake . && ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake .#${cfg.flakeAttr}'";
        WorkingDirectory = cfg.repoPath;
      };
    };

    systemd.timers.nix-auto-update = {
      description = "Run daily Nix flake update and boot rebuild";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
