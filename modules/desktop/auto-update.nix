# Automatic system-rebuild timer.
#
# Extracted from modules/desktop/base.nix in Stage 3. Runs `nix flake
# update` + `nixos-rebuild boot` daily so the next boot picks up fresh
# nixpkgs without operator action. Self-gated on `myOS.autoUpdate.enable`
# (default true; preserves pre-Stage-3 behaviour).
#
# Stage 5: `repoPath` / `invokingUser` are derived from whichever active
# user declared `identity.workspace.autoUpdateRepoPath` in a gitignored
# accounts/<name>.local.nix. The tracked tree no longer names a user or
# path. Explicit overrides via `myOS.autoUpdate.repoPath` /
# `myOS.autoUpdate.invokingUser` still win.
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.autoUpdate;

  # Prefer the active profile's user, but fall back to any configured
  # account so a paranoid default profile can still inherit the daily
  # operator's flake path for unattended updates.
  configuredCandidates = lib.filterAttrs (_: u:
    u.enable
    && (u.identity.workspace.autoUpdateRepoPath or null) != null
  ) (config.myOS.users or { });
  activeCandidates = lib.filterAttrs (_: u: u._activeOn or false) configuredCandidates;
  candidates = if activeCandidates != { } then activeCandidates else configuredCandidates;
  candidateNames = lib.attrNames candidates;
  firstCandidate =
    if candidateNames == [ ] then null
    else builtins.head candidateNames;
  derivedRepoPath =
    if firstCandidate == null then null
    else candidates.${firstCandidate}.identity.workspace.autoUpdateRepoPath;

  repoPath     = if cfg.repoPath     != null then cfg.repoPath     else derivedRepoPath;
  invokingUser = if cfg.invokingUser != null then cfg.invokingUser else firstCandidate;

  # The feature is effectively enabled when the operator asks for it AND
  # we have a repoPath + invokingUser to work with. Without either we
  # skip silently and surface a warning, so a fresh fork with no local
  # identity does not trip systemd at build time.
  effective = cfg.enable && repoPath != null && invokingUser != null;
in {
  options.myOS.autoUpdate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the daily flake-update + rebuild-boot timer. The timer is
        only actually installed when a `repoPath` + `invokingUser` can
        be resolved (from `myOS.users.<name>.identity.workspace` on a
        configured user, preferring the active profile and otherwise
        falling back to another configured account, or from explicit
        overrides below); otherwise this is a no-op.
      '';
    };
    repoPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/dotfiles";
      description = ''
        Filesystem path to the flake that should be updated and rebuilt.
        When null (the tracked default), the path is derived from the
        first configured user with `identity.workspace.autoUpdateRepoPath`
        set, preferring the active profile when one exists. Set
        explicitly in `hosts/<host>/local.nix` to override.
      '';
    };
    invokingUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        Unix user whose identity is assumed for the `nix flake update`
        half of the rebuild (the rebuild-boot half runs as root). When
        null, uses the first configured user with
        `identity.workspace.autoUpdateRepoPath` set, preferring the
        active profile when one exists.
      '';
    };
    flakeAttr = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "nixosConfiguration attribute name passed to `nixos-rebuild boot --flake .#<flakeAttr>`.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && !effective) {
      warnings = [
        ("myOS.autoUpdate.enable is true but repoPath/invokingUser could not be resolved."
         + " Set myOS.users.<name>.identity.workspace.autoUpdateRepoPath in a"
         + " gitignored accounts/<name>.local.nix, or override"
         + " myOS.autoUpdate.{repoPath,invokingUser} directly. Auto-update is currently inactive.")
      ];
    })
    (lib.mkIf effective {
      systemd.services.nix-auto-update = {
        description = "Daily automatic Nix flake update and boot entry rebuild";
        after = [ "network-online.target" "nss-lookup.target" ];
        wants = [ "network-online.target" ];
        unitConfig = {
          StartLimitIntervalSec = "600s";
          StartLimitBurst = 3;
        };
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "60s";
          WorkingDirectory = repoPath;
          ExecStart = "/bin/sh -c 'sudo -u ${invokingUser} ${pkgs.nix}/bin/nix flake update --flake . && ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake .#${cfg.flakeAttr}'";
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
    })
  ];
}
