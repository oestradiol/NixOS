{ pkgs, ... }: {
  imports = [ hardening.home-common ];

  home.username = "ghost";
  home.homeDirectory = "/home/ghost";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
  };

  home.packages = with pkgs; [
    eza
    bat
    keepassxc
    # Signal Desktop uses Flatpak (org.signal.Signal)
    # Browsers are system-wide sandboxed wrappers: safe-firefox, safe-tor-browser, safe-mullvad-browser
  ];
}
