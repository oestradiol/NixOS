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
    allowDiscards = true;
    preLVM = false;
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

  fileSystems."/home/ghost" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true; # Required for impermanence
    options = [ "subvol=@home-paranoid" "compress=zstd" "noatime" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
