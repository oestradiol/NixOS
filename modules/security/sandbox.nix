# Sandbox knob registry.
#
# `sandbox-core.nix` is a pure Nix helper (not a NixOS module) that builds
# bubblewrap wrappers from keyword arguments. The `myOS.security.sandbox.*`
# options below control which surfaces those wrappers expose, and they are
# consumed by:
#   - modules/security/browser.nix        (safe-firefox, safe-tor, safe-mullvad)
#   - modules/security/sandboxed-apps.nix (safe-vrcx, safe-windsurf)
#   - modules/security/vm-tooling.nix     (vms enable gate, via `vms`)
#   - modules/security/governance.nix     (profile-specific invariants)
#
# This module declares the option namespace only. No config wiring lives
# here; that belongs with the consumers.
{ lib, ... }:
{
  options.myOS.security.sandbox = {
    browsers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use sandboxed browser wrappers instead of base Firefox.
        Hardened baseline defaults to wrapped browsers.
      '';
    };
    apps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable tightened bubblewrap wrappers for non-Flatpak desktop apps.
      '';
    };
    vms = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable KVM/QEMU VM tooling layer for high-risk workloads.
      '';
    };
    dbusFilter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable filtered D-Bus access via xdg-dbus-proxy for bubblewrap sandboxes.
      '';
    };
    x11 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow X11 socket passthrough into bubblewrap sandboxes.
        Hardened baseline keeps this off because X11 is a large shared-desktop attack surface.
      '';
    };
    wayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow Wayland socket passthrough into bubblewrap sandboxes.";
    };
    pipewire = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow PipeWire/Pulse sockets inside bubblewrap sandboxes.";
    };
    gpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow GPU device passthrough into bubblewrap sandboxes.";
    };
    portals = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow xdg-desktop-portal access from bubblewrap sandboxes.";
    };
  };
}
