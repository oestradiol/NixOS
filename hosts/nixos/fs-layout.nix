{ lib, config, ... }: 
let
  isParanoid = config.myOS.profile == "paranoid";
  isDaily = config.myOS.profile == "daily";
in
{
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/NIXCRYPT";
    # Note: allowDiscards disabled; using periodic fstrim instead (safer, no info-leak risk)
  };

  # Shared install assumptions for the fresh reinstall target.
  # Root is tmpfs. Persisted state lives on Btrfs subvolumes inside LUKS.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "mode=755" "size=4G" ];
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

  # Paranoid profile: selective home impermanence (tmpfs + allowlist)
  # @home-paranoid subvolume mounted to /persist/home/ghost for impermanence backing store
  # /home/ghost is tmpfs (wiped on boot) - only allowlisted items bind-mounted from /persist/home/ghost
  # NOTE: Derives uid/gid from config.users.users."ghost" - must match!
  fileSystems."/home/ghost" = lib.mkIf isParanoid {
    device = "none";
    fsType = "tmpfs";
    neededForBoot = true;
    options = [
      "defaults"
      "size=2G"
      "mode=700"
      "uid=${toString config.users.users."ghost".uid}"
      "gid=${toString config.users.groups.${config.users.users."ghost".group}.gid}"
    ];
  };
  fileSystems."/persist/home/ghost" = lib.mkIf isParanoid {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true;
    options = [ "subvol=@home-paranoid" "compress=zstd" "noatime" ];
  };

  # Daily profile: full home impermanence
  fileSystems."/home/player" = lib.mkIf isDaily {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true; # Required for impermanence
    options = [ "subvol=@home-daily" "compress=zstd" "noatime" ];
  };

  # Swap subvolume — must be created during install as @swap with nocow.
  # See docs/INSTALL-GUIDE.md Phase 1.
  fileSystems."/swap" = lib.mkIf isDaily {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@swap" "noatime" ];
  };
  # Swap file on Btrfs @swap subvolume — fallback behind zram for VR/gaming memory spikes
  swapDevices = lib.mkIf isDaily [{
    device = "/swap/swapfile";
    size = 8192;
  }];
}
