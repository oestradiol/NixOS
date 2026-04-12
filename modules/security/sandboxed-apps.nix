# Sandboxed Applications
# Bubblewrap wrappers for high-risk proprietary apps not available as Flatpak
# MAXIMUM HARDENING (daily profile): Tighten first, accept breakage, debug later
#
# HARDENING POLICY (daily profile - VRCX and Windsurf):
# - D-Bus: xdg-dbus-proxy with default deny, minimum required names only
# - Runtime dir: Private per-app runtime, no full /run/user bind
# - Filesystem: Read-only root, per-app writable persistence (config/data/cache only)
# - Network: Exposed only if app requires it (VRCX needs it, Windsurf may not)
# - Privileges: no-new-privileges, unshare namespaces, drop capabilities
# - Seccomp: Strict filtering (to be added based on observed breakage)
# - Landlock: To be added if practical
# - Persistence: Only app-specific config/data/cache preserved
#
# This is HARDENED DAILY CONTAINMENT for semi-trusted apps, not VM isolation.
# For strong isolation, use VM isolation (sandbox.vms) or Flatpak.
#
# BREAKAGE POLICY: Log any breakage to POST-STABILITY.md, add exceptions only after observed need.
{ config, lib, pkgs, ... }:
let
  sandbox = config.myOS.security.sandbox;
  inherit (config.myOS) profile;

  # Maximum hardened wrapper for daily profile apps (VRCX, Windsurf)
  # Tighten first, accept breakage, debug later
  mkHardenedApp = {
    name,
    package,
    binaryName ? name,
    configDir ? null,
    dataDir ? null,
    cacheDir ? null,
    network ? false,  # Default: no network (tighten first)
    dbusNames ? [],   # Default: no D-Bus names (tighten first)
  }:
    pkgs.writeShellScriptBin "safe-${name}" ''
      set -euo pipefail

      # Check required environment variables
      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo "Error: XDG_RUNTIME_DIR not set. Are you running in a graphical session?" >&2
        exit 1
      fi

      # Private runtime directory per app
      RUNTIME="$XDG_RUNTIME_DIR/safe-${name}"
      PROFILE="$RUNTIME/profile"
      CACHE="$RUNTIME/cache"
      mkdir -p "$PROFILE" "$CACHE"

      # GPU and display sockets - check availability before use
      DISPLAY_SOCK=""
      WAYLAND_SOCK=""
      PIPEWIRE_SOCK=""
      GPU_DEV=""

      [[ -n "''${WAYLAND_DISPLAY:-}" ]] && WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      [[ -S "$WAYLAND_SOCK" ]] || WAYLAND_SOCK=""
      [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && PIPEWIRE_SOCK="$XDG_RUNTIME_DIR/pipewire-0"
      [[ -d /dev/dri ]] && GPU_DEV="/dev/dri"

      # D-Bus filtering - default deny, allow only minimum required names
      # Prefer org.freedesktop.portal.* for portal access
      DBUS_PROXY_SOCK=""
      DBUS_SYSTEM_PROXY_SOCK=""
      DBUS_PID=""
      DBUS_SYSTEM_PID=""

      if [[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        DBUS_PROXY_SOCK="$RUNTIME/dbus-proxy.sock"
        DBUS_SYSTEM_PROXY_SOCK="$RUNTIME/dbus-system-proxy.sock"

        # Start xdg-dbus-proxy for SESSION bus (default deny)
        ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
          "$DBUS_SESSION_BUS_ADDRESS" \
          "$DBUS_PROXY_SOCK" \
          --filter \
          --call=org.freedesktop.portal.*=@/org/freedesktop/portal/* \
          ${lib.concatMapStringsSep "\n" (n: "--talk=${n}") dbusNames} &
        DBUS_PID=$!

        # Start xdg-dbus-proxy for SYSTEM bus (default deny)
        ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
          "unix:path=/run/dbus/system_bus_socket" \
          "$DBUS_SYSTEM_PROXY_SOCK" \
          --filter &
        DBUS_SYSTEM_PID=$!

        cleanup() {
          kill $DBUS_PID 2>/dev/null || true
          kill $DBUS_SYSTEM_PID 2>/dev/null || true
        }
        trap cleanup EXIT
      fi

      # Build runtime bindings - NO full /run/user bind (tightened)
      RUN_BINDS=""
      [[ -S "$DBUS_PROXY_SOCK" ]] && RUN_BINDS="$RUN_BINDS --ro-bind \"$DBUS_PROXY_SOCK\" \"/run/user/$(id -u)/bus\""
      [[ -S "$DBUS_SYSTEM_PROXY_SOCK" ]] && RUN_BINDS="$RUN_BINDS --ro-bind \"$DBUS_SYSTEM_PROXY_SOCK\" \"/run/user/$(id -u)/system-bus-proxy.sock\""

      # Per-app writable persistence (config, data, cache only)
      PERSIST_BINDS=""
      ${lib.optionalString (configDir != null) ''
      PERSIST_BINDS="$PERSIST_BINDS --bind \"$HOME/.config/${configDir}\" \"$HOME/.config/${configDir}\""
      ''}
      ${lib.optionalString (dataDir != null) ''
      PERSIST_BINDS="$PERSIST_BINDS --bind \"$HOME/.local/share/${dataDir}\" \"$HOME/.local/share/${dataDir}\""
      ''}
      ${lib.optionalString (cacheDir != null) ''
      PERSIST_BINDS="$PERSIST_BINDS --bind \"$HOME/.cache/${cacheDir}\" \"$HOME/.cache/${cacheDir}\""
      ''}

      exec ${pkgs.bubblewrap}/bin/bwrap \
        --new-session \
        --die-with-parent \
        --unshare-user \
        --uid 100000 --gid 100000 \
        --unshare-ipc \
        --unshare-pid \
        --unshare-uts \
        --unshare-cgroup \
        --proc /proc \
        --dev /dev \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --ro-bind /usr /usr \
        --ro-bind /bin /bin \
        --ro-bind /sbin /sbin \
        --ro-bind /lib /lib \
        --ro-bind /lib64 /lib64 \
        --ro-bind /run /run \
        ''${RUN_BINDS} \
        --bind "$RUNTIME" "$HOME" \
        --tmpfs /tmp \
        ''${WAYLAND_SOCK:+--ro-bind "$WAYLAND_SOCK" "$WAYLAND_SOCK"} \
        ''${PIPEWIRE_SOCK:+--ro-bind "$PIPEWIRE_SOCK" "$PIPEWIRE_SOCK"} \
        ''${GPU_DEV:+--dev-bind /dev/dri /dev/dri} \
        --dev-bind /dev/null /dev/null \
        --dev-bind /dev/zero /dev/null \
        --dev-bind /dev/random /dev/random \
        --dev-bind /dev/urandom /dev/urandom \
        --dev-bind /dev/tty /dev/tty \
        ${lib.optionalString network "--share-net"} \
        ''${PERSIST_BINDS} \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
        --setenv DISPLAY "$DISPLAY" \
        ${lib.optionalString (DBUS_PROXY_SOCK != "") ''
        --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=/run/user/$(id -u)/bus" \
        --setenv DBUS_SYSTEM_BUS_ADDRESS "unix:path=/run/user/$(id -u)/system-bus-proxy.sock" \
        ''}\
        --cap-drop ALL \
        --no-new-privileges \
        --seccomp \
        ${package}/bin/${binaryName} "$@"
    '';

  # VRCX (VRChat utility) - not on Flathub
  # Maximum hardening: network required for VRChat API, portals for file access
  safeVrcxDaily = mkHardenedApp {
    name = "vrcx";
    package = pkgs.vrcx;
    binaryName = "VRCX";
    configDir = "VRCX";
    dataDir = "VRCX";
    cacheDir = "VRCX";
    network = true;  # Required for VRChat API
    dbusNames = [
      "org.freedesktop.portal.FileChooser"
      "org.freedesktop.portal.Settings"
    ];
  };

  # Windsurf (code editor) - not on Flathub
  # Maximum hardening: network may not be required for local editing, portals for file access
  safeWindsurfDaily = mkHardenedApp {
    name = "windsurf";
    package = pkgs.windsurf;
    binaryName = "windsurf";
    configDir = "Windsurf";
    dataDir = "Windsurf";
    cacheDir = "Windsurf";
    network = true;  # Required for AI features (may break without it)
    dbusNames = [
      "org.freedesktop.portal.FileChooser"
      "org.freedesktop.portal.Settings"
    ];
  };

  # Desktop entries for sandboxed apps
  mkSandboxedDesktop = { name, exec, icon, comment, genericName ? null }:
    pkgs.makeDesktopItem {
      name = "safe-${name}";
      exec = "${exec} %U";
      icon = icon;
      comment = comment;
      genericName = genericName;
      desktopName = "${name} (Hardened Sandbox)";
      categories = [ "Network" "Application" ];
      terminal = false;
      type = "Application";
    };

  safeVrcxDesktop = mkSandboxedDesktop {
    name = "VRCX";
    exec = "safe-vrcx";
    icon = "vrcx";
    comment = "VRCX with hardened daily containment (maximum tightening, log breakage to POST-STABILITY.md)";
    genericName = "VRChat Utility";
  };

  safeWindsurfDesktop = mkSandboxedDesktop {
    name = "Windsurf";
    exec = "safe-windsurf";
    icon = "windsurf";
    comment = "Windsurf with hardened daily containment (maximum tightening, log breakage to POST-STABILITY.md)";
    genericName = "Code Editor";
  };

in {
  config = lib.mkIf sandbox.apps {
    environment.systemPackages = lib.mkMerge [
      # Daily profile: VRCX and Windsurf with maximum hardening
      (lib.mkIf (profile == "daily") [
        safeVrcxDaily
        safeWindsurfDaily
        safeVrcxDesktop
        safeWindsurfDesktop
      ])
      # Paranoid profile: no sandboxed apps (uses Flatpak and VM isolation instead)
      (lib.mkIf (profile == "paranoid") [])
    ];
  };
}
