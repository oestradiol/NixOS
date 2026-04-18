# Host identity and primary-LAN parameterisation.
#
# Owns the handful of "what machine is this, and on which wire does it
# live" knobs that must be visible before any other module can make
# decisions (hostname for firewalls, timezone for logs, primary
# interface for WoL / WiVRn / firewall scoping, default locale for
# glibc). All defaults match the operator's reference machine so adding
# this module is a no-op on the current deployment.
{ config, lib, ... }:
{
  options.myOS = {
    host = {
      hostName = lib.mkOption {
        type = lib.types.str;
        default = "nixos";
        description = ''
          System hostname. Applied to networking.hostName. Forkers should
          override this in their hosts/<host>/local.nix or via an
          integrator flake.
        '';
      };
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "America/Sao_Paulo";
        description = "System timezone (applied to time.timeZone).";
      };
      defaultLocale = lib.mkOption {
        type = lib.types.str;
        default = "en_GB.UTF-8";
        description = ''
          Default glibc locale (LANG). Applied via modules/desktop/i18n.nix.
        '';
      };
    };

    networking.primaryInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp5s0";
      description = ''
        Name of the primary wired LAN interface. Consumed by the WoL
        firewall rules in modules/security/networking.nix and the WiVRn
        interface-scoping defaults in modules/desktop/vr.nix. Forkers on
        different hardware must override this (e.g. `eno1`, `enp2s0`).
      '';
    };
  };

  config = {
    networking.hostName = config.myOS.host.hostName;
    time.timeZone = config.myOS.host.timeZone;
  };
}
