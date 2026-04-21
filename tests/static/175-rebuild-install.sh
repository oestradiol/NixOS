#!/usr/bin/env bash
# Static: installer script must be flake-aware rather than repo-hardcoded.
source "${BASH_SOURCE%/*}/../lib/common.sh"

script="$REPO_ROOT/scripts/rebuild-install.sh"
assert_file "$script"

content=$(<"$script")

describe "installer selects flake, config, and framework template dynamically"
assert_contains "$content" 'prompt_required "Target flake path or URL"' "installer prompts for target flake ref"
assert_contains "$content" 'prompt_required "Framework template path"' "installer prompts for framework template path"
assert_contains "$content" 'prompt_required "nixosConfiguration attribute"' "installer prompts for nixosConfiguration attr"
assert_contains "$content" 'nix_cmd flake metadata --json --no-write-lock-file' "installer reads flake metadata read-only"
assert_contains "$content" 'nix_cmd eval --impure --json --no-write-lock-file' "installer evaluates config read-only"

describe "installer derives storage and passwords from evaluated config"
assert_contains "$content" 'passwordHashEntries' "installer reads discovered hashedPasswordFile entries"
assert_contains "$content" 'cfg.myOS.storage' "installer reads myOS.storage from evaluated config"
assert_contains "$content" 'prompt_required "EFI partition device"' "installer prompts for EFI partition"
assert_contains "$content" 'prompt_required "Encrypted root partition device"' "installer prompts for encrypted root partition"

describe "installer no longer hardcodes the maintainer repo or account names"
assert_not_contains "$content" 'https://github.com/oestradiol/NixOS.git' "no blind GitHub clone bootstrap"
assert_not_contains "$content" 'player-password.hash' "no hardcoded player hash path"
assert_not_contains "$content" 'ghost-password.hash' "no hardcoded ghost hash path"
assert_not_contains "$content" 'templates/default/' "no fixed template path assumption in installer logic"
