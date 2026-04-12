{ config, lib, pkgs, ... }:
let
  paranoid = config.myOS.profile == "paranoid";
  daily = config.myOS.profile == "daily";
in {
  config = lib.mkMerge [
    # === PARANOID: Comprehensive anti-fingerprinting ===
    (lib.mkIf paranoid {
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
        "net.ipv6.conf.all.use_tempaddr" = 2;  # Prefer temporary addresses
        "net.ipv6.conf.default.use_tempaddr" = 2;
        "net.ipv4.tcp_timestamps" = 0;  # Disable TCP timestamps
      };

      # 7. Hostname randomization option (disabled by default - breaks local network identification)
      # Can be enabled manually: networking.hostName = lib.mkForce "anon-${builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName)}";
    })

    # === DAILY: Relaxed fingerprinting protection ===
    (lib.mkIf daily {
      # Machine-id: systemd-generated unique stable ID, persisted via impermanence.
      
      # MAC: Stable per-network (default NetworkManager behavior)
      # WiFi uses stable cloned MAC per network (privacy without breaking WiFi)
      networking.networkmanager.wifi.macAddress = "stable";
      networking.networkmanager.wifi.scanRandMacAddress = true;  # Still randomize scan
      
      # IPv6 privacy extensions enabled (standard privacy)
      # TCP timestamps enabled (needed for some gaming/networking)
      boot.kernel.sysctl = {
        "net.ipv6.conf.all.use_tempaddr" = 2;
        "net.ipv6.conf.default.use_tempaddr" = 2;
        "net.ipv4.tcp_timestamps" = 1;
      };
    })
  ];
}
