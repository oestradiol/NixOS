{ lib, pkgs }:
let
  quote = lib.escapeShellArg;
  mkArgs = flag: values:
    lib.concatMapStringsSep " \\\n          " (v: quote "${flag}=${v}") values;
  mkPersistLines = persist:
    lib.concatMapStringsSep "\n" (p: ''
      mkdir -p "$HOST_HOME/${p}" "$SANDBOX_HOME/${p}"
      BWRAP_ARGS+=( --bind "$HOST_HOME/${p}" "/home/sandbox/${p}" )
    '') persist;
in {
  mkSandboxWrapper = {
    name,
    package,
    binaryName ? name,
    args ? [ ],
    network ? true,
    gpu ? false,
    enableDbusProxy ? true,
    wayland ? true,
    x11 ? true,
    pipewire ? false,
    sessionBusTalk ? [ ],
    sessionBusOwn ? [ ],
    sessionBusBroadcast ? [ ],
    systemBusTalk ? [ ],
    persist ? [ ],
    extraBwrapArgs ? [ ],
    extraEnv ? { },
    extraSetup ? "",
  }:
    pkgs.writeShellScriptBin "safe-${name}" ''
      set -euo pipefail

      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo "Error: XDG_RUNTIME_DIR not set. Start this from a graphical session." >&2
        exit 1
      fi

      HOST_HOME="''${HOME:?HOME not set}"
      HOST_UID="$(id -u)"
      HOST_GID="$(id -g)"
      STATE_ROOT="$XDG_RUNTIME_DIR/safe-${name}"
      SANDBOX_HOME="$STATE_ROOT/home"
      SANDBOX_RUNTIME="$STATE_ROOT/runtime"
      mkdir -p "$SANDBOX_HOME/.config" "$SANDBOX_HOME/.local/share" "$SANDBOX_HOME/.cache" "$SANDBOX_RUNTIME"

      BWRAP_ARGS=(
        --new-session
        --die-with-parent
        --unshare-user
        --uid "$HOST_UID"
        --gid "$HOST_GID"
        --unshare-ipc
        --unshare-pid
        --unshare-uts
        --unshare-cgroup
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --tmpfs /run
        --dir /run/user
        --dir /run/user/$HOST_UID
        --dir /run/user/$HOST_UID/pulse
        --dir /run/dbus
        --ro-bind /nix /nix
        --ro-bind /etc /etc
        --ro-bind /run/current-system /run/current-system
        --ro-bind /sys/dev/char /sys/dev/char
        --dir /home
        --dir /home/sandbox
        --chdir /home/sandbox
        --setenv HOME /home/sandbox
        --setenv USER sandbox
        --setenv LOGNAME sandbox
        --setenv XDG_CONFIG_HOME /home/sandbox/.config
        --setenv XDG_DATA_HOME /home/sandbox/.local/share
        --setenv XDG_CACHE_HOME /home/sandbox/.cache
        --setenv XDG_RUNTIME_DIR /run/user/$HOST_UID
        --cap-drop ALL
      )

      ${lib.optionalString (!network) ''
      BWRAP_ARGS+=( --unshare-net )
      ''}

      ${lib.optionalString wayland ''
      if [[ -n "''${WAYLAND_DISPLAY:-}" && -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
        BWRAP_ARGS+=( --ro-bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "/run/user/$HOST_UID/$WAYLAND_DISPLAY" )
        BWRAP_ARGS+=( --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" )
      fi
      ''}

      ${lib.optionalString x11 ''
      if [[ -n "''${DISPLAY:-}" && -d /tmp/.X11-unix ]]; then
        BWRAP_ARGS+=( --ro-bind /tmp/.X11-unix /tmp/.X11-unix )
        BWRAP_ARGS+=( --setenv DISPLAY "$DISPLAY" )
        if [[ -n "''${XAUTHORITY:-}" && -f "$XAUTHORITY" ]]; then
          mkdir -p "$STATE_ROOT/x11"
          cp "$XAUTHORITY" "$STATE_ROOT/x11/Xauthority"
          chmod 0600 "$STATE_ROOT/x11/Xauthority"
          BWRAP_ARGS+=( --ro-bind "$STATE_ROOT/x11/Xauthority" /home/sandbox/.Xauthority )
          BWRAP_ARGS+=( --setenv XAUTHORITY /home/sandbox/.Xauthority )
        fi
      fi
      ''}

      ${lib.optionalString pipewire ''
      if [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]]; then
        BWRAP_ARGS+=( --ro-bind "$XDG_RUNTIME_DIR/pipewire-0" /run/user/$HOST_UID/pipewire-0 )
      fi
      if [[ -S "$XDG_RUNTIME_DIR/pulse/native" ]]; then
        BWRAP_ARGS+=( --ro-bind "$XDG_RUNTIME_DIR/pulse/native" /run/user/$HOST_UID/pulse/native )
      fi
      ''}

      ${lib.optionalString gpu ''
      if [[ -d /dev/dri ]]; then
        BWRAP_ARGS+=( --dev-bind /dev/dri /dev/dri )
      fi
      for node in /dev/nvidiactl /dev/nvidia0 /dev/nvidia1 /dev/nvidia-modeset /dev/nvidia-uvm /dev/nvidia-uvm-tools /dev/kfd; do
        if [[ -e "$node" ]]; then
          BWRAP_ARGS+=( --dev-bind "$node" "$node" )
        fi
      done
      ''}

      ${lib.optionalString enableDbusProxy ''
      if [[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        DBUS_SESSION_PROXY="$STATE_ROOT/session-bus.sock"
        ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
          "$DBUS_SESSION_BUS_ADDRESS" \
          "$DBUS_SESSION_PROXY" \
          --filter \
          ${mkArgs "--talk" sessionBusTalk} \
          ${mkArgs "--own" sessionBusOwn} \
          ${mkArgs "--broadcast" sessionBusBroadcast} &
        DBUS_SESSION_PID=$!
        trap 'kill "$DBUS_SESSION_PID" 2>/dev/null || true${lib.optionalString (systemBusTalk != [ ]) "; kill \"$DBUS_SYSTEM_PID\" 2>/dev/null || true"}' EXIT
        BWRAP_ARGS+=( --ro-bind "$DBUS_SESSION_PROXY" /run/user/$HOST_UID/bus )
        BWRAP_ARGS+=( --setenv DBUS_SESSION_BUS_ADDRESS unix:path=/run/user/$HOST_UID/bus )
      fi

      ${lib.optionalString (systemBusTalk != [ ]) ''
      DBUS_SYSTEM_PROXY="$STATE_ROOT/system-bus.sock"
      ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        unix:path=/run/dbus/system_bus_socket \
        "$DBUS_SYSTEM_PROXY" \
        --filter \
        ${mkArgs "--talk" systemBusTalk} &
      DBUS_SYSTEM_PID=$!
      BWRAP_ARGS+=( --ro-bind "$DBUS_SYSTEM_PROXY" /run/dbus/system_bus_socket )
      BWRAP_ARGS+=( --setenv DBUS_SYSTEM_BUS_ADDRESS unix:path=/run/dbus/system_bus_socket )
      ''}
      ''}

      ${mkPersistLines persist}

      ${lib.concatMapStringsSep "\n" (arg: ''BWRAP_ARGS+=( ${quote arg} )'') extraBwrapArgs}
      ${lib.concatMapStringsSep "\n" (name: ''BWRAP_ARGS+=( --setenv ${name} ${quote extraEnv.${name}} )'') (builtins.attrNames extraEnv)}

      ${extraSetup}

      exec ${pkgs.bubblewrap}/bin/bwrap \
        "''${BWRAP_ARGS[@]}" \
        ${package}/bin/${binaryName} ${lib.concatMapStringsSep " " quote args} "$@"
    '';
}
