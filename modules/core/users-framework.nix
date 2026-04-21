# Two-axis user/profile framework — option shell (Stage 4a).
#
# Declares the `myOS.users.<name>.*` submodule that the framework uses
# to describe user personas independently of system profiles. No
# consumers yet — Stage 4b rewrites modules/core/users.nix to read from
# this attrset and Stage 4c migrates the rest of the tree.
#
# See docs/REFACTOR-PLAN.md §2 for the two-axis design and §7 for the
# XOR activation rule enforced here.
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS;

  # Compute `_activeOn` for each user: is the user unlocked / home-mounted
  # on the currently-selected profile? Exactly one of `activeOnProfiles`
  # (static list) and `activationPredicate` (arbitrary function) must be
  # non-null; the XOR assertion below enforces that. If both are null the
  # user is declared but never active (useful for transient / cold-wallet
  # accounts, though the assertion currently treats that as a misconfig
  # because the operator must state the intent explicitly).
  computeActive = uCfg:
    if uCfg.activeOnProfiles != null then
      builtins.elem cfg.profile uCfg.activeOnProfiles
    else if uCfg.activationPredicate != null then
      uCfg.activationPredicate cfg.profile
    else
      false;
in {
  options.myOS.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this user account is declared on this host. Setting
            enable=false removes the user entirely (useful when
            cherry-picking accounts via integrator flakes).
          '';
        };

        # ── Activation axis ─────────────────────────────────────────
        activeOnProfiles = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          example = [ "paranoid" ];
          description = ''
            Profile names under which this user is unlocked and
            home-mounted. Mutually exclusive with
            `activationPredicate`. Exactly one of the two must be set.
          '';
        };
        activationPredicate = lib.mkOption {
          type = lib.types.nullOr (lib.types.functionTo lib.types.bool);
          default = null;
          example = lib.literalExpression ''profile: profile != "paranoid"'';
          description = ''
            Escape-hatch predicate `profile: bool` for compound
            activation rules. Mutually exclusive with
            `activeOnProfiles`.
          '';
        };
        _activeOn = lib.mkOption {
          type = lib.types.bool;
          internal = true;
          readOnly = true;
          description = ''
            Computed: is this user active on the current profile?
            Derived from `activeOnProfiles` or `activationPredicate`.
          '';
        };

        # ── Unix identity ───────────────────────────────────────────
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "GECOS description for the Unix account.";
        };
        uid = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = ''
            Explicit UID. Required when the framework storage layout or
            another module must know the numeric ID before NixOS
            allocates one (e.g. tmpfs home-dir ownership).
          '';
        };
        shell = lib.mkOption {
          type = lib.types.package;
          default = pkgs.zsh;
          defaultText = lib.literalExpression "pkgs.zsh";
          description = "Login shell package.";
        };
        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Supplementary Unix groups. The `wheel` group is governed by
            `allowWheel` (do not put it here directly).
          '';
        };

        # ── Permissions ────────────────────────────────────────────
        allowWheel = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this user may belong to the `wheel` group.
            Governance asserts that no user active on a wheel-restricted
            profile may be in wheel without this flag.
          '';
        };

        # ── Home layout ────────────────────────────────────────────
        home = {
          persistent = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Fully persistent home subvolume. When false, the home is
              tmpfs-backed and only paths in `home.allowlist` survive a
              reboot via impermanence.
            '';
          };
          allowlist = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "Downloads" ".ssh" ".gnupg" ];
            description = ''
              Home-relative paths to persist when `home.persistent`
              is false. Ignored otherwise.
            '';
          };
          btrfsSubvol = lib.mkOption {
            type = lib.types.str;
            default = "@home-${name}";
            defaultText = lib.literalExpression ''"@home-''${name}"'';
            description = ''
              Btrfs subvolume name backing this user's home. Defaults to
              `@home-<name>`; override when adopting an existing disk
              layout (e.g. `@home-daily`, `@home-paranoid`).
            '';
          };
        };

        # ── home-manager binding ───────────────────────────────────
        homeManagerConfig = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a home-manager configuration file. Activated only on
            profiles where `_activeOn` is true, so inactive personas
            don't pollute the Nix store with unused home profiles.
          '';
        };

        # ── Identity (populated by Stage 5 *.local.nix; default null) ─
        identity = {
          git = {
            name = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "git user.name. Operator-owned; gitignored.";
            };
            email = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "git user.email. Operator-owned; gitignored.";
            };
          };
          audio.micSourceAlias = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              PipeWire / ALSA source name for the user's physical
              microphone (the `source=` argument to the pactl
              module-loopback invocation behind `echo_mic`). When null,
              the `echo_mic` shell alias is not emitted.
            '';
          };
          audio.micLoopbackSink = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Optional explicit sink name for the `echo_mic` loopback.
              When null, pactl chooses the default sink. Set when the
              operator's audio stack has several outputs and a specific
              one must receive the monitor stream.
            '';
          };
          workspace.autoUpdateRepoPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Filesystem path to the user's flake clone. Consumed by
              modules/desktop/auto-update.nix.
            '';
          };
        };
      };

      config._activeOn = computeActive config;
    }));
    default = { };
    description = ''
      Declarative user accounts keyed by Unix name. See
      docs/REFACTOR-PLAN.md §2 for the two-axis model.
    '';
  };

  # XOR activation: exactly one of activeOnProfiles / activationPredicate
  # must be set per user. Both null or both set is a build error.
  config.assertions = lib.mapAttrsToList (name: uCfg: {
    assertion = (uCfg.activeOnProfiles != null) != (uCfg.activationPredicate != null);
    message = ''
      myOS.users.${name}: exactly one of activeOnProfiles /
      activationPredicate must be non-null. Both null (or both set) is a
      misconfiguration — see docs/REFACTOR-PLAN.md §8 Q-ACTIVATION.
    '';
  }) (lib.filterAttrs (_: u: u.enable) config.myOS.users);
}
