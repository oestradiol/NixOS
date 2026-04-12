{ config, lib, pkgs, ... }:
let
  daily = config.myOS.profile == "daily";
  paranoid = config.myOS.profile == "paranoid";

  # Script to enforce user/profile binding
  # SECURITY NOTES:
  # - Uses 'requisite' not 'required' for immediate fail (no password prompt for wrong user)
  # - Default deny: if profile detection fails, only root allowed
  # - For sudo: checks both calling user AND target user (via PAM_RUSER for target)
  profileCheckScript = pkgs.writeShellScript "user-profile-binding" ''
    set -eu

    CALLING_USER="$PAM_USER"
    # PAM_RUSER is the target user for su/sudo, defaults to calling user if not set
    TARGET_USER="''${PAM_RUSER:-$CALLING_USER}"
    PROFILE="${if daily then "daily" else if paranoid then "paranoid" else "unknown"}"

    # Safety: if PAM_USER is unset, deny (should never happen)
    if [ -z "$CALLING_USER" ]; then
      echo "Access denied: PAM_USER not set" >&2
      exit 1
    fi

    # Always allow root (emergency access if script breaks)
    if [ "$CALLING_USER" = "root" ]; then
      exit 0
    fi

    # Default deny: unknown profile = only root allowed
    if [ "$PROFILE" = "unknown" ]; then
      echo "Access denied: unknown profile context" >&2
      exit 1
    fi

    # For sudo/su: if becoming a different user, check target user against profile
    if [ "$TARGET_USER" != "$CALLING_USER" ]; then
      # Daily profile: can only become player, not ghost
      if [ "$PROFILE" = "daily" ] && [ "$TARGET_USER" = "ghost" ]; then
        echo "Access denied: cannot become 'ghost' on daily profile" >&2
        exit 1
      fi
      # Paranoid profile: can only become ghost, not player
      if [ "$PROFILE" = "paranoid" ] && [ "$TARGET_USER" = "player" ]; then
        echo "Access denied: cannot become 'player' on paranoid profile" >&2
        exit 1
      fi
    fi

    # For direct login: check calling user against profile
    # Daily profile: only player allowed
    if [ "$PROFILE" = "daily" ] && [ "$CALLING_USER" = "ghost" ]; then
      echo "Access denied: 'ghost' user not allowed on daily profile" >&2
      exit 1
    fi

    # Paranoid profile: only ghost allowed
    if [ "$PROFILE" = "paranoid" ] && [ "$CALLING_USER" = "player" ]; then
      echo "Access denied: 'player' user not allowed on paranoid profile" >&2
      exit 1
    fi

    exit 0
  '';
  # Only enable if explicitly opted in (high-risk PAM implementation)
  pamEnabled = config.myOS.security.pamProfileBinding.enable;
in {
  config = lib.mkIf (pamEnabled) {
    # PAM rules using 'requisite' for immediate fail-fast (no password prompt for wrong user)
    # Order 100 = before password authentication modules

    # SDDM (GUI login)
    security.pam.services.sddm.text = lib.mkDefault (lib.mkOrder 100 ''
      auth requisite ${pkgs.pam}/lib/security/pam_exec.so stdout ${profileCheckScript}
    '');

    # login (TTY)
    security.pam.services.login.text = lib.mkDefault (lib.mkOrder 100 ''
      auth requisite ${pkgs.pam}/lib/security/pam_exec.so stdout ${profileCheckScript}
    '');

    # su (switch user)
    security.pam.services.su.text = lib.mkDefault (lib.mkOrder 100 ''
      auth requisite ${pkgs.pam}/lib/security/pam_exec.so stdout ${profileCheckScript}
    '');

    # sudo (privilege escalation - checks target user too)
    security.pam.services.sudo.text = lib.mkDefault (lib.mkOrder 100 ''
      auth requisite ${pkgs.pam}/lib/security/pam_exec.so stdout ${profileCheckScript}
    '');
  };
}
