{ lib, config, pkgs, ... }: 
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
  #
  # Why 16G: tmpfs is RAM+swap backed and only uses what it HOLDS (size is a cap,
  # not a reservation). 4G was empirically too small once KDE Plasma 6 + Windsurf
  # + VR + Spotify held session-scoped deleted-but-open files in /tmp, which
  # cascaded into logrotate.service failure, home-manager profile activation
  # dangling, and nix repl OOM. 16G gives headroom without meaningful RAM cost.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "mode=755" "size=16G" ];
  };

  # /tmp on its own tmpfs so a /tmp spike can never starve /var/lib, /root, /run,
  # or the home-manager profile path. `boot.tmp.cleanOnBoot = true` (base.nix)
  # still wipes this on reboot. `nosuid,nodev` is defense-in-depth.
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=1777" "size=50%" "nosuid" "nodev" "strictatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
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

  # Daily profile: persistent daily home on its own Btrfs subvolume
  fileSystems."/home/player" = lib.mkIf isDaily {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    neededForBoot = true; # Required because the profile expects /home/player during booted operation
    options = [ "subvol=@home-daily" "compress=zstd" "noatime" ];
  };

  # Swap subvolume — must be created during install as @swap with nocow.
  # See docs/pipeline/INSTALL-GUIDE.md Phase 1.
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

  # Per-install hardware quirks (external drives, etc.) live in the gitignored
  # hosts/nixos/local.nix. See hosts/nixos/default.nix for the conditional import.

  # Harden /persist: restrict to root-only traversal.
  # Impermanence bind mounts are set up by root during activation and do not
  # require unprivileged access to the backing store.  Without this, any user
  # can browse /persist and read world-readable files (NM connection names,
  # systemd state, Bluetooth pairing dirs, Mullvad state, etc.).
  systemd.tmpfiles.rules = [
    "z /persist 0700 root root - -"
    "z /persist/secrets 0700 root root - -"
  ] ++ lib.optionals isParanoid [
    # Defense-in-depth: lock ghost's impermanence backing store even though
    # /persist itself is already 0700.
    "z /persist/home/ghost 0700 ghost users - -"
  ];

  systemd.services.profile-mount-invariants = {
    description = "Assert profile-specific mount isolation invariants";
    wantedBy = [ "multi-user.target" ];
    before = [ "multi-user.target" ];
    after = [ "local-fs.target" "home-player.mount" "home-ghost.mount" "persist-home-ghost.mount" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = if isDaily then ''
      set -eu
      mountpoint -q /home/player
      ! mountpoint -q /home/ghost
      ! mountpoint -q /persist/home/ghost
    '' else ''
      set -eu
      mountpoint -q /home/ghost
      mountpoint -q /persist/home/ghost
      ! mountpoint -q /home/player
    '';
  };

}
