{ config, pkgs, lib, ... }: {
  home.stateVersion = "26.05";

  imports = [
    ./shell.nix
  ];

  gtk = {
    gtk2.force = true;
    gtk4.theme = null;
  };

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
      fetch.prune = true;
      core.sshCommand = "ssh -o IdentitiesOnly=yes";
    };
  };

  home.packages = with pkgs; lib.optionals (config ? osConfig && config.osConfig.myOS.desktopEnvironment == "plasma") [
    kdePackages.kate  # KDE text editor
  ];
}
