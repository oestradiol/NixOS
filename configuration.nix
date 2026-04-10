# Host-level configuration — imports all modules and sets user-facing options.
{ config, lib, pkgs, ... }: {
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
  imports = [
    ./hardware-configuration.nix
    ./modules/core/boot.nix
    ./modules/core/i18n.nix
    ./modules/core/nix.nix
    ./modules/core/users.nix
    ./modules/gpu
    ./modules/audio.nix
    ./modules/gaming.nix
    ./modules/theme.nix
  ];

  # System identity & Time
  networking.hostName = "nixos";
  time.timeZone = "America/Sao_Paulo";

  # Keymap
  console.keyMap = "br-abnt2";
  services.xserver.xkb = {
    layout = "br";
    variant = "";
  };

  # Hardware selection
  myOS.gpu = "nvidia";  # "nvidia" or "amd"

  # Swap
  boot.kernel.sysctl."vm.swappiness" = 30;
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 6144;
    }
  ];

  # Auto-mount drives
  services.udisks2.enable = true;

  # Avoid journalctl too big
  services.journald.extraConfig = ''
    RuntimeMaxUse=250M
    SystemMaxUse=250M
    SystemKeepFree=1G
  '';

  # EarlyOOM — prevent system hang under memory pressure
  services.earlyoom = {
    enable = true;
    # Kill when free memory drops below 400MB or swap below 300MB
    extraArgs = [ "-M" "409600,307200" "-S" "409600,307200" ];
  };

  # Privilege escalation 
  security.polkit.enable = true; # For prompts in KDE
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Networking
  networking.networkmanager.enable = true;
  #networking.wireless.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedUDPPorts = [ 7 ]; # 7 == WakeOnLAN
  networking.interfaces.enp5s0.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };
  services.openssh.enable = false;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Programs & packages
  programs = {
    zsh.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    gdb
    comma
  ];
}
