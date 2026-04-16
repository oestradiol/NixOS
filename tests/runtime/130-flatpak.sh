#!/usr/bin/env bash
# Runtime: Flatpak + Flathub + xdg-desktop-portal.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "flatpak service + systemd unit"
# services.flatpak.enable=true enables flatpak-system-helper.service.
if systemctl cat flatpak-system-helper.service >/dev/null 2>&1; then
  pass "flatpak-system-helper.service unit exists"
  # It's an on-demand dbus service, not always active.
  state=$(systemctl is-active flatpak-system-helper.service 2>&1 || true)
  info "flatpak-system-helper state: $state"
else
  fail "flatpak-system-helper.service unit missing"
fi

describe "flatpak-repo bootstrap service (repo-managed)"
# modules/security/flatpak.nix declares systemd.services.flatpak-repo
assert_unit_exists flatpak-repo.service "flatpak-repo.service unit declared"
# oneshot + RemainAfterExit → should have run at least once successfully.
state=$(systemctl is-active flatpak-repo.service 2>&1 || true)
if [[ "$state" == "active" ]]; then
  pass "flatpak-repo.service is active (exited ok)"
else
  fail "flatpak-repo.service state: $state" \
    "$(journalctl -u flatpak-repo.service -n 15 --no-pager 2>/dev/null || true)"
fi

describe "flatpak binary + /var/lib/flatpak"
if command -v flatpak >/dev/null 2>&1; then
  pass "flatpak binary in PATH"
else
  fail "flatpak not in PATH"
fi
if [[ -d /var/lib/flatpak ]]; then
  pass "/var/lib/flatpak exists (persisted root)"
else
  fail "/var/lib/flatpak missing"
fi

describe "flathub remote configured"
if command -v flatpak >/dev/null 2>&1; then
  remotes=$(flatpak remotes 2>/dev/null || true)
  if grep -q '^flathub' <<<"$remotes"; then
    pass "flathub remote present"
  else
    fail "flathub remote not registered" "$remotes"
  fi
fi

describe "xdg-desktop-portal enabled"
# xdg.portal.enable = true; GTK portal shipped.
if systemctl --user cat xdg-desktop-portal.service >/dev/null 2>&1; then
  pass "xdg-desktop-portal.service unit present"
  state=$(systemctl --user is-active xdg-desktop-portal.service 2>&1 || true)
  info "xdg-desktop-portal state: $state"
else
  fail "xdg-desktop-portal user service missing"
fi
if command -v xdg-desktop-portal >/dev/null 2>&1 \
   || [[ -x /run/current-system/sw/libexec/xdg-desktop-portal ]] \
   || [[ -x /run/current-system/sw/lib/xdg-desktop-portal/xdg-desktop-portal ]]; then
  pass "xdg-desktop-portal executable present"
else
  warn "xdg-desktop-portal executable not found in common locations"
fi

describe "gtk portal shipped alongside the base"
if find /run/current-system/sw /nix/store -maxdepth 3 -name 'xdg-desktop-portal-gtk*' 2>/dev/null | grep -q .; then
  pass "xdg-desktop-portal-gtk found"
else
  warn "xdg-desktop-portal-gtk not located on disk"
fi

describe "/var/lib/flatpak persisted via impermanence"
if [[ -L /var/lib/flatpak ]]; then
  target=$(readlink -f /var/lib/flatpak)
  if [[ "$target" == /persist/* ]]; then
    pass "/var/lib/flatpak is a symlink into $target"
  else
    warn "/var/lib/flatpak symlink target outside /persist: $target"
  fi
else
  # Could be a bind mount instead of a symlink
  if findmnt -n /var/lib/flatpak >/dev/null 2>&1; then
    pass "/var/lib/flatpak is a bind mount"
  else
    warn "/var/lib/flatpak is neither symlink nor bind mount (impermanence may not be wired)"
  fi
fi
