# Sandboxed Applications
# Bubblewrap wrappers for high-risk proprietary apps not available as Flatpak
# UID isolation (100000:100000) + process namespace + minimal filesystem access
# Note: Network namespace is NOT isolated - apps need host network for their functionality
#
# SECURITY TRADE-OFFS (daily profile - compatibility focus):
# - Host network exposed (required for app functionality)
# - Wayland/X11 socket exposed (required for display)
# - PipeWire socket exposed (required for audio)
# - GPU device nodes exposed (required for rendering)
# - /run partially bound (D-Bus, XDG runtime - not full /run)
# - /var bound readonly (system state compatibility)
# - D-Bus: filtered via xdg-dbus-proxy when sandbox.dbusFilter = true
#   When dbusFilter enabled: Full /run/user bind is REMOVED to prevent real bus access
#   This is ADVISORY filtering — motivated attackers may still find IPC bypass paths
#
# This is DAMAGE REDUCTION, not strong hostile-content isolation.
# For strong isolation, use VM isolation (sandbox.vms) instead.
{ config, lib, pkgs, ... }:
let
  sandbox = config.myOS.security.sandbox;
  inherit (config.myOS) profile;

  # Generic bubblewrap wrapper for GUI applications
  # 
  # CONSERVATIVE DEFAULTS (secure by default, override only when needed):
  # - extraBinds ? []       : No extra filesystem binds (add only what's required)
  # - extraArgs ? ""        : No extra command-line arguments
  # - bindVar ? false       : Don't bind /var by default (system state exposure)
  # - minimal ? false       : Use full /run binds (set true for paranoid mode)
  # - dbusFilter ? false    : No D-Bus filtering by default (apps need D-Bus)
  #
  # Profile-specific usage:
  # - Daily: bindVar = true (compatibility), minimal = false
  # - Paranoid: minimal = true (no /run binds), but apps are disabled anyway
  mkSandboxedApp = { 
    name, 
    package, 
    binaryName ? name, 
    extraBinds ? [], 
    extraArgs ? "", 
    bindVar ? false,      # CONSERVATIVE: don't bind /var by default
    minimal ? false,
  }: 
    pkgs.writeShellScriptBin "safe-${name}" ''
      set -eu
      
      RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/safe-${name}"
      PROFILE="$RUNTIME/profile"
      CACHE="$RUNTIME/cache"
      mkdir -p "$PROFILE" "$CACHE"
      
      # GPU and display sockets
      DISPLAY_SOCK="''${WAYLAND_DISPLAY:-$DISPLAY}"
      [[ -n "''${WAYLAND_DISPLAY:-}" ]] && WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && PIPEWIRE_SOCK="$XDG_RUNTIME_DIR/pipewire-0"
      [[ -d /dev/dri ]] && GPU_DEV="/dev/dri"
      
      # D-Bus filtering setup (when enabled via sandbox.dbusFilter)
      DBUS_PROXY_SOCK=""
      DBUS_SYSTEM_PROXY_SOCK=""
      ${if sandbox.dbusFilter then ''
      DBUS_PROXY_SOCK="$RUNTIME/dbus-proxy.sock"
      DBUS_SYSTEM_PROXY_SOCK="$RUNTIME/dbus-system-proxy.sock"
      
      # Start xdg-dbus-proxy for filtered SESSION bus access
      # More permissive than browsers: allow broader portal and app communication
      ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        "$DBUS_SESSION_BUS_ADDRESS" \
        "$DBUS_PROXY_SOCK" \
        --filter \
        --talk=org.freedesktop.portal.* \
        --talk=org.a11y.Bus \
        --talk=org.mpris.MediaPlayer2.* \
        --broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/* &
      DBUS_PID=$!
      
      # Start xdg-dbus-proxy for filtered SYSTEM bus access
      ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        "unix:path=/run/dbus/system_bus_socket" \
        "$DBUS_SYSTEM_PROXY_SOCK" \
        --filter \
        --talk=org.freedesktop.NetworkManager \
        --talk=org.freedesktop.login1 &
      DBUS_SYSTEM_PID=$!
      
      cleanup() { 
        kill $DBUS_PID 2>/dev/null || true
        kill $DBUS_SYSTEM_PID 2>/dev/null || true
      }
      trap cleanup EXIT
      '' else "# D-Bus filtering disabled — direct D-Bus access for compatibility
      :"}
      
      # Build runtime bindings - daily gets compatibility, paranoid would get minimal
      # (but sandboxed apps are disabled on paranoid anyway)
      ${if minimal then "RUN_BINDS=\"\"" else if sandbox.dbusFilter then '''
      # D-Bus filtered mode: NO full /run/user bind (prevents real bus access)
      RUN_BINDS=""
      [[ -S "$DBUS_PROXY_SOCK" ]] && RUN_BINDS="$RUN_BINDS --ro-bind \"$DBUS_PROXY_SOCK\" \"/run/user/$(id -u)/bus\""
      [[ -S "$DBUS_SYSTEM_PROXY_SOCK" ]] && RUN_BINDS="$RUN_BINDS --ro-bind \"$DBUS_SYSTEM_PROXY_SOCK\" \"/run/user/$(id -u)/system-bus-proxy.sock\""
      ''' else '''
      # D-Bus unfiltered mode: full /run/user bind (compatibility)
      RUN_BINDS=""
      [[ -d /run/user/$(id -u) ]] && RUN_BINDS="$RUN_BINDS --ro-bind /run/user/$(id -u) /run/user/$(id -u)"
      [[ -S /run/dbus/system_bus_socket ]] && RUN_BINDS="$RUN_BINDS --ro-bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket"
      '''
      
      exec ${pkgs.bubblewrap}/bin/bwrap \
        --new-session \
        --die-with-parent \
        --unshare-user \
        --uid 100000 --gid 100000 \
        --unshare-ipc \
        --unshare-pid \
        --unshare-uts \
        --proc /proc \
        --dev /dev \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --ro-bind /usr /usr \
        --ro-bind /bin /bin \
        --ro-bind /sbin /sbin \
        --ro-bind /lib /lib \
        --ro-bind /lib64 /lib64 \
        ''${RUN_BINDS} \
        ''${lib.optionalString bindVar "--ro-bind /var /var"} \
        --bind "$RUNTIME" "$HOME" \
        --tmpfs /tmp \
        ''${WAYLAND_SOCK:+--ro-bind "$WAYLAND_SOCK" "$WAYLAND_SOCK"} \
        ''${PIPEWIRE_SOCK:+--ro-bind "$PIPEWIRE_SOCK" "$PIPEWIRE_SOCK"} \
        ''${GPU_DEV:+--dev-bind /dev/dri /dev/dri} \
        --dev-bind /dev/null /dev/null \
        --dev-bind /dev/zero /dev/zero \
        --dev-bind /dev/random /dev/random \
        --dev-bind /dev/urandom /dev/urandom \
        --dev-bind /dev/tty /dev/tty \
        ${lib.concatMapStrings (b: "--bind ${b.from} ${b.to} ") extraBinds} \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
        --setenv DISPLAY "$DISPLAY" \
        ${lib.optionalString sandbox.dbusFilter ''
        --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=/run/user/$(id -u)/bus" \
        --setenv DBUS_SYSTEM_BUS_ADDRESS "unix:path=/run/user/$(id -u)/system-bus-proxy.sock" \
        ''}\
        --cap-drop ALL \
        ${package}/bin/${binaryName} ${extraArgs} "$@"
    '';

  # VRCX (VRChat utility) - not on Flathub
  # Daily profile apps: bind /var for compatibility
  safeVrcxDaily = mkSandboxedApp {
    name = "vrcx";
    package = pkgs.vrcx;
    binaryName = "VRCX";
    bindVar = true;
  };

  safeWindsurfDaily = mkSandboxedApp {
    name = "windsurf";
    package = pkgs.windsurf;
    binaryName = "windsurf";
    bindVar = true;
    extraBinds = [
      { from = "$HOME/.config/Windsurf"; to = "$HOME/.config/Windsurf"; }
      { from = "$HOME/.local/share/Windsurf"; to = "$HOME/.local/share/Windsurf"; }
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
      desktopName = "${name} (Sandboxed)";
      categories = [ "Network" "Application" ];
      terminal = false;
      type = "Application";
    };

  safeVrcxDesktop = mkSandboxedDesktop {
    name = "VRCX";
    exec = "safe-vrcx";
    icon = "vrcx";
    comment = "VRCX with UID isolation (damage reduction, not strong isolation)";
    genericName = "VRChat Utility";
  };

  safeWindsurfDesktop = mkSandboxedDesktop {
    name = "Windsurf";
    exec = "safe-windsurf";
    icon = "windsurf";
    comment = "Windsurf with UID isolation (damage reduction, not strong isolation)";
    genericName = "Code Editor";
  };

in {
  config = lib.mkIf sandbox.apps {
    environment.systemPackages = lib.mkMerge [
      # Daily profile: VRCX and Windsurf with /var bind for compatibility
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
