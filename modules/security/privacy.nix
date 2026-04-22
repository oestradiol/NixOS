{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.privacy;
  # Posture selection: can be set explicitly or derived from profile
  highPrivacy = cfg.posture == "high";
  relaxedPrivacy = cfg.posture == "relaxed";
in {
  options.myOS.privacy = {
    posture = lib.mkOption {
      type = lib.types.enum [ "high" "relaxed" ];
      default = "relaxed";
      description = ''
        Privacy/fingerprinting posture.
        - high: Comprehensive anti-fingerprinting (MAC randomization, TCP timestamps disabled)
        - relaxed: Standard privacy (stable MAC per network, TCP timestamps enabled)
      '';
    };
  };

  config = lib.mkMerge [
    # === HIGH PRIVACY: Comprehensive anti-fingerprinting ===
    (lib.mkIf highPrivacy {
      # 1. machine-id: persisted, unique host identity handled by impermanence.
      #    Bare-metal host IDs stay locally unique on both profiles.

      # 2. MAC Address Randomization
      # Use systemd.link for persistent randomization across boots
      systemd.network.links."mac-randomize" = {
        matchConfig.Type = "wlan";  # WiFi interfaces
        linkConfig.MACAddressPolicy = "random";
      };
      
      # For ethernet interfaces too
      systemd.network.links."mac-randomize-eth" = {
        matchConfig.Type = "ether";  # Ethernet interfaces
        linkConfig.MACAddressPolicy = "random";
      };

      # 3. NetworkManager WiFi MAC randomization
      networking.networkmanager.wifi.macAddress = "random";
      networking.networkmanager.wifi.scanRandMacAddress = true;
      
      # 4. IPv6 privacy extensions (sysctl method - more reliable)
      # 5. DMI/SMBIOS: Cannot fully hide (kernel needs it), but restrict access
      # The DMI data in /sys/class/dmi/id/ is world-readable by default
      # We can't easily restrict without breaking apps, but we document it as a residual vector
      # 6. Disable TCP timestamps (can be used for clock fingerprinting)
      boot.kernel.sysctl = {
        "net.ipv4.tcp_timestamps" = 0;  # Disable TCP timestamps
      };

      # 7. Hostname randomization option (disabled by default - breaks local network identification)
      # Can be enabled manually: networking.hostName = lib.mkForce "anon-${builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName)}";
    })

    # === RELAXED: Standard fingerprinting protection ===
    (lib.mkIf relaxedPrivacy {
      # Machine-id: systemd-generated unique stable ID, persisted via impermanence.
      
      # MAC: Stable per-network (default NetworkManager behavior)
      # WiFi uses stable cloned MAC per network (privacy without breaking WiFi)
      networking.networkmanager.wifi.macAddress = "stable";
      networking.networkmanager.wifi.scanRandMacAddress = true;  # Still randomize scan
      
      # IPv6 privacy extensions enabled (standard privacy)
      # TCP timestamps enabled (needed for some gaming/networking)
      boot.kernel.sysctl = {
        "net.ipv4.tcp_timestamps" = 1;
      };
    })
  ];
}
