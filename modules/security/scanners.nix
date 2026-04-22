{ config, lib, pkgs, ... }:
let
  scanCfg = config.myOS.security.scanners;
  scannerOptions = {
    options.myOS.security.scanners = {
      clamav.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          ClamAV impermanence-scan + deep-scan systemd timers and the
          freshclam signature updater.
        '';
      };
      aide.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          AIDE integrity monitoring (weekly timer + /etc/aide.conf policy).
        '';
      };
    };
  };

  # Build scan targets from active users' home configurations
  enabledUsers = lib.filterAttrs (_: u: u.enable) config.myOS.users;
  activeUsers = lib.filterAttrs (_: u: u._activeOn) enabledUsers;
  # For persistent homes: scan /home/<name>
  # For tmpfs homes: scan /persist/home/<name> (impermanence backing store)
  userHomePaths = lib.mapAttrsToList (_: u:
    if u.home.persistent
    then "/home/${u.home.btrfsSubvol}"
    else "/persist/home/${u.home.btrfsSubvol}"
  ) activeUsers;

  clamTargetPaths =
    [ "/persist" "/var/lib" "/var/log" "/boot" "/nix/var/nix/profiles" ]
    ++ userHomePaths;

  clamTargets = ''
    targets=()
    for p in ${lib.escapeShellArgs clamTargetPaths}; do
      if [ -e "$p" ]; then
        targets+=("$p")
      fi
    done
    if [ "''${#targets[@]}" -eq 0 ]; then
      echo "No scan targets found; skipping."
      exit 0
    fi
  '';

  runClamScan = name: extraArgs: pkgs.writeShellScript name ''
    set -eu
    ${clamTargets}
    rc=0
    ${pkgs.clamav}/bin/clamscan -r --infected       --exclude-dir='^/persist/etc/ssh$'       --exclude-dir='^/persist/home/[^/]+/etc/ssh$'       --exclude-dir='^/home/[^/]+/.*\.steam$'       --exclude-dir='^/home/[^/]+/\.local/share/Steam$'       --exclude-dir='^/home/[^/]+/\.local/share/Steam/steamapps$'       --exclude-dir='^/home/[^/]+/\.var/app$'       --exclude-dir='^/var/log/journal$'       ${extraArgs}       "''${targets[@]}" || rc=$?
    case "$rc" in
      0)
        exit 0
        ;;
      1)
        echo "ClamAV detected suspicious files during ${name}. See the log for details." >&2
        ${pkgs.util-linux}/bin/logger -p authpriv.alert -t ${name} "ClamAV detected suspicious files. Review the corresponding scan log immediately."
        exit 0
        ;;
      *)
        echo "ClamAV scan failed with exit code $rc" >&2
        exit "$rc"
        ;;
    esac
  '';

  # Daily persisted-state scan: durable paths that survive reboot for the active profile only
  # Critical: runs daily to catch malware in persisted locations and boot surfaces
  # TRUST NOTE: Steam runtime, Flatpak user data (~/.var/app), and Nix store are excluded.
  # System Flatpak content under /var/lib/flatpak is scanned as part of /var/lib.
  clamScanImpermanence = runClamScan "clamav-impermanence-scan" ''
      --max-filesize=100M \
      --max-scansize=200M
    '';

  # Weekly deep scan: comprehensive scan with higher limits for the active profile only
  # More thorough but resource-intensive, runs weekly when idle
  # TRUST NOTE: Steam runtime, Flatpak user data (~/.var/app), and Nix store are excluded.
  # System Flatpak content under /var/lib/flatpak is scanned as part of /var/lib.
  clamScanDeep = runClamScan "clamav-deep-scan" "";

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
  inherit (scannerOptions) options;
  config = lib.mkIf (scanCfg.clamav.enable || scanCfg.aide.enable) {
    # --- IMPERMANENCE SCAN ---
    # Daily scan of all durable state - critical for security
    # Focuses on paths where malware or tampering can survive a reboot.
    systemd.services.clamav-impermanence-scan = lib.mkIf scanCfg.clamav.enable {
      description = "Daily ClamAV scan of persisted state and boot surfaces";
      path = [ pkgs.clamav pkgs.coreutils pkgs.findutils pkgs.util-linux ];
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
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
      };
      script = ''${clamScanImpermanence} > /var/log/clamav-impermanence-scan.log 2>&1'';
    };

    systemd.timers.clamav-impermanence-scan = lib.mkIf scanCfg.clamav.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30m";
        OnUnitActiveSec = "1d";  # Daily
        RandomizedDelaySec = "60m";
        Persistent = true;
      };
    };

    # --- WEEKLY DEEP SCAN ---
    # Comprehensive recursive scan of all durable state and boot chain surfaces
    # Higher resource use, runs weekly, thorough check
    systemd.services.clamav-deep-scan = lib.mkIf scanCfg.clamav.enable {
      description = "Weekly deep ClamAV scan (comprehensive recursive check)";
      path = [ pkgs.clamav pkgs.coreutils pkgs.findutils pkgs.util-linux ];
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
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
      };
      script = ''${clamScanDeep} > /var/log/clamav-deep-scan.log 2>&1'';
    };

    systemd.timers.clamav-deep-scan = lib.mkIf scanCfg.clamav.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2h";  # Wait longer after boot
        OnUnitActiveSec = "1w";  # Weekly
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
    };

    # ClamAV virus signature updates (required for meaningful scans)
    services.clamav.updater = lib.mkIf scanCfg.clamav.enable {
      enable = true;
      interval = "daily";
      frequency = 12;  # Check twice daily if interval is daily
    };

    # --- AIDE INTEGRITY MONITORING ---
    # Weekly integrity check of stable, security-critical persisted paths only
    # AIDE must be initialized first: sudo aide --init (stored in /persist)
    # Database location persisted via impermanence.nix
    #
    # DESIGN: ultra-high-signal integrity model.
    # AIDE is intentionally NOT pointed at whole homes, logs, caches, runtime state,
    # package trees, or other naturally changing locations. That would create noise
    # and train you to ignore it.
    #
    # AIDE vs ClamAV: Different security models
    # - ClamAV: "Is this file known malware?" (signature-based detection)
    # - AIDE: "Did a stable, security-critical file change unexpectedly?" (integrity/hash-based)
    #
    # LIMIT: neither tool can prove a live kernel compromise away. If the running kernel is already
    # malicious, file-based scanners can be blinded. These checks are therefore persistence-aware,
    # especially for boot, identity, trust, and generation-selection surfaces.
    #
    # MONITORED (stable + security-critical):
    # - /boot: EFI/kernel/initrd generation chain
    # - /nix/var/nix/profiles: active system-profile links that select generations
    # - /persist/etc/{passwd,group,shadow,gshadow,subuid,subgid,machine-id}: identity/account base
    # - /persist/etc/ssh: SSH host identity
    # - /persist/etc/NetworkManager/system-connections: network trust/config
    # - /persist/var/lib/{nixos,aide,sbctl}: NixOS state, integrity DB, Secure Boot keys
    #
    # EXCLUDED ON PURPOSE (too noisy for AIDE):
    # - whole /persist tree
    # - whole /var/lib tree
    # - /var/log, /tmp, /var/tmp
    # - active users' home data (both /home/<user> and /persist/home/<user>)
    # - Flatpak trees, Steam trees, browser profiles, app state, package caches
    environment.etc."aide.conf".text = lib.mkDefault (lib.concatStringsSep "
" [
      "# AIDE configuration - ultra-high-signal stable security surfaces only"
      "# Deliberately excludes noisy user/app/package/runtime state"
      ""
      "# Database settings"
      "database=file:/var/lib/aide/aide.db.gz"
      "database_out=file:/var/lib/aide/aide.db.new.gz"
      ""
      "# Rule definitions"
      "R=p+u+g+md5+sha256"
      ""
      "# Boot chain / generation selection"
      "/boot R"
      "/nix/var/nix/profiles R"
      "!/nix/var/nix/profiles/per-user"
      ""
      "# Persisted identity / trust / system state"
      "/persist/etc/passwd R"
      "/persist/etc/group R"
      "/persist/etc/shadow R"
      "/persist/etc/gshadow R"
      "/persist/etc/subuid R"
      "/persist/etc/subgid R"
      "/persist/etc/machine-id R"
      "/persist/etc/ssh R"
      "/persist/etc/NetworkManager/system-connections R"
      "/persist/var/lib/nixos R"
      "/persist/var/lib/aide R"
      "/persist/var/lib/sbctl R"
    ]);

    # AIDE services only if aide.enable is true (allows ClamAV-only if desired)
    systemd.services.aide-daily-check = lib.mkIf scanCfg.aide.enable {
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
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
      };
      script = ''${aideCheck} > /var/log/aide-daily-check.log 2>&1'';
    };

    systemd.timers.aide-daily-check = lib.mkIf scanCfg.aide.enable {
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
