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

  # Lockdown killswitch — interface-based only (no hardcoded IPs).
  # After install, also run: mullvad lockdown-mode set on
  # Then validate with: sudo nft list ruleset && mullvad status
  #
  # DESIGN: Interface-based killswitch removes manual IP maintenance.
  # - Physical interface: only DHCP/DNS/systemd-resolved/ICMP (for tunnel bootstrap)
  # - VPN interfaces (tun*, wg-mullvad): unrestricted egress when tunnel is up
  # - Mullvad daemon handles its own bootstrap securely; we don't curate their IPs.
  #
  # Killswitch exceptions documented (allowed on physical interface):
  # - DHCP (v4: ports 67/547, v6: ports 547/546)
  # - DNS to systemd-resolved (127.0.0.53:53)
  # - Outbound ICMP only (path MTU discovery)

  # Known leakage (documented tradeoff):
  # - Bootstrap DNS: Brief clearnet DNS queries at boot before VPN tunnel is established.
  #   Unavoidable: must resolve VPN endpoint hostname. Mullvad daemon handles this.
  # - Host is "ping dark" (no inbound ICMP replies) but not invisible to other scans.

  #
  # RECOMMENDATION: Rely primarily on Mullvad's built-in lockdown-mode killswitch.
  # These nftables rules are defense-in-depth only.
  networking.nftables = lib.mkIf config.myOS.security.mullvad.lockdown {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          iif lo accept
          ct state established,related accept
          # No inbound ICMP - prevents ping reconnaissance (host "dark" to scans)
          # Outbound ICMP still allowed in output chain for path MTU discovery
          udp dport { 68, 546 } accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy drop;
          oif lo accept
          ct state established,related accept
          # DHCP v4 and v6 (bootstrap to get IP before tunnel)
          udp dport { 67, 547 } accept
          ip6 nexthdr udp udp dport { 547, 546 } accept
          # DNS to systemd-resolved (for Mullvad bootstrap)
          ip daddr 127.0.0.53 udp dport 53 accept
          ip daddr 127.0.0.53 tcp dport 53 accept
          # Outbound ICMP only - path MTU discovery (inbound blocked for stealth)
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
          # VPN interfaces: unrestricted egress when tunnel is up
          oifname { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } accept
        }
      }
    '';
  };
}
