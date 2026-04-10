{ config, lib, pkgs, ... }:
let
  daily = config.myOS.profile == "daily";
  clamScan = pkgs.writeShellScript "clamav-daily-scan" ''
    set -eu
    target="/home/player /persist /var/lib"
    exec ${pkgs.clamav}/bin/clamscan -r --infected --exclude-dir='^/persist/etc/ssh$' $target
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
    systemd.services.clamav-daily-scan = {
      description = "Weekly ClamAV scan for persisted daily data";
      path = [ pkgs.clamav pkgs.coreutils pkgs.findutils ];
      serviceConfig = {
        Type = "oneshot";
        Nice = 10;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 7;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
      script = ''${clamScan} > /var/log/clamav-daily-scan.log 2>&1'';
    };

    systemd.timers.clamav-daily-scan = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "20m";
        OnUnitActiveSec = "1w";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
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
