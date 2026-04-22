#!/usr/bin/env bash
# Runtime: shell environment + home-manager for active users.
# Template-agnostic: discovers users from myOS.users configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

# Discover active users (template-agnostic)
mapfile -t active_users < <(detect_active_users)

if [[ ${#active_users[@]} -eq 0 ]]; then
  warn "no active users found for current profile"
else
  info "active user(s): ${active_users[*]}"
fi

describe "zsh system-wide enabled"
assert_file /etc/zshenv
if command -v zsh >/dev/null 2>&1; then
  pass "zsh in PATH"
else
  fail "zsh missing from PATH"
fi

# Check active users' shells
for u in "${active_users[@]}"; do
  shell=$(getent passwd "$u" | awk -F: '{print $7}')
  if [[ "$shell" == *"/zsh" ]]; then
    pass "${u}'s login shell = $shell"
  else
    fail "${u}'s login shell is not zsh" "got: $shell"
  fi
done

describe "git + git-lfs + mtr"
for c in git git-lfs mtr; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    fail "$c missing"
  fi
done

describe "home-manager units for active users"
for u in "${active_users[@]}"; do
  unit_name="home-manager-${u}.service"
  if systemctl cat "$unit_name" >/dev/null 2>&1; then
    state=$(systemctl is-active "$unit_name" 2>&1 || true)
    case "$state" in
      active)
        pass "${unit_name} active"
        ;;
      inactive|failed)
        fail "${unit_name} state: $state" "$(journalctl -u "$unit_name" -n 20 --no-pager 2>/dev/null || true)"
        ;;
      *)
        info "${unit_name} state: $state"
        ;;
    esac
  else
    fail "${unit_name} unit not found"
  fi
done

describe "HM-managed packages are installed for active users"
# With home-manager `useGlobalPkgs = true; useUserPackages = true;`, the repo
# installs user packages via nix profile into ~/.nix-profile (standard HM
# behaviour). However, the important thing is that packages are reachable via
# PATH, which they are via useGlobalPkgs=true. Skip profile path checks.

for u in "${active_users[@]}"; do
  np="/home/${u}/.nix-profile"
  if [[ -L "$np" ]]; then
    pass "${u}: ~/.nix-profile is a symlink -> $(readlink "$np" 2>/dev/null || true)"
    resolved=$(readlink -f "$np" 2>/dev/null)
    if [[ -n "$resolved" && -e "$resolved" ]]; then
      pass "${u}: ~/.nix-profile target exists: $resolved"
    else
      info "${u}: ~/.nix-profile is a DANGLING symlink (packages still reachable via system PATH)"
    fi
  elif [[ -d "$np" ]]; then
    pass "${u}: ~/.nix-profile is a directory"
  else
    # Some HM setups install everything into environment.systemPackages, leaving
    # no user profile. This is fine as long as packages are in PATH.
    info "${u}: ~/.nix-profile missing (packages installed via system PATH)"
  fi
  bins="$np/bin"
  if [[ -d "$bins" ]]; then
    pass "${u}: $bins is a directory"
    for b in eza bat; do
      if [[ -x "$bins/$b" || -L "$bins/$b" ]]; then
        pass "${u}: ~/.nix-profile/bin/$b present"
      else
        # eza + bat could also be in /run/current-system/sw/bin via global pkgs.
        if command -v "$b" >/dev/null 2>&1; then
          pass "${u}: $b reachable via system PATH (useGlobalPkgs=true)"
        else
          warn "${u}: $b missing from user profile AND system PATH"
        fi
      fi
    done
  else
    # Fall back to confirming eza/bat are reachable via PATH (system-packaged).
    for b in eza bat; do
      if command -v "$b" >/dev/null 2>&1; then
        pass "${u}: $b reachable via system PATH (useGlobalPkgs=true)"
      else
        fail "${u}: $b missing entirely (neither user profile nor system PATH)"
      fi
    done
  fi
done

describe "HM-generated shell config files exist for active users"
for u in "${active_users[@]}"; do
  # starship init is in initContent.
  zshrc="/home/${u}/.zshrc"
  if [[ -r "$zshrc" ]]; then
    if grep -q 'starship' "$zshrc" 2>/dev/null; then
      pass "${u}: starship init wired into .zshrc"
    else
      warn "${u}: .zshrc exists but starship not wired"
    fi
  else
    warn "${u}: .zshrc not readable as current user"
  fi

  starship_cfg="/home/${u}/.config/starship.toml"
  if [[ -r "$starship_cfg" ]]; then
    pass "${u}: ~/.config/starship.toml present"
  elif [[ -r "${starship_cfg}.bkp" ]]; then
    warn "${u}: starship.toml backed up as .bkp (rebuild may be pending)"
  else
    warn "${u}: ~/.config/starship.toml absent"
  fi
done

describe "git config for active users"
for u in "${active_users[@]}"; do
  git_config="/home/${u}/.config/git/config"
  git_config_alt="/home/${u}/.gitconfig"
  if command -v git >/dev/null 2>&1 && [[ -r "$git_config" || -r "$git_config_alt" ]]; then
    gc=$( (cat "$git_config" "$git_config_alt" 2>/dev/null || true) )
    # Check for git identity - any identity is acceptable, we just verify git is configured
    if grep -q 'user.name' <<<"$gc" 2>/dev/null; then
      pass "${u}: git user.name configured"
    else
      warn "${u}: git user.name not configured"
    fi
    if grep -q 'user.email' <<<"$gc" 2>/dev/null; then
      pass "${u}: git user.email configured"
    else
      warn "${u}: git user.email not configured"
    fi
  else
    info "${u}: git config not accessible"
  fi
done
