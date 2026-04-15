{ config, lib, pkgs, ... }:
let
  safeFirefox = pkgs.writeShellScriptBin "safe-firefox" ''
    set -eu
    runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/safe-firefox"
    profile="$runtime/profile"
    mkdir -p "$profile"
    exec systemd-run --user --collect --quiet --same-dir --service-type=exec       -p PrivateTmp=yes       -p PrivateDevices=yes       -p NoNewPrivileges=yes       -p ProtectSystem=strict       -p ProtectHome=tmpfs       -p ProtectKernelTunables=yes       -p ProtectKernelLogs=yes       -p ProtectControlGroups=yes       -p RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6       -p LockPersonality=yes       ${pkgs.bubblewrap}/bin/bwrap         --new-session         --die-with-parent         --dev-bind / /         --tmpfs "$HOME/.mozilla"         --bind "$profile" "$profile"         ${pkgs.firefox}/bin/firefox --no-remote --profile "$profile" "$@"
  '';
in {
  environment.systemPackages = [ safeFirefox ];

  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisplayBookmarksToolbar = "never";
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      Preferences = {
        "media.peerconnection.enabled" = false;
        "privacy.resistFingerprinting" = config.myOS.security.browserLockdown.enable;
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
      };
    } // lib.optionalAttrs config.myOS.security.browserLockdown.enable {
      DisableFirefoxAccounts = true;
      ExtensionSettings = {
        "*" = { installation_mode = "blocked"; };
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
  };
}
