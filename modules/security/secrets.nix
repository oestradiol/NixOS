{ config, lib, ... }:
{
  options.myOS.security.agenix.enable = lib.mkEnableOption "agenix secrets";

  config = lib.mkIf config.myOS.security.agenix.enable {
    age.identityPaths = [
      "/persist/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key"
    ];

    age.secrets = {
      # Example placeholders. Create these after install:
      # mullvad-account.file = ../../secrets/mullvad-account.age;
      # ssh-private.file = ../../secrets/ssh-private.age;
    };
  };
}
