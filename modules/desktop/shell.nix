{ config, pkgs, ... }: {
  # ── Zsh (was other/zsh.nix) ───────────────────────────────────
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
      flake-switch = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      flake-update = "sudo nix flake update --flake /etc/nixos";
      nix-update = "flake-update && flake-switch";
      ls = "eza";
      cat = "bat";
      neofetch = "hyfetch";
    };

    initContent = ''
      # starship prompt
      eval "$(starship init zsh)"

      clear
      hyfetch
    '';
  };

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.packages = with pkgs; [
    hyfetch
    tig
  ];

  # ── Starship prompt (was other/starship.nix) ──────────────────
  programs.starship = {
    enable = true;

    settings = {
      format = "[](bg:none fg:#f38ba8)$username[](bg:#fab387 fg:#f38ba8)$hostname[](bg:#f9e2af fg:#fab387)$directory[](bg:#a6e3a1 fg:#f9e2af)$git_branch[](bg:#74c7ec fg:#a6e3a1)$cmd_duration[](bg:none fg:#74c7ec)$line_break$character";

      add_newline = false;

      character = {
        success_symbol = "[ 󱞪](#a6e3a1 bold)";
        error_symbol = "[ 󱞪](#f38ba8)";
        vicmd_symbol = "[ 󱞪❯](#f9e2af)";
      };

      username = {
        disabled = false;
        show_always = true;
        format = "[ $user ](bg:#f38ba8 fg:#1e1e2e bold)";
      };

      hostname = {
        disabled = false;
        ssh_only = false;
        format = "[ 󰌽 $hostname ]( bg:#fab387 fg:#1e1e2e bold)";
      };

      directory = {
        disabled = false;
        format = "[  $path](bg:#f9e2af fg:#1e1e2e bold)";
        truncation_length = 5;
        truncate_to_repo = false;

        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
          "Videos" = " ";
          "iso" = "󰌽 ";
          ".config" = "";
        };
      };

      git_branch = {
        disabled = false;
        format = "[  $branch](bg:#a6e3a1 fg:#1e1e2e bold)";
      };

      cmd_duration = {
        disabled = false;
        show_milliseconds = false;
        format = "[ 󱑆 $duration](bg:#74c7ec fg:#1e1e2e bold)";
        min_time = 4;
      };
    };
  };
}
