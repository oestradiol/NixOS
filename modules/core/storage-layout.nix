{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.storage;
  persistRoot = config.myOS.persistence.root;

  enabledUsers = lib.filterAttrs (_: u: u.enable) config.myOS.users;
  activeUsers = lib.filterAttrs (_: u: u._activeOn) enabledUsers;
  inactiveUsers = lib.filterAttrs (_: u: !u._activeOn) enabledUsers;

  persistentHomeMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "/home/${name}" {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      neededForBoot = true;
      options = [ "subvol=${u.home.btrfsSubvol}" "compress=zstd" "noatime" ];
    }
  ) (lib.filterAttrs (_: u: u.home.persistent) activeUsers);

  tmpfsHomeMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "/home/${name}" {
      device = "none";
      fsType = "tmpfs";
      neededForBoot = true;
      options = [
        "defaults"
        "size=${cfg.homeTmpfs.size}"
        "mode=700"
        "uid=${toString (if u.uid != null then u.uid else config.users.users.${name}.uid)}"
        "gid=${toString config.users.groups.users.gid}"
      ];
    }
  ) (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);

  tmpfsBackingMounts = lib.mapAttrs' (name: u:
    lib.nameValuePair "${persistRoot}/home/${name}" {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      neededForBoot = true;
      options = [ "subvol=${u.home.btrfsSubvol}" "compress=zstd" "noatime" ];
    }
  ) (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);

  tmpfsUserNames = lib.attrNames (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);
  backingStoreRules = map (name:
    "z ${persistRoot}/home/${name} 0700 ${name} users - -"
  ) tmpfsUserNames;

  activeHomeNames = lib.attrNames activeUsers;
  inactiveHomeNames = lib.attrNames inactiveUsers;
  activeTmpfsNames = lib.attrNames (lib.filterAttrs (_: u: !u.home.persistent) activeUsers);
  inactiveTmpfsNames = lib.attrNames (lib.filterAttrs (_: u: !u.home.persistent) inactiveUsers);

  expectedPresent = map (name: "mountpoint -q /home/${name} || exit 1") activeHomeNames;
  expectedAbsent = map (name: "! mountpoint -q /home/${name} || exit 1") inactiveHomeNames;
  expectedBacking = map (name: "mountpoint -q ${persistRoot}/home/${name} || exit 1") activeTmpfsNames;
  expectedBackingAbsent = map (name: "! mountpoint -q ${persistRoot}/home/${name} || exit 1") inactiveTmpfsNames;
in {
  options.myOS.storage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Framework-managed storage layout: initrd LUKS root, tmpfs root,
        Btrfs-backed persistent mounts, dynamic home mounts, and the
        profile-mount invariant service.
      '';
    };

    devices = {
      boot = lib.mkOption {
        type = lib.types.str;
        default = "/dev/disk/by-label/NIXBOOT";
        description = "Boot/EFI filesystem device.";
      };
      cryptroot = lib.mkOption {
        type = lib.types.str;
        default = "/dev/disk/by-partlabel/NIXCRYPT";
        description = "Underlying encrypted root partition opened as `cryptroot`.";
      };
    };

    subvolumes = {
      nix = lib.mkOption {
        type = lib.types.str;
        default = "@nix";
        description = "Btrfs subvolume mounted at /nix.";
      };
      persist = lib.mkOption {
        type = lib.types.str;
        default = "@persist";
        description = "Btrfs subvolume mounted at the impermanence root.";
      };
      log = lib.mkOption {
        type = lib.types.str;
        default = "@log";
        description = "Btrfs subvolume mounted at /var/log.";
      };
      swap = lib.mkOption {
        type = lib.types.str;
        default = "@swap";
        description = "Btrfs subvolume mounted at /swap when disk-backed swap is enabled.";
      };
    };

    rootTmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Mount / as tmpfs.";
      };
      size = lib.mkOption {
        type = lib.types.str;
        default = "16G";
        description = "Size cap for the tmpfs root filesystem.";
      };
    };

    tmpTmpfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Mount /tmp as a dedicated tmpfs.";
      };
      size = lib.mkOption {
        type = lib.types.str;
        default = "50%";
        description = "Size cap for the dedicated /tmp tmpfs.";
      };
      options = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "nosuid" "nodev" "strictatime" ];
        description = "Additional mount options for the dedicated /tmp tmpfs.";
      };
    };

    homeTmpfs.size = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Size cap for tmpfs-backed per-user homes.";
    };

    swap = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable a disk-backed swap subvolume and swapfile.";
      };
      sizeMiB = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "Swapfile size in MiB when disk-backed swap is enabled.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.initrd.systemd.enable = true;
      boot.initrd.luks.devices.cryptroot = {
        device = cfg.devices.cryptroot;
      };

      fileSystems."/boot" = {
        device = cfg.devices.boot;
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };
      fileSystems."/nix" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=${cfg.subvolumes.nix}" "compress=zstd" "noatime" ];
      };
      fileSystems.${persistRoot} = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=${cfg.subvolumes.persist}" "compress=zstd" "noatime" ];
      };
      fileSystems."/var/log" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        neededForBoot = true;
        options = [ "subvol=${cfg.subvolumes.log}" "compress=zstd" "noatime" ];
      };

      systemd.tmpfiles.rules = [
        "z ${persistRoot} 0700 root root - -"
        "z ${persistRoot}/secrets 0700 root root - -"
      ] ++ backingStoreRules;

      systemd.services.profile-mount-invariants = {
        description = "Assert profile-specific mount isolation invariants";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
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
          ${lib.concatStringsSep "\n" expectedBackingAbsent}
        '';
      };
    }

    (lib.mkIf cfg.rootTmpfs.enable {
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
        options = [ "mode=755" "size=${cfg.rootTmpfs.size}" ];
      };
    })

    (lib.mkIf cfg.tmpTmpfs.enable {
      fileSystems."/tmp" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=1777" "size=${cfg.tmpTmpfs.size}" ] ++ cfg.tmpTmpfs.options;
      };
    })

    (lib.mkIf cfg.swap.enable {
      fileSystems."/swap" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=${cfg.subvolumes.swap}" "noatime" ];
      };
      swapDevices = [{
        device = "/swap/swapfile";
        size = cfg.swap.sizeMiB;
      }];
    })

    { fileSystems = persistentHomeMounts; }
    { fileSystems = tmpfsHomeMounts; }
    { fileSystems = tmpfsBackingMounts; }
  ]);
}
