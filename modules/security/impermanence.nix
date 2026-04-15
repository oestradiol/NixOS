{ config, lib, ... }:
let
  persistRoot = config.myOS.persistence.root;
in {
  config = lib.mkIf config.myOS.security.impermanence.enable {
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
          ".config/vesktop"
          ".config/discord"
          ".config/Signal"
          ".config/keepassxc"
          ".local/share/keyrings"
          ".gnupg"
          ".ssh"
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
        ];
        files = [ ".zsh_history" ];
      };
    };
  };

  assertions = [
    {
      assertion = !config.myOS.security.impermanence.enable || config.fileSystems ? "${persistRoot}";
      message = "Impermanence is enabled, but /persist is not mounted.";
    }
  ];
}
