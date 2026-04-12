{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.security.wireguardMullvad;

  # Self-owned WireGuard stack for paranoid profile
  # Provider: Mullvad (servers only)
  # Control plane: NixOS (interface, routes, firewall, config)
  #
  # Architecture principle: single source of truth
  # - WireGuard config (interface, peer, endpoint, allowed IPs) defined here
  # - Firewall rules generated from the same config attributes
  # - No Mullvad app daemon - NixOS owns all tunnel state
  #
  # This removes the split-authority problem where:
  # - Mullvad app owned connection state
  # - Local nftables owned a separate firewall story
  #
  # Now: one authority for tunnel state, one authority for firewall policy.

  # The WireGuard interface name - fixed and known
  wgInterface = "wg-mullvad";

  # Parse endpoint to extract IP/hostname and port for firewall rules
  # Endpoint format: "ip:port" or "hostname:port"
  endpointParts = lib.splitString ":" cfg.endpoint;
  endpointHost = lib.head endpointParts;
  endpointPort = lib.toInt (lib.last endpointParts);

  # Determine if endpoint is an IP address (for direct firewall rule)
  # or hostname (requires DNS resolution before tunnel is up)
  isEndpointIP = let
    ipParts = lib.splitString "." endpointHost;
    firstOctet = lib.toInt (lib.head ipParts);
  in lib.hasInfix "." endpointHost && lib.all (p: lib.isInt (lib.toInt p)) (lib.take 4 ipParts);

  # Build the list of non-WG interfaces for bootstrap exceptions
  # This is dynamic: all interfaces EXCEPT the WG interface
  bootstrapExceptionExpression = "oifname != \"${wgInterface}\"";

in {
  config = lib.mkIf cfg.enable {
    # Assert that we have the minimum required configuration
    assertions = [
      {
        assertion = cfg.privateKey != "";
        message = "myOS.security.wireguardMullvad.privateKey must be set (use agenix or sops)";
      }
      {
        assertion = cfg.endpoint != "";
        message = "myOS.security.wireguardMullvad.endpoint must be set (Mullvad server endpoint)";
      }
      {
        assertion = cfg.address != "";
        message = "myOS.security.wireguardMullvad.address must be set (WireGuard tunnel IP)";
      }
    ];

    # Disable Mullvad app - we own the tunnel ourselves
    services.mullvad-vpn.enable = false;

    # WireGuard interface using NixOS native module
    # This is the single source of truth for tunnel configuration
    networking.wireguard.interfaces.${wgInterface} = {
      inherit (cfg) privateKey;

      # The tunnel IP address assigned by Mullvad
      ips = [ cfg.address ];

      # WireGuard peer configuration
      peers = [{
        # Mullvad server public key
        publicKey = cfg.serverPublicKey;

        # Allowed IPs: route everything through tunnel for killswitch behavior
        # This is the "route all traffic" configuration
        allowedIPs = cfg.allowedIPs;

        # Server endpoint: hostname or IP with port
        endpoint = cfg.endpoint;

        # Keepalive: important for NAT traversal and maintaining connection
        persistentKeepalive = cfg.persistentKeepalive;

        # Preshared key for additional symmetric encryption layer (optional but recommended)
        presharedKey = lib.mkIf (cfg.presharedKey != "") cfg.presharedKey;
      }];

      # Bring interface up at boot
      autostart = true;

      # DNS configuration: use Mullvad's DNS through the tunnel
      # This is critical for leak prevention - DNS must go through tunnel
      dns = lib.mkIf (cfg.dns != "") [ cfg.dns ];
    };

    # Firewall: generated from the same config that defines the tunnel
    # This ensures the firewall always matches the tunnel configuration
    networking.firewall.enable = false;  # We use nftables exclusively

    networking.nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority filter; policy drop;

            # Loopback: always allow
            iif lo accept

            # Established/related: allow return traffic
            ct state established,related accept

            # Drop invalid state packets
            ct state invalid drop

            # WireGuard: accept incoming handshake packets on the endpoint port
            # Only from the specific Mullvad server endpoint when known
            ${if isEndpointIP then ''
              ip saddr ${endpointHost} udp sport ${toString endpointPort} accept
            '' else ''
              # Endpoint is hostname - allow from any (DNS resolution needed)
              # This is slightly broader but necessary for hostname-based configs
              udp sport ${toString endpointPort} accept
            ''}

            # DHCP client responses: required for IP acquisition
            udp dport { 68, 546 } accept

            # ICMP for path MTU discovery (only specific types)
            ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept

            # IPv6 NDP: minimal for local network functionality
            ip6 nexthdr icmpv6 icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept

            # Log and drop everything else (paranoid mode)
            log prefix "nftables-input-drop: " level warn drop
          }

          chain forward {
            type filter hook forward priority filter; policy drop;

            # Allow forwarding through the WireGuard interface
            # This is the killswitch: only traffic through WG is forwarded
            oifname "${wgInterface}" accept
            iifname "${wgInterface}" accept

            # Drop everything else
            log prefix "nftables-forward-drop: " level warn drop
          }

          chain output {
            type filter hook output priority filter; policy drop;

            # Loopback: always allow
            oif lo accept

            # Established/related: allow response traffic
            ct state established,related accept

            # Drop invalid state packets
            ct state invalid drop

            # Bootstrap traffic: DHCP/NDP on non-WG interfaces only
            # This allows the system to get an IP before tunnel is established
            ${bootstrapExceptionExpression} udp dport { 67, 547 } accept
            ${bootstrapExceptionExpression} ip6 nexthdr udp udp dport { 547, 546 } accept

            # NDP on non-WG interfaces (router/neighbor discovery)
            ${bootstrapExceptionExpression} ip6 nexthdr icmpv6 icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept

            # ICMP for path MTU discovery (non-WG interfaces for bootstrap)
            ${bootstrapExceptionExpression} ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept

            # DNS: ONLY through the tunnel interface
            # This prevents DNS leaks - DNS queries must go through WG
            oifname "${wgInterface}" udp dport 53 accept
            oifname "${wgInterface}" tcp dport 53 accept

            # WireGuard handshake: to the endpoint (non-WG interface)
            # This establishes/maintains the tunnel itself
            ${bootstrapExceptionExpression} udp dport ${toString endpointPort} accept

            # ALL other traffic: ONLY through WireGuard interface
            # This is the killswitch: if tunnel is down, no traffic leaves
            oifname "${wgInterface}" accept

            # Log and drop everything else (shows what would leak)
            log prefix "nftables-output-drop: " level warn drop
          }
        }

        # NAT for WireGuard interface (masquerade outgoing traffic)
        table ip nat {
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname "${wgInterface}" masquerade
          }
        }
      '';
    };

    # systemd-resolved configuration for DNS leak prevention
    services.resolved = {
      enable = true;
      # Use the DNS server provided through WireGuard (Mullvad's DNS)
      # This is set via the WireGuard interface dns option above
      fallbackDns = [];  # No fallback - if tunnel DNS fails, queries fail (secure)
    };

    # sysctl settings for WireGuard and security
    boot.kernel.sysctl = {
      # Enable IP forwarding (required for WireGuard routing)
      "net.ipv4.ip_forward" = true;
      "net.ipv6.conf.all.forwarding" = true;

      # Strict reverse path filtering (prevent IP spoofing)
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      # Don't accept redirects (security)
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;

      # Don't send redirects
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
    };

    # Ensure WireGuard interface comes up before networking is considered "online"
    systemd.services."wg-quick-${wgInterface}" = {
      # Ensure this is considered part of network target
      wantedBy = [ "multi-user.target" ];
      # Ensure proper ordering with other services
      after = [ "systemd-resolved.service" "network.target" ];
      wants = [ "systemd-resolved.service" ];
    };
  };
}
