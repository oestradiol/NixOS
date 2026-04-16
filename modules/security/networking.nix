{ config, lib, pkgs, ... }:
let
  isDaily = config.myOS.profile == "daily";

  # VPN architecture:
  # daily/player  → Mullvad app mode (GUI + daemon)
  # paranoid/ghost → self-owned WireGuard path (staged, wireguard.nix)
  useSelfOwnedWireGuard = config.myOS.security.wireguardMullvad.enable;
in {
  networking.networkmanager.enable = true;

  # Firewall: enable NixOS firewall in Mullvad app mode
  # Self-owned WireGuard mode uses its own nftables policy exclusively (wireguard.nix)
  networking.firewall.enable = lib.mkDefault (!useSelfOwnedWireGuard);

  # Wake-on-LAN: magic packets are matched by the NIC at layer-2 and DO NOT require
  # any firewall port to be open (the matcher runs before netfilter). Some WoL
  # proxies / routers re-encapsulate magic packets as UDP-9 (discard) payloads,
  # so we open UDP 9 on the LAN interface only, not globally. UDP 7 (echo) was
  # never needed and has been removed (attack-surface minimisation).
  networking.interfaces = lib.mkIf isDaily {
    enp5s0.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };
  networking.firewall.interfaces = lib.mkIf isDaily {
    enp5s0.allowedUDPPorts = [ 9 ];  # WoL-over-UDP compatibility (LAN only)
  };

  # DNS resolver: needed on both profiles
  services.resolved.enable = lib.mkDefault true;

  # Configure NetworkManager to use systemd-resolved for DNS
  networking.networkmanager.dns = lib.mkIf isDaily "systemd-resolved";

  # Mullvad app mode: daily/player only
  # Paranoid/ghost uses the self-owned WireGuard path (wireguard.nix)
  services.mullvad-vpn.enable = lib.mkDefault (isDaily && !useSelfOwnedWireGuard);
  services.mullvad-vpn.package = lib.mkIf isDaily pkgs.mullvad-vpn;
}
