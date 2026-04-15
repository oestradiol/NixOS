# VR option declarations and shared config
{ config, lib, pkgs, ... }: {
  security.pam.loginLimits = [
    # VR Compositor locks memory pages.
    # Without unlimited memlock, this fails with EPERM.
    { domain = "@users"; type = "soft"; item = "memlock"; value = "unlimited"; }
    { domain = "@users"; type = "hard"; item = "memlock"; value = "unlimited"; }
    # Realtime priority perms
    { domain = "@realtime"; type = "soft"; item = "rtprio"; value = "99"; }
  ];

  # WiVRn
  services.wivrn = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    package = (pkgs.wivrn.override { cudaSupport = config.myOS.gpu == "nvidia"; });
    config.json = {
      encoders = [
        {
          encoder = "nvenc";
          codec = "h265";
        }
      ];
    };
  };
  systemd.user.services.wivrn = {
    serviceConfig = {
      Nice = -10;
      LimitRTPRIO = 99;
      LimitMEMLOCK = "infinity";
      Group = "realtime";
    };
  };

  # Other
  environment.systemPackages = with pkgs; [
    wayvr # Overlay
  ];
}
