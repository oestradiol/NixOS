# VR option declarations and shared config
{ config, lib, pkgs, ... }:
let
  vr = config.myOS.vr;
  lanIfaces = vr.lanInterfaces;
  # Policy: do NOT use services.wivrn.openFirewall. Upstream opens 9757 on EVERY
  # interface. We bind to `myOS.vr.lanInterfaces` only via networking.firewall.interfaces.
  wivrnPort = 9757;
  perIfaceFirewall = lib.genAttrs lanIfaces (_: {
    allowedTCPPorts = [ wivrnPort ];
    allowedUDPPorts = [ wivrnPort ];
  });
in {
  options.myOS.vr = {
    # WiVRn's upstream nixpkgs module hard-enables services.avahi + publish.userServices
    # without mkDefault, which would broadcast mDNS service records on every reachable
    # LAN. This knob gates that behaviour so the daily profile only broadcasts when
    # explicitly opted in. When OFF (default): connect the headset by typing the host's
    # IP manually in WiVRn's headset app. When ON: avahi advertises on the declared
    # LAN interfaces only (not everywhere).
    lanDiscovery.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow WiVRn to advertise itself via mDNS/avahi on the LAN so VR headsets
        auto-discover the host. Default: OFF. When OFF, the headset connects by
        entering the host IP manually. When ON, advertising is scoped to
        `myOS.vr.lanInterfaces` only (not all interfaces).
      '';
    };
    lanInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "enp5s0" ];
      description = ''
        LAN interfaces where WiVRn (TCP/UDP 9757) is reachable. The firewall opens
        9757 ONLY on these interfaces, and if `lanDiscovery.enable = true` avahi
        advertises on these interfaces only.
      '';
    };
  };

  # Gate the entire config on the daily profile. Paranoid never activates
  # wivrn (no VR stack, no avahi beacon). This gate preserves the
  # pre-Stage-2 semantics where vr.nix was only reachable through the
  # daily-specific gaming.nix import chain. A future stage can replace
  # this with a dedicated `myOS.gaming.vr.enable` master knob.
  config = lib.mkIf (config.myOS.profile == "daily") {
    users.groups.realtime = {};

    security.pam.loginLimits = [
      # VR Compositor locks memory pages.
      # Without unlimited memlock, this fails with EPERM.
      { domain = "@users"; type = "soft"; item = "memlock"; value = "unlimited"; }
      { domain = "@users"; type = "hard"; item = "memlock"; value = "unlimited"; }
      # Realtime priority perms
      { domain = "@realtime"; type = "soft"; item = "rtprio"; value = "99"; }
    ];

    # WiVRn
    services.wivrn = {
      enable = true;
      autoStart = true;
      openFirewall = false;  # see `networking.firewall.interfaces` below
      package = (pkgs.wivrn.override { cudaSupport = config.myOS.gpu == "nvidia"; });
      config.json = {
        encoders = [
          {
            encoder = if config.myOS.gpu == "nvidia" then "nvenc" else "vaapi";
            codec = "h265";
          }
        ];
      };
    };

    # Allow inbound WiVRn (TCP/UDP 9757) on declared LAN interfaces ONLY.
    networking.firewall.interfaces = perIfaceFirewall;

    systemd.user.services.wivrn = {
      serviceConfig = {
        Nice = -10;
        LimitRTPRIO = 99;
        LimitMEMLOCK = "infinity";
      };
    };

    # ── mDNS/avahi policy ─────────────────────────────────────────
    # Upstream nixpkgs `wivrn.nix` hard-sets services.avahi.enable + publish.userServices
    # = true without mkDefault. Without the overrides below, every WiVRn-enabled host
    # broadcasts "I am a VR server" on all LANs it can reach — an identity beacon that
    # has nothing to do with VR functioning.
    #
    # Default: lanDiscovery.enable = false → avahi disabled, headset connects by typing
    #          the host IP manually in WiVRn's headset app.
    # Opt-in : myOS.vr.lanDiscovery.enable = true → avahi advertises on
    #          `myOS.vr.lanInterfaces` ONLY (not all interfaces).
    services.avahi = lib.mkMerge [
      (lib.mkIf (!vr.lanDiscovery.enable) {
        enable = lib.mkForce false;
        publish = {
          enable = lib.mkForce false;
          userServices = lib.mkForce false;
        };
      })
      (lib.mkIf vr.lanDiscovery.enable {
        # Scope the broadcast to the declared LAN interfaces only so we don't
        # leak onto any other reachable network (VPN, Bluetooth, guest iface).
        allowInterfaces = lanIfaces;
        denyInterfaces = [ ];
        ipv4 = true;
        ipv6 = false;
        openFirewall = true;  # mDNS 5353 on the interfaces above only
      })
    ];

    # Other
    environment.systemPackages = with pkgs; [
      wayvr # Overlay
    ];
  };
}
