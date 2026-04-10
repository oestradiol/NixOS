{ config, lib, pkgs, ... }:
let
  vpnIfaces = [ "wg-mullvad" "tun0" "tun1" ];
in {
  networking.networkmanager.enable = true;
  networking.firewall.enable = !config.myOS.security.mullvad.lockdown;
  networking.firewall.allowedUDPPorts = lib.optionals (config.myOS.profile == "daily") [ 7 ];

  networking.interfaces = lib.mkIf (config.myOS.profile == "daily") {
    enp5s0.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };

  services.resolved.enable = lib.mkDefault config.myOS.security.mullvad.enable;
  services.mullvad-vpn.enable = lib.mkDefault config.myOS.security.mullvad.enable;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;

  # Lockdown killswitch — supplementary baseline behind Mullvad's own firewall.
  # After install, also run: mullvad lockdown-mode set on
  # Then validate with: sudo nft list ruleset && mullvad status
  # If Mullvad's built-in always-require-VPN works correctly, these rules
  # serve as defense-in-depth. Adjust interface names after live testing.
  networking.nftables = lib.mkIf config.myOS.security.mullvad.lockdown {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          iif lo accept
          ct state established,related accept
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
          udp dport 68 accept
          udp dport 546 accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy drop;
          oif lo accept
          ct state established,related accept
          udp dport { 67, 547 } accept
          ip daddr 127.0.0.53 tcp dport 53 accept
          ip daddr 127.0.0.53 udp dport 53 accept
          oifname { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } accept
          udp dport 51820 accept
          tcp dport { 443, 1401 } accept
        }
      }
    '';
  };
}
