{ config, lib, pkgs, ... }:
let
  daily = config.myOS.profile == "daily";
  paranoid = config.myOS.profile == "paranoid";

  # Daily impermanence scan: all persisted data (impermanence directories)
  # Critical: runs daily to catch malware in persisted locations
  # TRUST NOTE: Steam runtime, Flatpak user data (~/.var/app), and Nix store are excluded.
  # System Flatpak content under /var/lib/flatpak is scanned as part of /var/lib.
  clamScanImpermanence = pkgs.writeShellScript "clamav-impermanence-scan" ''
    set -eu
    # Scan ALL impermanence directories daily
    # These are the only places malware can survive a reboot
    # Plus /tmp and /var/tmp (common malware drop zones)
    # EFI partition: bootkit target, must be scanned
    # Scan both daily and paranoid persisted directories
    targets="/home/player /home/ghost /persist /persist/home/ghost /var/lib /var/log /tmp /var/tmp /boot"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/persist/home/ghost/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam$' \
      --exclude-dir='^/home/player/\.var/app$' \
      --exclude-dir='^/var/log/journal$' \
      --max-filesize=100M \
      --max-scansize=200M \
      $targets
  '';

  # Weekly deep scan: comprehensive scan with higher limits
  # More thorough but resource-intensive, runs weekly when idle
  # TRUST NOTE: Steam runtime, Flatpak user data (~/.var/app), and Nix store are excluded.
  # System Flatpak content under /var/lib/flatpak is scanned as part of /var/lib.
  clamScanDeep = pkgs.writeShellScript "clamav-deep-scan" ''
    set -eu
    # Deep scan: comprehensive check of all persisted locations
    # Higher limits for thoroughness, runs weekly when system is idle
    # Deep scan both daily and paranoid persisted directories
    targets="/home/player /home/ghost /persist /persist/home/ghost /var/lib /var/log /tmp /var/tmp /boot"
    exec ${pkgs.clamav}/bin/clamscan -r --infected \
      --exclude-dir='^/persist/etc/ssh$' \
      --exclude-dir='^/persist/home/ghost/etc/ssh$' \
      --exclude-dir='^/home/player/.*\.steam$' \
      --exclude-dir='^/home/player/\.local/share/Steam/steamapps$' \
      --exclude-dir='^/home/player/\.var/app$' \
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
  config = lib.mkIf (daily || paranoid) {
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
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
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
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
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
    # Weekly integrity check of critical persisted directories only
    # AIDE must be initialized first: sudo aide --init (stored in /persist)
    # Database location persisted via impermanence.nix
    #
    # DESIGN: High-signal integrity model - only monitor paths where malware can persist
    # across reboots AND that have stable contents. Volatile paths create noise.
    #
    # AIDE vs ClamAV: Different security models
    # - ClamAV: "Is this file known malware?" (signature-based detection)
    # - AIDE: "Did this file change unexpectedly?" (integrity/hash-based detection)
    #
    # They complement each other:
    # - ClamAV catches known malware (even if it hasn't modified files yet)
    # - AIDE catches unknown malware / rootkits that modify persisted files
    # - Zero-day malware won't be in ClamAV DB, but AIDE will flag file changes
    #
    # If you prefer ClamAV-only: set myOS.security.aide.enable = false
    #
    # MONITORED (high-value persisted):
    # - /persist, /persist/home/ghost: explicit persistence (impermanence.nix)
    # - /home/player: Btrfs subvolume (daily profile, persisted)
    # - /var/lib: system state that survives reboot
    #
    # EXCLUDED (volatile or inappropriate for integrity monitoring):
    # - /home/ghost: tmpfs on paranoid (wiped every boot - naturally churns)
    # - /var/log: log files naturally change; integrity != log monitoring
    # - /tmp, /var/tmp: tmpfs (wiped on boot)
    environment.etc."aide.conf".text = lib.mkDefault (lib.concatStringsSep "\n" [
      "# AIDE configuration - high-signal persisted-state integrity only"
      "# Monitors paths where malware can survive reboot AND contents are stable"
      "# Excludes volatile paths (tmpfs, logs) that create noise without security value"
      ""
      "# Database settings"
      "database=file:/var/lib/aide/aide.db.gz"
      "database_out=file:/var/lib/aide/aide.db.new.gz"
      ""
      "# Rule definitions"
      "R=p+u+g+md5+sha256"
      ""
      "# Persisted directories only (high-value integrity targets)"
      "/persist R"
      "/persist/home/ghost R"
      "/home/player R"
      "/var/lib R"
      ""
      "# Exclude noisy/volatile paths"
      "!/persist/var/lib/aide"
      "!/home/player/.local/share/Steam"
      "!/home/player/.steam"
      "!/var/lib/systemd"
    ]);

    # AIDE services only if aide.enable is true (allows ClamAV-only if desired)
    systemd.services.aide-daily-check = lib.mkIf config.myOS.security.aide.enable {
      description = "Periodic AIDE integrity check";
      path = [ pkgs.aide pkgs.coreutils pkgs.gzip ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
      };
      script = ''${aideCheck} > /var/log/aide-daily-check.log 2>&1'';
    };

    systemd.timers.aide-daily-check = lib.mkIf config.myOS.security.aide.enable {
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
