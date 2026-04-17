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

      # ── nixos-rebuild family ──────────────────────────────────────
      # Rationale: the system ships two configurations (paranoid toplevel +
      # daily specialisation). A single `nixos-rebuild switch` without
      # `--specialisation` ALWAYS targets the toplevel. Running it from a
      # booted daily session therefore silently swaps the live config to
      # paranoid, which tries to stop home-player.mount while player is
      # logged in and trips profile-mount-invariants. These aliases make
      # the choice explicit (see switch.log + tests/bugs/020).
      #
      # IMPORTANT: For daily, use --specialisation daily to activate the daily specialisation.
      # This avoids PAM breakage by ensuring the correct profile is activated.
      #
      # Debug phase: --show-trace on every alias so failures are actionable.
      flake-switch-daily    = "sudo nixos-rebuild switch --flake .#nixos --specialisation daily --show-trace";
      flake-switch-paranoid = "sudo nixos-rebuild switch --flake .#nixos --show-trace";
      # Smart default: pick the specialisation that is currently booted.
      # Check profile specialisation symlink since /run/current-system/specialisation/daily is not created by NixOS
      flake-switch = "if [ -e /nix/var/nix/profiles/system/specialisation/daily ]; then flake-switch-daily; else flake-switch-paranoid; fi";

      # `test` applies the new configuration WITHOUT creating a boot entry.
      # Use this for iterative work during the debug/test phase.
      flake-test-daily    = "sudo nixos-rebuild test --flake .#nixos --specialisation daily --show-trace";
      flake-test-paranoid = "sudo nixos-rebuild test --flake .#nixos --show-trace";
      flake-test = "if [ -e /nix/var/nix/profiles/system/specialisation/daily ]; then flake-test-daily; else flake-test-paranoid; fi";

      # `dry-activate` evaluates + builds, shows what WOULD happen, applies nothing.
      flake-dry  = "nixos-rebuild dry-activate --flake .#nixos --show-trace";

      # `boot` stages the new generation for the NEXT boot only — does not activate.
      # Useful when swapping profile (paranoid <-> daily) so the profile-mount
      # invariants fire cleanly on a fresh boot with no one logged in.
      # Note: boot already builds all specialisations, no --specialisation flag needed.
      flake-boot    = "sudo nixos-rebuild boot --flake .#nixos --show-trace";

      # Panic button: re-apply the currently-booted generation. Restores the
      # live system to whatever was activated at boot time (undoes a bad `test`
      # or `switch`). Does not touch /boot.
      flake-rollback = "sudo /run/current-system/bin/switch-to-configuration switch";

      flake-update = "sudo nix flake update --flake .";
      nix-update   = "flake-update && flake-switch";

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
