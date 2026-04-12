# Sandboxed Applications
# Bubblewrap wrappers for high-risk proprietary apps not available as Flatpak
# UID isolation (100000:100000) + process namespace + minimal filesystem access
# Note: Network namespace is NOT isolated - apps need host network for their functionality
{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.security.sandboxedApps;

  # Generic bubblewrap wrapper for GUI applications
  # Similar to browser.nix mkSandboxedBrowser but for general apps
  mkSandboxedApp = { name, package, binaryName ? name, extraBinds ? [], extraArgs ? "" }: 
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
        --ro-bind /run /run \
        --ro-bind /var /var \
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
        --dev-bind /dev/input /dev/input \
        ${lib.concatMapStrings (b: "--bind ${b.from} ${b.to} ") extraBinds} \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
        --setenv DISPLAY "$DISPLAY" \
        --cap-drop ALL \
        ${package}/bin/${binaryName} ${extraArgs} "$@"
    '';

  # VRCX (VRChat utility) - not on Flathub
  safeVrcx = mkSandboxedApp {
    name = "vrcx";
    package = pkgs.vrcx;
    binaryName = "VRCX";
  };

  # Windsurf (Code editor) - not on Flathub
  safeWindsurf = mkSandboxedApp {
    name = "windsurf";
    package = pkgs.windsurf;
    binaryName = "windsurf";
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
    comment = "VRCX with UID isolation sandbox";
    genericName = "VRChat Utility";
  };

  safeWindsurfDesktop = mkSandboxedDesktop {
    name = "Windsurf";
    exec = "safe-windsurf";
    icon = "windsurf";
    comment = "Windsurf with UID isolation sandbox";
    genericName = "Code Editor";
  };

in {
  options.myOS.security.sandboxedApps = {
    enable = lib.mkEnableOption "Sandboxed applications with bubblewrap";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      safeVrcx
      safeWindsurf
      safeVrcxDesktop
      safeWindsurfDesktop
    ];
  };
}
