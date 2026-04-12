{ config, lib, pkgs, ... }:
let
  daily = config.myOS.profile == "daily";

  # Daily shallow scan: quick check of high-risk locations
  clamScanShallow = pkgs.writeShellScript "clamav-shallow-scan" ''
    set -eu
    # Shallow scan: home downloads, tmp, and persist (where user data lives)
    # Excludes large media dirs and SSH keys
    targets="/home/player/Downloads /tmp /persist /var/tmp"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam$' \
      --max-filesize=50M \
      --max-scansize=100M \
      $targets
  '';

  # Weekly deep scan: full recursive scan of all persisted data
  clamScanDeep = pkgs.writeShellScript "clamav-deep-scan" ''
    set -eu
    # Deep scan: comprehensive check of all persisted locations
    # Higher limits for thoroughness, runs weekly when system is idle
    targets="/home/player /persist /var/lib"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam/steamapps$' \
      $targets
  '';

  aideCheck = pkgs.writeShellScript "aide-daily-check" ''
    set -eu
    db="/var/lib/aide/aide.db.gz"
    if [ ! -e "$db" ]; then
      echo "AIDE database not initialized yet; skipping."
      exit 0
    fi
    exec ${pkgs.aide}/bin/aide --check
  '';
in {
  config = lib.mkIf daily {
    # --- DAILY SHALLOW SCAN ---
    # Quick daily check of high-risk locations (downloads, temp dirs)
    # Fast, low resource impact, catches obvious threats
    systemd.services.clamav-shallow-scan = {
      description = "Daily shallow ClamAV scan (quick check of high-risk locations)";
      path = [ pkgs.clamav pkgs.coreutils pkgs.findutils ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 15;  # Lower priority than deep scan
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 7;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
      script = ''${clamScanShallow} > /var/log/clamav-shallow-scan.log 2>&1'';
    };

    systemd.timers.clamav-shallow-scan = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30m";
        OnUnitActiveSec = "1d";  # Daily
        RandomizedDelaySec = "60m";
        Persistent = true;
      };
    };

    # --- WEEKLY DEEP SCAN ---
    # Comprehensive recursive scan of all persisted data
    # Higher resource use, runs weekly, thorough check
    systemd.services.clamav-deep-scan = {
      description = "Weekly deep ClamAV scan (comprehensive recursive check)";
      path = [ pkgs.clamav pkgs.coreutils pkgs.findutils ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;  # Higher priority (less nice) for deep scan
        IOSchedulingClass = "idle";  # Only run when system is idle
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
      script = ''${clamScanDeep} > /var/log/clamav-deep-scan.log 2>&1'';
    };

    systemd.timers.clamav-deep-scan = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2h";  # Wait longer after boot
        OnUnitActiveSec = "1w";  # Weekly
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };

    # ClamAV virus signature updates (required for meaningful scans)
    services.clamav.updater = {
      enable = true;
      interval = "daily";
      frequency = 12;  # Check twice daily if interval is daily
    };

    systemd.services.aide-daily-check = {
      description = "Periodic AIDE integrity check";
      path = [ pkgs.aide pkgs.coreutils pkgs.gzip ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
      script = ''${aideCheck} > /var/log/aide-daily-check.log 2>&1'';
    };

    systemd.timers.aide-daily-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "45m";
        OnUnitActiveSec = "1w";
        RandomizedDelaySec = "45m";
        Persistent = true;
      };
    };
  };
}
