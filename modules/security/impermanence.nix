{ config, lib, ... }:
let
  persistRoot = config.myOS.persistence.root;
  impermanenceEnabled = config.myOS.security.impermanence.enable;
in {
  config = lib.mkMerge [
    (lib.mkIf impermanenceEnabled {
      environment.persistence.${persistRoot} = {
        hideMounts = true;

        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
          "/var/lib/flatpak"
          "/var/lib/mullvad-vpn"
          "/etc/mullvad-vpn"
        ];

        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];

        users.player = {
          directories = [
            "Data"
            ".local/share/Steam"
            ".steam"
            ".config/Signal"
            ".config/keepassxc"
            ".local/share/keyrings"
            ".gnupg"
            ".ssh"
            # Flatpak app data
            ".local/share/flatpak"
            ".var/app/org.signal.Signal"
            ".var/app/com.spotify.Client"
            ".var/app/com.bitwarden.desktop"
            ".var/app/dev.vencord.Vesktop"
            ".var/app/md.obsidian.Obsidian"
            ".var/app/org.telegram.desktop"
            ".var/app/im.riot.Riot"
          ];
          files = [ ".zsh_history" ];
        };

        users."ghost" = {
          directories = [
            "Downloads"
            "Documents"
            ".config/Signal"
            ".config/keepassxc"
            ".gnupg"
            ".ssh"
            ".local/share/flatpak"
            ".var/app/org.signal.Signal"
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
