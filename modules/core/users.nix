{ pkgs, config, lib, ... }:
let
  lockRoot = config.myOS.security.lockRoot;
in {
  # CRITICAL: mutableUsers MUST be true for first-boot password setup.
  # Users have no initial passwords - they must:
  # 1. Switch to TTY (Ctrl+Alt+F3)
  # 2. Log in as 'player' (no password required with mutableUsers=true)
  # 3. Run 'passwd' to set password
  # 4. Switch back to SDDM (Ctrl+Alt+F1/F7) and log in
  # After passwords are set, you can set mutableUsers=false if desired.
  users.mutableUsers = true;

  users.users.player = {
    isNormalUser = true;
    description = "Daily desktop";
    home = "/home/player";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "realtime"
      "gamemode"
      "libvirtd"
      "kvm"
      "flatpak"
    ];
    # No initial password - user must set via TTY on first boot (see above)
  };

  users.users."ghost" = {
    isNormalUser = true;
    description = "Hardened workspace";
    home = "/home/ghost";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "flatpak"
    ];
    # No initial password - user must set via TTY on first boot (see above)
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
