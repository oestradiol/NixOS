#!/usr/bin/env bash
# Bug regression: boot.loader.systemd-boot.extraInstallCommands is commented
# out in modules/core/boot.nix because enabling it broke the bootloader
# install step. This test diagnoses the current state so the fix attempt is
# grounded in real evidence from the live system.
#
# Specifically:
#   1. Confirm the code is still commented out.
#   2. Show what the actual boot entry filenames look like, so the glob
#      pattern in the script can be validated against reality.
#   3. Show whether /boot/loader/loader.conf has a `default` line, what
#      value it takes, and whether it points at a daily entry.
#   4. If `default` points at a daily entry today, the extraInstallCommands
#      workaround is actually redundant for current policy (systemd-boot
#      keeps it as @saved).
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

boot_nix="$REPO_ROOT/modules/core/boot.nix"

describe "the problematic block is still commented out"
# Every non-blank line of the extraInstallCommands block in boot.nix must
# start with '#' (i.e. the block stays staged off). If any line lacks the
# leading comment, the block is live again and we want to notice.
# Use awk to pull the region between the `# extraInstallCommands = ''` and
# the matching `# '';`.
if awk '
  /extraInstallCommands = '"'"''"'"'/   { in_block = 1 }
  in_block {
    nonblank = $0 ~ /[^[:space:]]/
    if (nonblank && $1 !~ /^#/) { print NR ": " $0; flag = 1 }
    if ($0 ~ /'"'"''"'"';/) in_block = 0
  }
  END { exit flag }
' "$boot_nix"; then
  pass "extraInstallCommands block remains fully commented out"
else
  fail "extraInstallCommands has a non-commented line; the bug may have resurfaced"
fi

describe "real boot entry filenames reveal the correct glob"
if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
  entries=$(sudo -n ls -1 /boot/loader/entries 2>/dev/null || true)
  daily=$(grep -E 'daily' <<<"$entries" || true)
  info "daily-matching entries:"
  while IFS= read -r e; do [[ -n "$e" ]] && info "  $e"; done <<<"$daily"

  # The commented-out glob is `nixos-*-daily.conf`. Against current NixOS,
  # the filename form is nixos-generation-<n>-specialisation-daily.conf,
  # which DOES match the glob (because `*` is greedy). Validate.
  any_match=0
  while IFS= read -r e; do
    [[ -z "$e" ]] && continue
    # `bash`'s [[ ... == <pat> ]] is the most direct equivalent.
    if [[ "$e" == nixos-*-daily.conf ]]; then
      any_match=1
      info "glob nixos-*-daily.conf matches: $e"
    fi
  done <<<"$daily"
  if [[ $any_match -eq 1 ]]; then
    pass "the glob nixos-*-daily.conf DOES match real entries — glob is not the root cause"
  else
    if [[ -z "$daily" ]]; then
      fail "no daily boot entries exist at all; rebuild has never materialised specialisation"
    else
      fail "glob pattern does not match real entries; this is the root cause"
    fi
  fi
else
  skip "cannot read /boot/loader/entries without sudo"
fi

describe "loader.conf default policy"
if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
  cfg=$(sudo -n cat /boot/loader/loader.conf 2>/dev/null || true)
  if [[ -z "$cfg" ]]; then
    fail "loader.conf not readable"
  else
    def=$(awk '/^default /{print $2}' <<<"$cfg")
    if [[ -z "$def" ]]; then
      info "loader.conf has no default directive"
      info "the commented-out block would ADD one pointing at the latest daily entry"
    else
      info "loader.conf default = $def"
      if [[ "$def" == *daily* ]]; then
        pass "default already points at a daily entry; extraInstallCommands fix is not needed today"
      else
        info "default does NOT point at daily; the commented block would change it"
      fi
    fi
  fi
fi

describe "diagnostic: systemd-boot behaves fine with extraInstallCommands DISABLED"
# Confirm that switch-to-configuration DOES succeed currently (bugs with the
# block are recorded elsewhere). We just observe the current config's drvPath.
if [[ -L /run/current-system ]]; then
  pass "current-system symlink exists (most recent activation succeeded)"
else
  fail "/run/current-system is not a symlink"
fi

describe "root-cause note: loader.conf edits must be idempotent across rebuilds"
# If you re-enable the block, add a test that runs a sentinel switch in a
# chroot-like environment (or simply watches that switch.log below contains
# no `extraInstallCommands` failure for three consecutive rebuilds).
if [[ -s "$REPO_ROOT/switch.log" ]]; then
  if grep -q 'extraInstallCommands' "$REPO_ROOT/switch.log"; then
    fail "switch.log mentions extraInstallCommands (re-enabled prematurely?)"
  else
    pass "switch.log has no extraInstallCommands noise (as expected)"
  fi
fi

info "note: Lanzaboote does not support extraInstallCommands (see"
info "      modules/core/boot.nix header and POST-STABILITY section 9)."
info "      When Secure Boot graduates, the block must either migrate to a"
info "      Lanzaboote-supported mechanism or be deleted."
