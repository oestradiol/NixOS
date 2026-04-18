#!/usr/bin/env bash
# Runtime: AIDE integrity monitoring (config, service, DB, persistence).
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "aide binary present"
if command -v aide >/dev/null 2>&1; then
  pass "aide in PATH"
else
  fail "aide missing from PATH"
fi

describe "/etc/aide.conf contents match policy"
if [[ -r /etc/aide.conf ]]; then
  pass "/etc/aide.conf readable"
  # Must include boot chain + profile links + persisted identity surfaces.
  required=(
    "database=file:/var/lib/aide/aide.db.gz"
    "database_out=file:/var/lib/aide/aide.db.new.gz"
    "/boot R"
    "/nix/var/nix/profiles R"
    "/persist/etc/passwd R"
    "/persist/etc/group R"
    "/persist/etc/shadow R"
    "/persist/etc/machine-id R"
    "/persist/etc/ssh R"
    "/persist/etc/NetworkManager/system-connections R"
    "/persist/var/lib/nixos R"
    "/persist/var/lib/aide R"
    "/persist/var/lib/sbctl R"
  )
  for r in "${required[@]}"; do
    if grep -Fq "$r" /etc/aide.conf; then
      pass "aide.conf watches: $r"
    else
      fail "aide.conf missing entry: $r"
    fi
  done
  # Must NOT include noisy home/app/log trees.
  forbidden=(
    "/home/player "
    "/home/ghost "
    "/var/log "
    "/tmp "
    "/var/tmp "
  )
  for f in "${forbidden[@]}"; do
    if grep -Fq "$f" /etc/aide.conf; then
      fail "aide.conf watches noisy path: $f"
    else
      pass "aide.conf excludes noisy path: $f"
    fi
  done
else
  fail "/etc/aide.conf missing or unreadable"
fi

describe "aide services gated behind myOS.security.scanners.aide.enable"
# With enable=true (default) service + timer must exist.
assert_unit_exists aide-daily-check.service
assert_unit_exists aide-daily-check.timer
assert_unit_enabled aide-daily-check.timer

describe "aide database directory persisted"
# modules/security/impermanence.nix persists /var/lib/aide
if [[ -L /var/lib/aide ]]; then
  target=$(readlink -f /var/lib/aide)
  if [[ "$target" == /persist/* ]]; then
    pass "/var/lib/aide symlinks to $target"
  else
    warn "/var/lib/aide -> $target (outside /persist)"
  fi
elif findmnt -n /var/lib/aide >/dev/null 2>&1; then
  pass "/var/lib/aide is a bind mount"
else
  warn "/var/lib/aide neither symlinked nor bind-mounted; impermanence may not be wired"
fi

describe "aide database initialization status"
if [[ -r /var/lib/aide/aide.db.gz ]] || sudo -n test -r /var/lib/aide/aide.db.gz 2>/dev/null; then
  pass "aide.db.gz present (initialized)"
else
  warn "aide.db.gz not present — run \`sudo aide --init\` before expecting checks to succeed"
fi

describe "aide timer cadence (weekly)"
if systemctl cat aide-daily-check.timer 2>/dev/null | grep -qE 'OnUnitActiveSec=(1w|7d|168h|604800)'; then
  pass "aide-daily-check.timer cadence = weekly"
else
  fail "aide-daily-check.timer cadence drift"
fi
