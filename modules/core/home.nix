{ pkgs, ... }: {
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.
  imports = [
    ../other/zsh.nix
    ../other/starship.nix
  ];

  home.username = "ruby";
  home.homeDirectory = "/home/ruby";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    # New default since 26.05
    setSessionVariables = false;

    desktop = "/home/ruby/Data/Desktop";
    documents = "/home/ruby/Data/Documents";
    download = "/home/ruby/Data/Downloads";
    music = "/home/ruby/Data/Music";
    pictures = "/home/ruby/Data/Pictures";
    videos = "/home/ruby/Data/Videos";
    publicShare = "/home/ruby/Data/Videos";
    templates = "/home/ruby/Data/Templates";
  };

  gtk = {
    # Fix GTK2 config creation
    gtk2.force = true;
    # New default since 26.05
    gtk4.theme = null;
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
  ];
}
