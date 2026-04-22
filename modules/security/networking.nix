{ config, lib, pkgs, ... }:
let
  primaryIface = config.myOS.networking.primaryInterface;

  # VPN architecture options
  useSelfOwnedWireGuard = config.myOS.security.wireguardMullvad.enable;
  # Enable Mullvad app mode by default when not using self-owned WireGuard
  useMullvadAppMode = config.myOS.networking.mullvadAppMode.enable or (!useSelfOwnedWireGuard);
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
  networking.interfaces = lib.mkIf config.myOS.networking.wakeOnLan.enable {
    ${primaryIface}.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };
  networking.firewall.interfaces = lib.mkIf config.myOS.networking.wakeOnLan.enable {
    ${primaryIface}.allowedUDPPorts = [ 9 ];  # WoL-over-UDP compatibility (LAN only)
  };

  # DNS resolver: needed when NetworkManager is enabled
  services.resolved.enable = lib.mkDefault config.networking.networkmanager.enable;

  # Configure NetworkManager to use systemd-resolved for DNS
  networking.networkmanager.dns = lib.mkIf config.networking.networkmanager.enable "systemd-resolved";

  # Mullvad app mode: enabled by default unless using self-owned WireGuard
  services.mullvad-vpn.enable = lib.mkDefault (useMullvadAppMode && !useSelfOwnedWireGuard);
  services.mullvad-vpn.package = lib.mkIf (useMullvadAppMode && !useSelfOwnedWireGuard) pkgs.mullvad-vpn;
}
