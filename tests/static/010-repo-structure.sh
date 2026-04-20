#!/usr/bin/env bash
# Static: repo structure sanity. Required files from the truth-surface list
# in README.md, the pipeline docs, and the maps. These are the files the
# governance model assumes exist.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "repo top-level files"
for f in \
    "$REPO_ROOT/README.md" \
    "$REPO_ROOT/docs/governance/PROJECT-STATE.md" \
    "$REPO_ROOT/docs/governance/REFERENCES.md" \
    "$REPO_ROOT/LICENSE" \
    "$REPO_ROOT/flake.nix" \
    "$REPO_ROOT/flake.lock" \
    "$REPO_ROOT/.gitignore"; do
  assert_file "$f"
done

describe "templates"
for f in \
    "$REPO_ROOT/templates/workstation/flake.nix" \
    "$REPO_ROOT/templates/workstation/README.md" \
    "$REPO_ROOT/templates/default/flake.nix"; do
  assert_file "$f"
done

describe "host entrypoint and fs/hardware layouts (templates/default)"
for f in \
    "$REPO_ROOT/templates/default/hosts/nixos/default.nix" \
    "$REPO_ROOT/templates/default/hosts/nixos/fs-layout.nix" \
    "$REPO_ROOT/templates/default/hosts/nixos/hardware-target.nix"; do
  assert_file "$f"
done

describe "profiles"
for f in \
    "$REPO_ROOT/profiles/daily.nix" \
    "$REPO_ROOT/profiles/paranoid.nix"; do
  assert_file "$f"
done

describe "core modules"
for f in \
    "$REPO_ROOT/modules/core/boot.nix" \
    "$REPO_ROOT/modules/core/options.nix" \
    "$REPO_ROOT/modules/core/users.nix"; do
  assert_file "$f"
done

describe "desktop modules"
for f in \
    "$REPO_ROOT/modules/desktop/base.nix" \
    "$REPO_ROOT/modules/desktop/controllers.nix" \
    "$REPO_ROOT/modules/desktop/gaming.nix" \
    "$REPO_ROOT/modules/desktop/theme.nix" \
    "$REPO_ROOT/modules/desktop/vr.nix"; do
  assert_file "$f"
done

describe "gpu modules"
for f in \
    "$REPO_ROOT/modules/gpu/amd.nix" \
    "$REPO_ROOT/modules/gpu/nvidia.nix"; do
  assert_file "$f"
done

describe "home manager modules"
for f in \
    "$REPO_ROOT/modules/home/common.nix" \
    "$REPO_ROOT/modules/home/shell.nix"; do
  assert_file "$f"
done

describe "template account home configs"
for f in \
    "$REPO_ROOT/templates/default/accounts/home/ghost.nix" \
    "$REPO_ROOT/templates/default/accounts/home/player.nix"; do
  assert_file "$f"
done

describe "security modules (fifteen files per NIX-IMPORT-TREE)"
for f in \
    base.nix browser.nix flatpak.nix governance.nix impermanence.nix \
    networking.nix privacy.nix sandbox-core.nix sandboxed-apps.nix \
    scanners.nix secrets.nix secure-boot.nix user-profile-binding.nix \
    vm-tooling.nix wireguard.nix; do
  assert_file "$REPO_ROOT/modules/security/$f"
done
assert_file "$REPO_ROOT/modules/security/arkenfox/user.js"

describe "docs: pipeline"
for f in \
    "$REPO_ROOT/docs/pipeline/INSTALL-GUIDE.md" \
    "$REPO_ROOT/docs/pipeline/TEST-PLAN.md" \
    "$REPO_ROOT/docs/pipeline/RECOVERY.md" \
    "$REPO_ROOT/docs/pipeline/POST-STABILITY.md"; do
  assert_file "$f"
done

describe "docs: maps"
for f in \
    "$REPO_ROOT/docs/maps/AUDIT-STATUS.md" \
    "$REPO_ROOT/docs/maps/FEATURES.md" \
    "$REPO_ROOT/docs/maps/HARDENING-TRACKER.md" \
    "$REPO_ROOT/docs/maps/PROFILE-POLICY.md" \
    "$REPO_ROOT/docs/maps/SECURITY-SURFACES.md" \
    "$REPO_ROOT/docs/maps/SOURCE-COVERAGE.md"; do
  assert_file "$f"
done

describe "scripts"
for f in \
    "$REPO_ROOT/scripts/README.md" \
    "$REPO_ROOT/scripts/audit-tutorial.sh" \
    "$REPO_ROOT/scripts/post-install-secureboot-tpm.sh" \
    "$REPO_ROOT/scripts/rebuild-install.sh"; do
  assert_file "$f"
done
# remount.sh is tracked as a helper too
assert_file "$REPO_ROOT/scripts/remount.sh"

describe "no stray per-user override layer (governance rule)"
# INSTALL-GUIDE says edits happen in canonical files; a private-overrides.nix
# or user-overrides.nix is a red flag.
stray=$(find "$REPO_ROOT" -maxdepth 2 -type f \
    \( -name 'private-overrides.nix' -o -name 'user-overrides.nix' \
       -o -name 'local.nix' \) 2>/dev/null || true)
if [[ -z "$stray" ]]; then
  pass "no stray override files"
else
  fail "stray override files present" "$stray"
fi
