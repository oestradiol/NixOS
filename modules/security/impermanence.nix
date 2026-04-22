{ config, lib, pkgs, ... }:
let
  persistRoot = config.myOS.persistence.root;
  impermanenceEnabled = config.myOS.security.impermanence.enable;
  persistMachineId = config.myOS.security.persistMachineId;
  machineIdValue = config.myOS.security.machineIdValue;
in {
  options.myOS.security = {
    impermanence.enable = lib.mkEnableOption "tmpfs root + explicit persistence";
    persistMachineId = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Persist /etc/machine-id across reboots via impermanence.
      '';
    };
    machineIdValue = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Explicit machine-id value to set. When null, systemd generates the ID.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf impermanenceEnabled {
      environment.persistence.${persistRoot} = {
        # Note: hideMounts and allowOther removed - impermanence now uses real bind mounts

        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
          "/var/lib/aide"  # AIDE integrity database
          "/var/lib/sbctl"  # Secure Boot keys (Lanzaboote/sbctl)
          "/var/lib/logrotate"  # logrotate.status: without this, /var/lib/logrotate.status.tmp
                                # lands on the tmpfs root and logrotate.service fails the
                                # first time it tries to write state.
          "/var/lib/clamav"  # CVD virus database (freshclam downloads here). Without
                             # persistence, clamav-impermanence-scan fails with
                             # "cl_load(): No such file or directory" until freshclam
                             # has populated the dir after each boot.
          "/var/lib/fwupd"   # Firmware metadata cache; without persistence fwupd
                             # re-downloads every boot AND is the first casualty when
                             # / is tmpfs-exhausted (seen 2026-04).
          "/etc/NetworkManager/system-connections"
          "/var/lib/flatpak"
        ]
        # Gaming/Bluetooth state: persist if controllers or bluetooth are enabled
        ++ lib.optionals (config.myOS.gaming.controllers.enable or config.services.bluetooth.enable) [
          "/var/lib/bluetooth"
        ]
        # VPN state: persist if Mullvad is enabled
        ++ lib.optionals config.services.mullvad-vpn.enable [
          "/var/lib/mullvad-vpn"
          "/etc/mullvad-vpn"
        ]
        # NetworkManager full state: persist when enabled (for Wi-Fi lease stability)
        ++ lib.optionals config.networking.networkmanager.enable [
          "/var/lib/NetworkManager"
        ];

        files = []
        # machine-id: persisted for both profiles; systemd generates the unique ID
        ++ lib.optionals persistMachineId [
          "/etc/machine-id"
        ]
        # SSH host keys: persisted only when the SSH server is actually running.
        # With services.openssh.enable = false (current baseline in desktop/base.nix),
        # sshd never runs and therefore never generates /etc/ssh/ssh_host_*_key.
        # Persisting them anyway produced dangling symlinks (target missing) that
        # `tests/runtime/200-persistence.sh` rightly flagged. When openssh is
        # enabled in the future, drop this guard and unconditionally persist.
        ++ lib.optionals config.services.openssh.enable [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };
    })
    
    # Set explicit machine-id if configured (exceptional override path)
    (lib.mkIf (impermanenceEnabled && persistMachineId && machineIdValue != null) {
      # Use systemd tmpfiles to set the machine-id at boot
      # This runs before systemd-machine-id-commit.service
      systemd.tmpfiles.rules = [
        "f /etc/machine-id 0444 root root - ${machineIdValue}"
      ];

      # Ensure the file is writable during early boot so tmpfiles can set it
      boot.initrd.systemd.tmpfiles.settings = {
        "10-machine-id"."/etc/machine-id"."f" = {
          mode = "0444";
          user = "root";
          group = "root";
          argument = machineIdValue;
        };
      };
    })

    # Impermanence allowlists for users with home.persistent = false.
    # Each user's allowlist is declared in their account file (accounts/*.nix).
    (lib.mkIf impermanenceEnabled {
      environment.persistence.${persistRoot}.users =
        let
          enabledUsers = lib.filterAttrs (_: u: u.enable) config.myOS.users;
          tmpfsUsers = lib.filterAttrs (_: u: !u.home.persistent) enabledUsers;
        in
        lib.mapAttrs (_: u: {
          directories = u.home.allowlist;
          files = [ ".zsh_history" ];
        }) tmpfsUsers;
    })
    
    {
      assertions = [
        {
          assertion = !impermanenceEnabled || (config.fileSystems ? "${persistRoot}");
          message = "Impermanence is enabled, but ${persistRoot} is not mounted.";
        }
      ];
    }
  ];
}
