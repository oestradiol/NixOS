{ config, pkgs, lib, ... }:
{
  imports = [
    ../desktop/theme.nix
    ../desktop/greeter.nix
    ../desktop/plasma.nix
    ../desktop/hyprland.nix
    # i18n layer (BR locale/keymap + JP fcitx5/mozc). Each subsystem
    # self-gates on its myOS.i18n.<layer>.enable knob.
    ../desktop/i18n.nix
    # Daily flake-update + rebuild-boot timer. Self-gated on
    # myOS.autoUpdate.enable (default true).
    ../desktop/auto-update.nix
    # Gaming stack (Steam, gamescope, gamemode, NT sync). Self-gated on
    # myOS.gaming.enable (default false; daily profile sets true).
    ../desktop/gaming.nix
    # Controller support is self-gated on myOS.gaming.controllers.enable
    # (default false). Imported unconditionally so the option is visible
    # on every profile (paranoid sets it explicitly to false).
    ../desktop/controllers.nix
    # VR is gated on myOS.gaming.vr.enable (default follows
    # myOS.gaming.enable). Imported unconditionally so myOS.vr.* options
    # are visible on every profile (governance assertions reference them).
    ../desktop/vr.nix
  ];

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

  # ── Locale / keyboard / input method ───────────────────────────
  # Moved to modules/desktop/i18n.nix (myOS.i18n.{brazilian,japanese}.*).
  # Default locale wiring reads from myOS.host.defaultLocale.

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
  # ── Automatic system updates ────────────────────────────────────
  # Moved to modules/desktop/auto-update.nix (myOS.autoUpdate.*).

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
