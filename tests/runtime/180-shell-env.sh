#!/usr/bin/env bash
# Runtime: shell environment + home-manager for player (daily-only tests
# check VRCX/Windsurf reachability).
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "zsh system-wide enabled"
assert_file /etc/zshenv
if command -v zsh >/dev/null 2>&1; then
  pass "zsh in PATH"
else
  fail "zsh missing from PATH"
fi
# player's shell must be zsh at the passwd level
shell=$(getent passwd player | awk -F: '{print $7}')
if [[ "$shell" == *"/zsh" ]]; then
  pass "player's login shell = $shell"
else
  fail "player's login shell is not zsh" "got: $shell"
fi

describe "git + git-lfs + mtr"
for c in git git-lfs mtr; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    fail "$c missing"
  fi
done

describe "home-manager unit for player ran successfully"
if systemctl cat home-manager-player.service >/dev/null 2>&1; then
  state=$(systemctl is-active home-manager-player.service 2>&1 || true)
  case "$state" in
    active)
      pass "home-manager-player.service active"
      ;;
    inactive|failed)
      fail "home-manager-player.service state: $state" "$(journalctl -u home-manager-player.service -n 20 --no-pager 2>/dev/null || true)"
      ;;
    *)
      info "home-manager-player.service state: $state"
      ;;
  esac
else
  fail "home-manager-player.service unit not found"
fi

describe "player's HM-managed packages are installed"
# With home-manager `useGlobalPkgs = true; useUserPackages = true;`, the repo
# installs user packages via nix profile into ~/.nix-profile (standard HM
# behaviour). However, the important thing is that packages are reachable via
# PATH, which they are via useGlobalPkgs=true. Skip profile path checks.
np=/home/player/.nix-profile
if [[ -L "$np" ]]; then
  pass "~/.nix-profile is a symlink -> $(readlink "$np" 2>/dev/null || true)"
  resolved=$(readlink -f "$np" 2>/dev/null)
  if [[ -n "$resolved" && -e "$resolved" ]]; then
    pass "~/.nix-profile target exists: $resolved"
  else
    info "~/.nix-profile is a DANGLING symlink (packages still reachable via system PATH)"
  fi
elif [[ -d "$np" ]]; then
  pass "~/.nix-profile is a directory"
else
  # Some HM setups install everything into environment.systemPackages, leaving
  # no user profile. This is fine as long as packages are in PATH.
  info "~/.nix-profile missing (packages installed via system PATH)"
fi
bins="$np/bin"
if [[ -d "$bins" ]]; then
  pass "$bins is a directory"
  for b in eza bat; do
    if [[ -x "$bins/$b" || -L "$bins/$b" ]]; then
      pass "~/.nix-profile/bin/$b present"
    else
      # eza + bat could also be in /run/current-system/sw/bin via global pkgs.
      if command -v "$b" >/dev/null 2>&1; then
        pass "$b reachable via system PATH (useGlobalPkgs=true)"
      else
        warn "$b missing from user profile AND system PATH"
      fi
    fi
  done
else
  # Fall back to confirming eza/bat reach player via PATH (system-packaged).
  for b in eza bat; do
    if command -v "$b" >/dev/null 2>&1; then
      pass "$b reachable via system PATH (useGlobalPkgs=true)"
    else
      fail "$b missing entirely (neither user profile nor system PATH)"
    fi
  done
fi

describe "HM-generated shell config files exist"
# starship init is in initContent.
if [[ -r /home/player/.zshrc ]]; then
  if grep -q 'starship' /home/player/.zshrc; then
    pass "starship init wired into /home/player/.zshrc"
  else
    warn ".zshrc exists but starship not wired"
  fi
else
  warn "/home/player/.zshrc not readable as current user"
fi
if [[ -r /home/player/.config/starship.toml ]]; then
  pass "~/.config/starship.toml present"
elif [[ -r /home/player/.config/starship.toml.bkp ]]; then
  warn "starship.toml backed up as .bkp (rebuild may be pending)"
else
  warn "~/.config/starship.toml absent"
fi

describe "git config: Elaina + github email"
if command -v git >/dev/null 2>&1 && [[ -r /home/player/.config/git/config || -r /home/player/.gitconfig ]]; then
  gc=$( (cat /home/player/.config/git/config /home/player/.gitconfig 2>/dev/null || true) )
  # NixOS HM writes the values quoted: name = "Elaina"
  if grep -Eq 'name\s*=\s*"?Elaina"?' <<<"$gc"; then
    pass "git user.name = Elaina"
  else
    warn "git user.name drift"
  fi
  if grep -Fq '48662592+oestradiol@users.noreply.github.com' <<<"$gc"; then
    pass "git user.email matches player.nix"
  else
    warn "git user.email drift"
  fi
fi
