{ config, pkgs, ... }: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    defaultKeymap = "emacs";

    history = {
      size = 10000;
      save = 10000;
      share = true;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    shellAliases = {
      echo_mic = "pactl load-module module-loopback latency_msec=200 source=alsa_input.usb-3142_Fifine_Microphone-00.mono-fallback sink=alsa_output.pci-0000_09_00.4.analog-stereo";
      #rustdesk = "sudo cp /run/sddm/$(sudo ls /run/sddm) ~/.Xauthority && XAUTHORITY=/home/ruby/.Xauthority DISPLAY=:0 sudo -S rustdesk";
      flake-switch = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      flake-update = "sudo nix flake update --flake /etc/nixos";
      nix-update = "flake-update && flake-switch";
      ls = "eza";
      cat = "bat";
      neofetch = "hyfetch";
    };

    sessionVariables = {
      DEFAULT_USER = "ruby";
    };

    initContent = ''
      # starship prompt
      eval "$(starship init zsh)"

      clear
      hyfetch
    '';
  };

  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.packages = with pkgs; [
    hyfetch
    tig
  ];
}
