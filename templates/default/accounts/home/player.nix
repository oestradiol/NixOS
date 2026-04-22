{ config, osConfig, pkgs, lib, inputs, ... }:
let
  # Git identity is read from the framework's per-user identity options.
  userCfg = osConfig.myOS.users.${config.home.username} or { };
  gitName  = userCfg.identity.git.name  or null;
  gitEmail = userCfg.identity.git.email or null;
in {
  imports = [ inputs.hardening.nixosModules.home-common ];

  home.username = "player";
  home.homeDirectory = "/home/player";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
  };

  # Only configure git user.* when the framework identity is populated;
  # otherwise leave the fields unset so forkers start from a clean slate.
  programs.git.settings = lib.mkMerge [
    (lib.mkIf (gitName  != null) { user.name  = gitName; })
    (lib.mkIf (gitEmail != null) { user.email = gitEmail; })
  ];

  home.packages = with pkgs; [
    eza
    bat
    mullvad-vpn
    # Flatpak packages (installed via system.services.flatpak, not home.packages)
    # These are listed here for reference; actual installation via flatpak command
    # spotify → com.spotify.Client
    # bitwarden-desktop → com.bitwarden.desktop
    # vesktop → dev.vencord.Vesktop
    # obsidian → md.obsidian.Obsidian
    # Bubblewrapped apps (not available on Flathub)
    # vrcx and windsurf are pulled in as dependencies of the wrappers
    windsurf
    vrcx
  ];
}
