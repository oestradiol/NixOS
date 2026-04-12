{ config, lib, pkgs, ... }:
let
  # VPN interfaces for Mullvad app mode (deprecated for paranoid)
  vpnIfaces = [ "wg-mullvad" "tun0" "tun1" ];

  # Determine which VPN mode is active
  # wireguardMullvad.enable = true → self-owned WireGuard (paranoid)
  # wireguardMullvad.enable = false → Mullvad app mode (daily, default)
  useSelfOwnedWireGuard = config.myOS.security.wireguardMullvad.enable;
in {
  networking.networkmanager.enable = true;

  # Firewall: enable NixOS firewall in Mullvad app mode
  # Self-owned WireGuard mode uses its own nftables policy exclusively (wireguard.nix)
  networking.firewall.enable = lib.mkDefault (!useSelfOwnedWireGuard);
  networking.firewall.allowedUDPPorts = lib.optionals (config.myOS.profile == "daily") [ 7 ];

  networking.interfaces = lib.mkIf (config.myOS.profile == "daily") {
    enp5s0.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };

  # Mullvad app mode: enable daemon and resolved
  # Self-owned WireGuard mode: handled in wireguard.nix (disables mullvad-vpn)
  services.resolved.enable = lib.mkDefault (!useSelfOwnedWireGuard);
  services.mullvad-vpn.enable = lib.mkDefault (!useSelfOwnedWireGuard);
  services.mullvad-vpn.package = pkgs.mullvad-vpn;
}
