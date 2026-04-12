# NVIDIA GPU driver configuration
{ config, lib, pkgs, ... }:
lib.mkIf (config.myOS.gpu == "nvidia") {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    # NVIDIA powerManagement follows allowSleep: only enable if sleep states are allowed
    # This avoids suspend/resume issues when sleep is disabled
    powerManagement.enable = config.myOS.security.allowSleep;
    open = lib.mkDefault false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
  };
}
