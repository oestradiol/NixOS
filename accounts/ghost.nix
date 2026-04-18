# Reference account: ghost — the hardened workspace persona.
#
# Pure data: declares the user's identity shape via the two-axis
# framework (modules/core/users-framework.nix). The system side
# (Unix account, profile locking, home-manager binding) is wired by
# modules/core/users.nix reading this attrset.
#
# Forkers: copy this file and tweak it. Operator identity (git
# name/email, mic alias, workspace path) lives in a gitignored
# accounts/ghost.local.nix added in Stage 5.
{ pkgs, lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./ghost.local.nix) ./ghost.local.nix;

  myOS.users.ghost = {
    activeOnProfiles = [ "paranoid" ];
    description = "Hardened workspace";
    uid = 1001;  # explicit for fs-layout tmpfs uid= / gid= mount options
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
    ];
    allowWheel = false;
    home = {
      persistent = false;
      # Backing subvolume uses the legacy name to match the on-disk
      # layout from before the refactor. Fresh installs may prefer
      # the default `@home-ghost`.
      btrfsSubvol = "@home-paranoid";
      allowlist = [
        "Downloads"
        "Documents"
        ".config/Signal"
        ".config/keepassxc"
        ".local/share/KeePassXC"   # KeePassXC database storage
        ".local/share/keyrings"     # Password/key storage
        ".local/share/applications" # Custom desktop entries
        ".gnupg"
        ".ssh"
        ".local/share/flatpak"
        ".var/app/org.signal.Signal"
        ".mozilla/safe-firefox"
      ];
    };
    homeManagerConfig = ../modules/home/ghost.nix;
  };
}
