{ config, lib, pkgs, ... }:
let
  persistRoot = config.myOS.persistence.root;
  impermanenceEnabled = config.myOS.security.impermanence.enable;
  persistMachineId = config.myOS.security.persistMachineId;
  machineIdValue = config.myOS.security.machineIdValue;
  profile = config.myOS.profile;
in {
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
        # Daily-only persistence: Bluetooth (controllers), Mullvad app state
        ++ lib.optionals (profile == "daily") [
          "/var/lib/bluetooth"
          "/var/lib/mullvad-vpn"
          "/etc/mullvad-vpn"
        ]
        # NetworkManager full state: daily gets persistence (operational stability for Wi-Fi leases)
        # paranoid gets minimal (connections only, state regenerates)
        ++ lib.optionals (profile == "daily") [
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

    (lib.mkIf (impermanenceEnabled && profile == "paranoid") {
      environment.persistence.${persistRoot} = {
        # NOTE: Daily profile (/home/player): fully persistent Btrfs subvolume (@home-daily).
        # Do not duplicate that persistence through impermanence allowlists here.
        #
        # NOTE: Paranoid profile (/home/ghost): selective impermanence (tmpfs + allowlist)
        # @home-paranoid is mounted at /persist/home/ghost, and only allowlisted items
        # are persisted. The home directory itself is tmpfs and is wiped on every boot.
        users."ghost" = {
          # Note: home directory is now automatically deduced by impermanence module
          # @home-paranoid should be mounted at /persist/home/ghost
          directories = [
            "Downloads"
            "Documents"
            ".config/Signal"
            ".config/keepassxc"
            ".local/share/KeePassXC"  # KeePassXC database storage
            ".local/share/keyrings"  # Password/key storage
            ".local/share/applications"  # Custom desktop entries
            ".gnupg"
            ".ssh"
            ".local/share/flatpak"
            ".var/app/org.signal.Signal"
            ".mozilla/safe-firefox"
          ];
          files = [ ".zsh_history" ];
        };
      };
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
