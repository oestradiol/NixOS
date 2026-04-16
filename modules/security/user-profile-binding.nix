{ config, lib, ... }:
# Guardrail module.
#
# `myOS.security.pamProfileBinding.enable` exists as an option (declared in
# modules/core/options.nix) but is INTENTIONALLY BLOCKED: every earlier draft
# implemented it via `security.pam.services.<name>.text`, which replaces the
# full PAM service file rather than safely extending the generated PAM stack,
# and every such draft tripped sudo / su / login on target hardware.
#
# The current profile/user binding policy is enforced by **account locking**
# (see modules/core/users.nix: daily locks `ghost`, paranoid locks `player`),
# which is simpler, safer, and achieves the same effect. See
# docs/maps/HARDENING-TRACKER.md row "PAM profile-binding" (rejected).
#
# This file stays in-tree so the option cannot be flipped on by accident:
# enabling it deliberately fires the assertion below.
{
  config = lib.mkIf config.myOS.security.pamProfileBinding.enable {
    assertions = [
      {
        assertion = false;
        message = ''
          myOS.security.pamProfileBinding.enable is intentionally blocked.
          The previous implementation replaced the full PAM service file
          (security.pam.services.<name>.text) instead of extending the
          generated stack and broke authentication on target hardware.
          Profile/user binding is currently enforced via account locking
          (modules/core/users.nix) which is simpler and safer. Do not
          re-enable this knob without reworking it onto a safe, stack-aware
          PAM integration path.
        '';
      }
    ];
  };
}
