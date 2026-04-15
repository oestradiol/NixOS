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
    spotify
    bitwarden-desktop
    vesktop
    vscode
    firefox
    vrcx
    obsidian
    signal-desktop
    windsurf
    keepassxc
    telegram-desktop
    element-desktop
    discord
  ];
}
