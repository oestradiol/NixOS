{ pkgs, ... }: {
  imports = [ ./common.nix ];

  home.username = "player";
  home.homeDirectory = "/home/player";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
  };

  home.packages = with pkgs; [
    eza
    bat
    mullvad-vpn
    kdePackages.kate
    # Flatpak packages (installed via system.services.flatpak, not home.packages)
    # These are listed here for reference; actual installation via flatpak command
    # spotify → com.spotify.Client
    # bitwarden-desktop → com.bitwarden.desktop
    # vesktop → dev.vencord.Vesktop
    # obsidian → md.obsidian.Obsidian
    # Bubblewrapped apps (not available on Flathub)
    # vrcx and windsurf are pulled in as dependencies of the wrappers
  ];
}
