{ config, lib, pkgs, ... }:
let
  vpnIfaces = [ "wg-mullvad" "tun0" "tun1" ];
in {
  networking.networkmanager.enable = true;
  networking.firewall.enable = !config.myOS.security.mullvad.nftablesFallback;
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

  # WARNING: This is a best-effort local fallback policy, not a reimplementation
  # of Mullvad's firewall state machine. It must be live-validated per machine.
  #
  # Purpose: Boot-gap fallback to reduce accidental leaks before/around daemon startup.
  # Primary enforcement: Mullvad's built-in lockdown-mode killswitch.
  #
  # DESIGN: Minimal pre-tunnel bootstrap only; not assumed correct across changes.
  # - Bootstrap (non-VPN interfaces only): minimal DHCP/NDP for tunnel establishment
  # - VPN interfaces: unrestricted egress when tunnel is up
  # - Mullvad daemon handles its own bootstrap securely; we don't curate their IPs.
  #
  # Known limitations (documented tradeoff):
  # - Bootstrap DNS: Brief clearnet DNS queries at boot before VPN tunnel is established.
  #   Unavoidable: must resolve VPN endpoint hostname. Mullvad daemon handles this.
  # - Interface names are hand-maintained and must match actual tunnel names.
  # - Static rules cannot model Mullvad's stateful behavior (connecting/connected/lockdown).
  #
  # RECOMMENDATION: Rely primarily on Mullvad's built-in lockdown-mode killswitch.
  # These nftables rules are a narrow fallback, not authoritative enforcement.
  networking.nftables = lib.mkIf config.myOS.security.mullvad.nftablesFallback {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          iif lo accept
          ct state established,related accept
          # Inbound ICMP blocked (no response to pings)
          # Bootstrap traffic allowed (DHCP client responses)
          udp dport { 68, 546 } accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy drop;
          oif lo accept
          ct state established,related accept
          # Bootstrap traffic: DHCP and NDP only on non-VPN interfaces
          oifname != { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } udp dport { 67, 547 } accept
          oifname != { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } ip6 nexthdr udp udp dport { 547, 546 } accept
          # DNS to systemd-resolved (local stub only, not a DNS-security guarantee)
          ip daddr 127.0.0.53 udp dport 53 accept
          ip daddr 127.0.0.53 tcp dport 53 accept
          # IPv4 ICMP: PMTU-relevant types only
          ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
          # IPv6 NDP: router/neighbor discovery only (Mullvad-allowed subset)
          # Types: 133 (rs), 134 (ra), 135 (ns), 136 (na)
          oifname != { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } ip6 nexthdr icmpv6 icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          # VPN interfaces: unrestricted egress when tunnel is up
          oifname { ${lib.concatStringsSep ", " (map (n: "\"${n}\"") vpnIfaces)} } accept
        }
      }
    '';
  };
}
