# Repo-wide debug mode.
#
# Debug mode declaratively relaxes specific governance invariants so local
# debugging and recovery stop requiring ad-hoc edits to tracked modules.
# Each sub-flag relaxes exactly one invariant; nothing is relaxed unless the
# master switch (`myOS.debug.enable`) is also true.
#
# Debug mode must be off on production / published baselines. When it is on,
# an activation warning is emitted for each relaxation so the state is
# visible on every rebuild.
{ config, lib, ... }:
let
  cfg = config.myOS.debug;
  active = name: cfg.enable && cfg."${name}".enable;
in {
  options.myOS.debug = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Master gate for myOS debug mode.

        When false (the default), every `myOS.debug.*.enable` sub-flag is a
        no-op regardless of its own value: governance stays strict, account
        locks stay in place, and the tracked modules behave identically to
        the non-debug baseline.

        When true, any sub-flag that is also true takes effect and the
        associated invariant is relaxed. Warnings are emitted at activation
        listing which relaxations are active.
      '';
    };

    crossProfileLogin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When both `myOS.debug.enable` and this flag are true: every user
        with an `activeOnProfiles` binding gets its `hashedPasswordFile`
        set on every profile, and `hashedPassword = "!"` locks are lifted.
        This lets you authenticate with any declared account regardless of
        the booted profile — useful for recovering from a misconfigured
        binding, bootstrapping a new profile, or debugging PAM/greeter flows.

        It must not be left on in a stable baseline: the profile-user
        binding invariant that governance otherwise enforces is relaxed.
      '';
    };

    paranoidWheel.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When both `myOS.debug.enable` and this flag are true: the paranoid
        reference user (`ghost`) receives `"wheel"` in `extraGroups` and the
        governance assertion "paranoid user must not be in wheel" is
        skipped.

        Useful for emergency administration from the paranoid profile when
        the daily profile is unavailable. Should not remain enabled on a
        stable baseline: wheel on the hardened account is a documented
        anti-pattern in `docs/maps/HARDENING-TRACKER.md`.
      '';
    };

    warnings.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When both `myOS.debug.enable` and this flag are true: emit one
        NixOS warning per active relaxation at activation time, so debug
        state shows up in every `nixos-rebuild` output.

        Leaving this on is the recommended posture: silencing the warnings
        while debug mode is active is a footgun.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.warnings.enable) {
    warnings =
      lib.optional (active "crossProfileLogin")
        ("myOS.debug.crossProfileLogin.enable is ON: hashedPasswordFile is "
         + "set on every account regardless of profile and account-lock "
         + "invariants are relaxed.")
      ++ lib.optional (active "paranoidWheel")
        ("myOS.debug.paranoidWheel.enable is ON: ghost has \"wheel\" in "
         + "extraGroups on paranoid and the matching governance assertion "
         + "is skipped.");
  };
}
