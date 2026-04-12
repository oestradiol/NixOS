# Hardware-adapted target layout for the main NVMe reinstall.
# This replaces the current ext4 layout with:
# EFI -> LUKS2 -> Btrfs subvolumes -> tmpfs root + impermanence.
# Use the partition labels from docs/INSTALL-GUIDE.md exactly.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/NIXCRYPT";
    # Note: allowDiscards disabled; using periodic fstrim instead (safer, no info-leak risk)
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/NIXBOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true;
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/persist" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true;
    options = [ "subvol=@persist" "compress=zstd" "noatime" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true;
    options = [ "subvol=@log" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/player" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true; # Required for impermanence
    options = [ "subvol=@home-daily" "compress=zstd" "noatime" ];
  };

  # Paranoid profile: selective home impermanence (tmpfs + allowlist)
  # @home-paranoid subvolume mounted to /persist/home/ghost for impermanence backing store
  # /home/ghost is tmpfs (wiped on boot) - only allowlisted items bind-mounted from /persist/home/ghost
  # NOTE: Derives uid/gid from config.users.users."ghost" - must match!
  fileSystems."/home/ghost" = {
    device = "none";
    fsType = "tmpfs";
    neededForBoot = true;
    options = [
      "defaults"
      "size=2G"
      "mode=700"
      "uid=${toString config.users.users."ghost".uid}"
      "gid=${toString config.users.users."ghost".gid}"
    ];
  };
  fileSystems."/persist/home/ghost" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true;
    options = [ "subvol=@home-paranoid" "compress=zstd" "noatime" ];
  };

  swapDevices = lib.mkDefault [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
