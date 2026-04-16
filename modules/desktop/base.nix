{ config, pkgs, lib, ... }:
{
  imports = [
    ../desktop/theme.nix
  ];

  # ── Desktop environment ────────────────────────────────────────
  console.keyMap = "br-abnt2";
  services.xserver.enable = false;
  # Wayland-native keyboard layout via XKB_DEFAULT_* (respected by cage and Plasma 6 Wayland)
  environment.sessionVariables = {
    XKB_DEFAULT_LAYOUT = "br";
  };
  services.desktopManager.plasma6.enable = true;
  programs.regreet.enable = true;  # Wayland-native greeter (greetd + cage + regreet)

  security.polkit.enable = true;
  # services.dbus.implementation = "broker";
  # ^ deliberately disabled 2026-04 after it caused a boot-time hang on a D-Bus
  # message (failed to reach Plasma/greetd's bus before the login screen).
  # Do NOT re-enable without first validating that greetd, regreet, plasma6,
  # xdg-portal, pipewire, and the bwrap wrappers all come up cleanly on the
  # target hardware with dbus-broker. See docs/pipeline/POST-STABILITY.md §8.
  services.udisks2.enable = true;
  services.printing.enable = false;
  services.openssh.enable = false;
  services.fwupd.enable = true;

  # Plasma 6 (and xdg.portal's location backend) auto-enables geoclue2 via
  # mkDefault. geoclue queries Wi-Fi BSSIDs against the Mozilla Location
  # Service — an identity beacon that none of our declared features use.
  # Disable explicitly (mkForce) and document: re-enable via lib.mkOverride
  # 40 or a dedicated myOS.desktop.geolocation knob if redshift/gammastep
  # with automatic location ever becomes a requirement.
  services.geoclue2.enable = lib.mkForce false;

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

  # ── Nix settings (was nix.nix) ────────────────────────────────
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

  # Disable drkonqi coredump processor - coredumps are already disabled via systemd.coredump.extraConfig
  # in modules/security/base.nix (Storage=none, ProcessSizeMax=0). The drkonqi service
  # tries to process stale journal entries from before that config was applied and times out.
  systemd.user.services.drkonqi-coredump-pickup.enable = false;
  systemd.user.services.drkonqi-coredump-launcher.enable = false;

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
