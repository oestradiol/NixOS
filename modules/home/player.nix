{ pkgs, ... }: {
  imports = [ ./common.nix ];

  home.username = "player";
  home.homeDirectory = "/home/player";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
    desktop = "/home/player/Data/Desktop";
    documents = "/home/player/Data/Documents";
    download = "/home/player/Data/Downloads";
    music = "/home/player/Data/Music";
    pictures = "/home/player/Data/Pictures";
    videos = "/home/player/Data/Videos";
    publicShare = "/home/player/Data/Public";
    templates = "/home/player/Data/Templates";
  };

  home.packages = with pkgs; [
    eza
    bat
    firefox
    kdePackages.kate
    # Flatpak packages (installed via system.services.flatpak, not home.packages)
    # These are listed here for reference; actual installation via flatpak command
    # spotify → com.spotify.Client
    # bitwarden-desktop → com.bitwarden.desktop
    # vesktop → dev.vencord.Vesktop
    # obsidian → md.obsidian.Obsidian
    # telegram-desktop → org.telegram.desktop
    # element-desktop → im.riot.Riot
    # Bubblewrap-wrapped apps (not available on Flathub)
    # vrcx and windsurf are pulled in as dependencies of the wrappers
  ];
}
