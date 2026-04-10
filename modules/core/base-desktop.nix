{ config, pkgs, lib, ... }:
{
  # ── Desktop environment ────────────────────────────────────────
  console.keyMap = "br-abnt2";
  services.xserver.xkb.layout = "br";
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.desktopManager.plasma6.enable = true;

  security.polkit.enable = true;
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

  # ── Nix settings (was nix.nix) ────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "player" ];
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

  # Swap file on Btrfs @swap subvolume — fallback behind zram for VR/gaming memory spikes
  swapDevices = [{
    device = "/swap/swapfile";
    size = 8192;
  }];
}
