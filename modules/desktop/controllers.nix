# Controller and Bluetooth support for living room gaming.
#
# - Xbox One/Series wireless controllers via xpadneo (Bluetooth)
# - Xbox 360 wired controllers (xpad, built-in)
# - Steam Controller
# - Bluetooth tuning for low-latency controller connections
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.gaming.controllers;
in {
  options.myOS.gaming.controllers.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Bluetooth and Xbox controller support (xpadneo, game-devices-udev-rules).";
  };

  config = lib.mkIf cfg.enable {
    # ── Xbox One / Series wireless controller (Bluetooth) ───────────
    hardware.xpadneo.enable = true;

    # ── Bluetooth ────────────────────────────────────────────────────
    hardware.bluetooth = {
      enable = true;
      # Power on the Bluetooth adapter at boot (living room PC use case)
      powerOnBoot = true;
      settings = {
        General = {
          # Enable experimental features — required for full Xbox controller
          # support (battery reporting, LE features)
          Experimental = true;
          # Support multiple Bluetooth profiles simultaneously
          # (e.g., controller + headphones at the same time)
          MultiProfile = "multiple";
          # Faster reconnection to previously paired controllers
          FastConnectable = true;
          # SteamOS-aligned LE privacy and codec offload
          KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e,330859bc-7506-492d-9370-9a6f0614037f";
        };
      };
    };

    # Load bluetooth module even without hardware (for testing and controller support)
    boot.kernelModules = [ "bluetooth" ];

    # Disable Bluetooth ERTM — fixes pairing issues with Xbox controllers
    # and many other Bluetooth gamepads (8BitDo, PS4/PS5 controllers)
    boot.extraModprobeConfig = ''
      options bluetooth disable_ertm=1
    '';

    # ── Controller udev rules ───────────────────────────────────────
    # Broad game device udev rules (gamepads, arcade sticks, peripherals beyond Steam's set)
    services.udev.packages = [ pkgs.game-devices-udev-rules ];
    services.udev.extraRules = ''
      # ── From SteamOS: USB devices, HID devices, Steam Controller ──
      # USB devices and topological children
      SUBSYSTEMS=="usb", TAG+="uaccess"

      # HID devices over hidraw
      KERNEL=="hidraw*", TAG+="uaccess"

      # Steam Controller udev write access
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"

      # ── Ensure non-root access to gamepad input devices ───────────
      # Xbox 360 wired controller
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="028e", TAG+="uaccess"
      # Xbox 360 wireless receiver
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0719", TAG+="uaccess"
      # Xbox One controller (USB)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02ea", TAG+="uaccess"
      # Xbox Series X|S controller (USB)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b12", TAG+="uaccess"

      # Sony DualShock 4
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", TAG+="uaccess"
      # Sony DualSense (PS5)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", TAG+="uaccess"

      # 8BitDo controllers (common living room gamepads)
      # XInput mode
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="310b", TAG+="uaccess"
      # DInput mode (hold B + turn on for extra buttons)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="6012", TAG+="uaccess"
    '';
    # Note: generic hidraw uaccess is already set in steam-session.nix

    # ── Blueman Bluetooth manager ───────────────────────────────────
    # Provides a GUI for pairing controllers from KDE desktop mode
    services.blueman.enable = true;
  };
}
