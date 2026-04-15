{ ... }: {
  # Shared install assumptions for the fresh reinstall target.
  # Root is tmpfs. Persisted state lives on Btrfs subvolumes inside LUKS.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "mode=755" "size=4G" ];
  };

  # Swap subvolume — must be created during install as @swap with nocow.
  # See docs/INSTALL-GUIDE.md Phase 1.
  fileSystems."/swap" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@swap" "noatime" ];
  };
}
