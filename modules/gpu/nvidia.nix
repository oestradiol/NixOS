# NVIDIA GPU driver configuration
{ config, lib, pkgs, ... }:
lib.mkIf (config.myOS.gpu == "nvidia") {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # Required for gamescope and Wayland
    powerManagement.enable = true;
    # Start with proprietary modules for VR stability.
    # open = true is supported on Turing+ but has reported VA-API and
    # VR issues. Toggle to true after confirming system stability.
    open = lib.mkDefault false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  environment.sessionVariables = {
    # Hint for electron/chromium apps on NVIDIA Wayland
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
