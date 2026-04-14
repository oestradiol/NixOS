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
          # NOTE: Both profiles persist a stable unique machine-id. No rotation issues.
          "/var/lib/systemd"
          "/var/lib/aide"  # AIDE integrity database
          "/var/lib/sbctl"  # Secure Boot keys (Lanzaboote/sbctl)
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

        # CRITICAL: /etc identity files must persist with tmpfs root + mutableUsers
        # Without these, imperative password changes are lost on reboot
        # See: https://nixos.org/manual/nixos/stable/options#opt-users.mutableUsers
        files = [
          "/etc/passwd"
          "/etc/group"
          "/etc/shadow"
          "/etc/gshadow"
          "/etc/subuid"
          "/etc/subgid"
        ]
        # machine-id: persisted for both profiles; systemd generates the unique ID
        ++ lib.optionals persistMachineId [
          "/etc/machine-id"
        ]
        ++ [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];

        # NOTE: Daily profile (/home/player): fully persistent Btrfs subvolume (@home-daily)
        # These allowlists manage dotfiles within an already-persistent home.
        #
        # NOTE: Paranoid profile (/home/ghost): selective impermanence (tmpfs + allowlist)
        # @home-paranoid is mounted to /persist/home/ghost, and only allowlisted items
        # are persisted. The home directory itself is tmpfs - wiped on every boot.
        # This is "ephemeral root + selective home persistence" for paranoid.
        users.player = {
          directories = [
            "Data"
            ".local/share/Steam"
            ".steam"
            ".config/Signal"
            # NOTE: KeePassXC is paranoid-only; daily uses Bitwarden (Flatpak)
            ".local/share/keyrings"
            ".local/share/applications"  # Custom desktop entries
            ".gnupg"
            ".ssh"
            # Flatpak app data
            ".local/share/flatpak"
            ".var/app/org.signal.Signal"
            ".var/app/com.spotify.Client"
            ".var/app/com.bitwarden.desktop"
            ".var/app/dev.vencord.Vesktop"
            ".var/app/md.obsidian.Obsidian"
            # Windsurf (sandboxed app) - persists configs
            ".config/Windsurf"
            ".local/share/Windsurf"
            # VRCX (sandboxed app) - persists configs
            ".config/VRCX"
          ];
          files = [ ".zsh_history" ];
        };

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
          ];
          files = [ ".zsh_history" ];
        };
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
