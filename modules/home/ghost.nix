{ pkgs, ... }: {
  imports = [ ./common.nix ];

  home.username = "ghost";
  home.homeDirectory = "/home/ghost";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
    desktop = "/home/ghost/Desktop";
    documents = "/home/ghost/Documents";
    download = "/home/ghost/Downloads";
    music = "/home/ghost/Music";
    pictures = "/home/ghost/Pictures";
    videos = "/home/ghost/Videos";
    publicShare = "/home/ghost/Public";
    templates = "/home/ghost/Templates";
  };

  home.packages = with pkgs; [
    eza
    bat
    keepassxc
    # Signal Desktop uses Flatpak (org.signal.Signal)
    # Browsers are system-wide sandboxed wrappers: safe-firefox, safe-tor-browser, safe-mullvad-browser
  ];
}
