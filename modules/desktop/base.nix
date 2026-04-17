{ config, pkgs, lib, ... }:
{
  imports = [
    ../desktop/theme.nix
    ../desktop/greeter.nix
    ../desktop/plasma.nix
    ../desktop/hyprland.nix
  ];

  # ── Desktop environment ────────────────────────────────────────
  console.keyMap = "br-abnt2";
  # Wayland-native keyboard layout via XKB_DEFAULT_*
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "br";
  };

  services.xserver.enable = lib.mkForce false;

  security.polkit.enable = true;
  # services.dbus.implementation = "broker";
  # ^ deliberately disabled 2026-04 after it caused a boot-time hang on a D-Bus
  # message (failed to reach Plasma/greetd's bus before the login screen).
  # Do NOT re-enable without first validating that the selected desktop environment
  # (plasma/hyprland), greetd/regreet, xdg-portal, pipewire, and the bwrap wrappers
  # all come up cleanly on the target hardware with dbus-broker.
  # See docs/pipeline/POST-STABILITY.md §8.
  services.udisks2.enable = true;
  services.printing.enable = false;
  services.openssh.enable = false;
  services.fwupd.enable = true;


  programs = {
    zsh.enable = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-qt;
    };
    git = {
      enable = true;
      lfs.enable = true;
    };
  };

  # ── Locale (was i18n.nix) ──────────────────────────────────────
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-mozc-ut
        fcitx5-gtk
      ];
      waylandFrontend = true;
    };
  };

  # ── Nix settings ────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" ];
    warn-dirty = false;
    # Prevent "download buffer is full" warnings during large builds (e.g., kernel)
    download-buffer-size = 524288000; # 500MB
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  # ── Automatic system updates ────────────────────────────────────────
  systemd.services.nix-auto-update = {
    description = "Daily automatic Nix flake update and boot entry rebuild";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/bin/sh -c 'cd /home/player/dotfiles && sudo -u player ${pkgs.nix}/bin/nix flake update --flake . && ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake .#nixos'";
      WorkingDirectory = "/home/player/dotfiles";
    };
  };

  systemd.timers.nix-auto-update = {
    description = "Run daily Nix flake update and boot rebuild";
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  # ── Audio (was audio.nix) ─────────────────────────────────────
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  # ── System health ─────────────────────────────────────────────
  services.earlyoom = {
    enable = true;
    extraArgs = [ "-M" "409600,307200" "-S" "409600,307200" ];
  };
  services.journald.extraConfig = ''
    RuntimeMaxUse=250M
    SystemMaxUse=250M
    SystemKeepFree=1G
  '';
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # SSD TRIM: periodic fstrim (safer than real-time discard for LUKS)
  services.fstrim.enable = true;


  # Sleep states (suspend/hibernate) controlled by security option (disabled by default)
  # Rationale: 16GB RAM + 8GB swap insufficient; NVIDIA suspend issues; tmpfs+LUKS complexity
  powerManagement.enable = config.myOS.security.allowSleep;

  # Actually block sleep: mask systemd sleep targets when allowSleep is false.
  # powerManagement.enable alone only controls CPU power-management helpers, not sleep.
  systemd.targets.sleep.enable = config.myOS.security.allowSleep;
  systemd.targets.suspend.enable = config.myOS.security.allowSleep;
  systemd.targets.hibernate.enable = config.myOS.security.allowSleep;
  systemd.targets.hybrid-sleep.enable = config.myOS.security.allowSleep;
}
