#!/usr/bin/env bash
# Runtime: sandbox wrappers. Paranoid ships safe-firefox / safe-tor /
# safe-mullvad; daily does not (sandbox.browsers=false). Daily ships the
# safe-* app wrappers (VRCX, Windsurf) only if sandbox.apps=true AND they're
# enabled in sandboxed-apps.nix (they are commented out today).
source "${BASH_SOURCE%/*}/../lib/common.sh"

profile=$(detect_profile)

describe "browser wrappers per profile"
if [[ "$profile" == "paranoid" ]]; then
  for w in safe-firefox safe-tor-browser safe-mullvad-browser; do
    if command -v "$w" >/dev/null 2>&1; then
      pass "$w in PATH"
    else
      fail "$w missing on paranoid (sandbox.browsers=true should ship it)"
    fi
  done
  # Plain firefox must NOT be reachable (programs.firefox.enable=false).
  if command -v firefox >/dev/null 2>&1; then
    wpath=$(command -v firefox)
    # Accept when it's actually the safe-firefox wrapper (shell script).
    if head -1 "$wpath" 2>/dev/null | grep -q 'bwrap'; then
      pass "firefox on paranoid is the bubblewrap wrapper"
    else
      fail "plain firefox is reachable on paranoid: $wpath"
    fi
  fi
else
  for w in safe-firefox safe-tor-browser safe-mullvad-browser; do
    if command -v "$w" >/dev/null 2>&1; then
      warn "$w exists on daily even though sandbox.browsers=false"
    else
      pass "$w absent on daily (expected)"
    fi
  done
  # Plain firefox should be reachable via programs.firefox.
  if command -v firefox >/dev/null 2>&1; then
    pass "firefox reachable on daily (enterprise-policy path)"
  else
    fail "firefox not reachable on daily"
  fi
fi

describe "sandbox-core wrapper script hardening (static)"
# The wrapper emits bwrap calls with specific flags. Verify the wrapper
# shipped in /nix/store matches policy: --clearenv, --new-session,
# --die-with-parent, --cap-drop ALL, unshare-{user,ipc,pid,uts,cgroup}.
wrapper_bin=$(command -v safe-firefox 2>/dev/null || true)
if [[ -z "$wrapper_bin" ]]; then
  # Try to locate any safe-* binary available on this profile
  wrapper_bin=$(compgen -c 'safe-' 2>/dev/null | head -1 || true)
  if [[ -n "$wrapper_bin" ]]; then
    wrapper_bin=$(command -v "$wrapper_bin")
  fi
fi
if [[ -n "$wrapper_bin" && -r "$wrapper_bin" ]]; then
  for f in --clearenv --new-session --die-with-parent --unshare-user \
           --unshare-ipc --unshare-pid --unshare-uts --unshare-cgroup \
           --cap-drop; do
    if grep -qF "$f" "$wrapper_bin"; then
      pass "wrapper uses $f"
    else
      fail "wrapper missing $f flag"
    fi
  done
  # cap-drop must be ALL
  if grep -qE 'cap-drop\s+ALL' "$wrapper_bin"; then
    pass "wrapper drops all capabilities"
  else
    fail "wrapper cap-drop value is not ALL"
  fi
  # minimal /etc allowlist for browsers
  if grep -q 'etcMode\|--tmpfs /etc\|--ro-bind "/etc/' "$wrapper_bin"; then
    pass "wrapper uses minimal /etc allowlist or --ro-bind selective /etc"
  else
    warn "wrapper /etc handling not detectable by grep"
  fi
else
  skip "no safe-* wrapper available in PATH on this profile"
fi

describe "bubblewrap + xdg-dbus-proxy binaries available"
if command -v bwrap >/dev/null 2>&1; then
  pass "bwrap in PATH"
else
  fail "bwrap missing from PATH"
fi
# xdg-dbus-proxy is pulled in as a runtime dependency of the sandbox wrappers
# but is not exported into the interactive PATH. Confirm it exists in the
# store so wrappers can execute it.
# Note: /nix/store dir names are <hash>-<name>-<version>; glob with leading *.
if command -v xdg-dbus-proxy >/dev/null 2>&1; then
  pass "xdg-dbus-proxy in PATH"
elif find /nix/store -maxdepth 2 -type d -name '*-xdg-dbus-proxy-*' 2>/dev/null | grep -q . \
     || find /nix/store -maxdepth 3 -type f -name 'xdg-dbus-proxy' 2>/dev/null | grep -q .; then
  pass "xdg-dbus-proxy present in /nix/store (wrappers reference it directly)"
else
  fail "xdg-dbus-proxy not available in PATH or /nix/store"
fi

describe "sandboxed daily app wrappers (VRCX, Windsurf) — currently commented out"
# modules/security/sandboxed-apps.nix has all four desktop items disabled
# behind comments. This test documents that state so a future enablement is
# caught as a governance event.
sa="$REPO_ROOT/modules/security/sandboxed-apps.nix"
if grep -q '^\s*#\s*safeVrcxDaily' "$sa"; then
  pass "safeVrcxDaily still commented out in sandboxed-apps.nix"
else
  warn "safeVrcxDaily is no longer commented out — update tests"
fi
if grep -q '^\s*#\s*safeWindsurfDaily' "$sa"; then
  pass "safeWindsurfDaily still commented out in sandboxed-apps.nix"
else
  warn "safeWindsurfDaily is no longer commented out — update tests"
fi
# Hence, safe-vrcx / safe-windsurf must NOT be in PATH.
if command -v safe-vrcx >/dev/null 2>&1; then
  warn "safe-vrcx is in PATH but sandboxed-apps.nix keeps it commented — update tests"
else
  pass "safe-vrcx absent (matches current commented-out state)"
fi
if command -v safe-windsurf >/dev/null 2>&1; then
  warn "safe-windsurf is in PATH but sandboxed-apps.nix keeps it commented — update tests"
else
  pass "safe-windsurf absent (matches current commented-out state)"
fi
