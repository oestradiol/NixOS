{ pkgs, ... }: {
  home.stateVersion = "26.05";

  imports = [
    ../desktop/shell.nix
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
}
