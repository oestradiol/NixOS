{ lib, config, pkgs, ... }:
let
  cfg = config.myOS;
  isParanoid = cfg.profile == "paranoid";
  isDaily = cfg.profile == "daily";

  # Users active on current profile (framework-driven)
  enabledUsers = lib.filterAttrs (_: u: u.enable) cfg.users;
  activeUsers = lib.filterAttrs (_: u: u._activeOn) enabledUsers;

  # Persistent home mounts: Btrfs subvolume directly at /home/<name>
  persistentHomeMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "/home/${name}" {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      neededForBoot = true;
      options = [ "subvol=${u.home.btrfsSubvol}" "compress=zstd" "noatime" ];
    }
  ) (lib.filterAttrs (_: u: u.home.persistent) activeUsers);

  # Tmpfs home mounts: tmpfs at /home/<name>
  tmpfsHomeMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "/home/${name}" {
      device = "none";
      fsType = "tmpfs";
      neededForBoot = true;
      options = [
        "defaults"
        "size=2G"
        "mode=700"
        "uid=${toString (if u.uid != null then u.uid else config.users.users.${name}.uid)}"
        "gid=${toString config.users.groups.users.gid}"
      ];
    }
  ) (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);

  # Tmpfs backing store mounts: Btrfs subvolume at /persist/home/<name>
  tmpfsBackingMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "/persist/home/${name}" {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      neededForBoot = true;
      options = [ "subvol=${u.home.btrfsSubvol}" "compress=zstd" "noatime" ];
    }
  ) (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);

  # tmpfiles rules for backing store permissions
  tmpfsUserNames = lib.attrNames (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);
  backingStoreRules = map (name:
    "z /persist/home/${name} 0700 ${name} users - -"
  ) tmpfsUserNames;

  # Mount invariants service: assert expected mounts present/absent
  activeHomeNames = lib.attrNames activeUsers;
  allUserNames = lib.attrNames enabledUsers;
  inactiveHomeNames = lib.subtractLists activeHomeNames allUserNames;
  activeTmpfsNames = lib.attrNames (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);

  expectedPresent = map (n: "mountpoint -q /home/${n} || exit 1") activeHomeNames;
  expectedAbsent = map (n: "! mountpoint -q /home/${n} || exit 1") inactiveHomeNames;
  expectedBacking = map (n: "mountpoint -q /persist/home/${n} || exit 1") activeTmpfsNames;
in
{
  # Use config = lib.mkMerge so we can mix static top-level fileSystems.<path>
  # declarations (grep-visible for tests) with dynamically generated ones
  # derived from myOS.users.
  config = lib.mkMerge [
    {
      boot.initrd.systemd.enable = true;
      boot.initrd.luks.devices.cryptroot = {
        device = "/dev/disk/by-partlabel/NIXCRYPT";
        # Note: allowDiscards disabled; using periodic fstrim instead (safer, no info-leak risk)
      };

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

      # Harden /persist: restrict to root-only traversal.
      # Impermanence bind mounts are set up by root during activation and do not
      # require unprivileged access to the backing store.
      systemd.tmpfiles.rules = [
        "z /persist 0700 root root - -"
        "z /persist/secrets 0700 root root - -"
      ] ++ backingStoreRules;

      systemd.services.profile-mount-invariants = {
        description = "Assert profile-specific mount isolation invariants";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        after = [ "local-fs.target" ]
          ++ map (n: "home-${n}.mount") activeHomeNames
          ++ map (n: "persist-home-${n}.mount") activeTmpfsNames;
        path = [ pkgs.util-linux ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -eu
          ${lib.concatStringsSep "\n" expectedPresent}
          ${lib.concatStringsSep "\n" expectedAbsent}
          ${lib.concatStringsSep "\n" expectedBacking}
        '';
      };
    }
    # Dynamically generated per-user mounts (framework-driven from myOS.users).
    # Paranoid profile: /home/ghost is tmpfs backed by @home-paranoid at /persist/home/ghost.
    # Daily profile: /home/player is a persistent Btrfs subvol (@home-daily).
    { fileSystems = persistentHomeMounts; }
    { fileSystems = tmpfsHomeMounts; }
    { fileSystems = tmpfsBackingMounts; }
  ];
}
