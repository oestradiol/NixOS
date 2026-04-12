{ config, lib, pkgs, ... }:
let
  daily = config.myOS.profile == "daily";

  # Daily impermanence scan: all persisted data (impermanence directories)
  # Critical: runs daily to catch malware in persisted locations
  clamScanImpermanence = pkgs.writeShellScript "clamav-impermanence-scan" ''
    set -eu
    # Scan ALL impermanence directories daily
    # These are the only places malware can survive a reboot
    # Plus /tmp and /var/tmp (common malware drop zones)
    targets="/home/player /persist /var/lib /var/log /tmp /var/tmp"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam$' \
      --exclude-dir='^/var/log/journal$' \
      --max-filesize=100M \
      --max-scansize=200M \
      $targets
  '';

  # Weekly deep scan: comprehensive scan with higher limits
  # More thorough but resource-intensive, runs weekly when idle
  clamScanDeep = pkgs.writeShellScript "clamav-deep-scan" ''
    set -eu
    # Deep scan: comprehensive check of all persisted locations
    # Higher limits for thoroughness, runs weekly when system is idle
    # NOTE: /persist/home-ghost is NOT scanned - ghost files isolated from daily
    # Includes /tmp and /var/tmp (common malware drop zones)
    targets="/home/player /persist /var/lib /var/log /tmp /var/tmp"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam/steamapps$' \
      --exclude-dir='^/var/log/journal$' \
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
    # --- DAILY IMPERMANENCE SCAN ---
    # Daily scan of all impermanence directories - critical for security
    # These are the only places malware can survive a reboot
    systemd.services.clamav-impermanence-scan = {
      description = "Daily ClamAV scan of impermanence directories (persisted data)";
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
      script = ''${clamScanImpermanence} > /var/log/clamav-impermanence-scan.log 2>&1'';
    };

    systemd.timers.clamav-impermanence-scan = {
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

    # --- AIDE INTEGRITY MONITORING ---
    # Weekly integrity check of critical persisted directories
    # AIDE must be initialized first: sudo aide --init (stored in /persist)
    # Database location persisted via impermanence.nix
    # NOTE: /persist/home-ghost is NOT monitored - ghost files isolated from daily
    environment.etc."aide.conf".text = lib.mkDefault (lib.concatStringsSep "\n" [
      "# AIDE configuration for impermanence integrity monitoring"
      "# Monitors all persisted directories (where malware can survive reboot)"
      "# NOTE: /persist/home-ghost excluded - ghost profile files isolated from daily"
      ""
      "# Database settings"
      "database=file:/var/lib/aide/aide.db.gz"
      "database_out=file:/var/lib/aide/aide.db.new.gz"
      ""
      "# Rule definitions"
      "R=p+u+g+md5+sha256"
      "L=p+u+g+sha256"
      ""
      "# Impermanence directories (all persisted data)"
      "/persist R"
      "/home/player R"
      "/var/lib R"
      "/var/log L"
      "/tmp L"
      "/var/tmp L"
      ""
      "# Exclude noisy/volatile paths"
      "!/persist/var/lib/aide"
      "!/home/player/.local/share/Steam"
      "!/home/player/.steam"
      "!/var/lib/systemd"
      "!/var/log/journal"
    ]);

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
