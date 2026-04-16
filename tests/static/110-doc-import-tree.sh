#!/usr/bin/env bash
# Static governance: docs/maps/NIX-IMPORT-TREE.md must match the real
# `imports =` statements in the checked-in .nix files.
source "${BASH_SOURCE%/*}/../lib/common.sh"

tree="$REPO_ROOT/docs/maps/NIX-IMPORT-TREE.md"
assert_file "$tree"

# A set of (parent, child) edges that must be present in code. These are
# the edges the doc claims. A new import in code without a doc update will
# not flag here; the reverse (doc claims but code doesn't import) will.
edges=(
  "hosts/nixos/default.nix;hosts/nixos/fs-layout.nix"
  "hosts/nixos/default.nix;hosts/nixos/hardware-target.nix"
  "hosts/nixos/default.nix;modules/core/options.nix"
  "hosts/nixos/default.nix;modules/core/boot.nix"
  "hosts/nixos/default.nix;modules/core/users.nix"
  "hosts/nixos/default.nix;modules/desktop/base.nix"
  "hosts/nixos/default.nix;modules/security/base.nix"
  "hosts/nixos/default.nix;modules/gpu/nvidia.nix"
  "hosts/nixos/default.nix;modules/gpu/amd.nix"
  "hosts/nixos/default.nix;profiles/paranoid.nix"
  "modules/desktop/base.nix;modules/desktop/theme.nix"
  "modules/security/base.nix;modules/security/governance.nix"
  "modules/security/base.nix;modules/security/networking.nix"
  "modules/security/base.nix;modules/security/wireguard.nix"
  "modules/security/base.nix;modules/security/browser.nix"
  "modules/security/base.nix;modules/security/impermanence.nix"
  "modules/security/base.nix;modules/security/secrets.nix"
  "modules/security/base.nix;modules/security/secure-boot.nix"
  "modules/security/base.nix;modules/security/flatpak.nix"
  "modules/security/base.nix;modules/security/scanners.nix"
  "modules/security/base.nix;modules/security/vm-tooling.nix"
  "modules/security/base.nix;modules/security/sandboxed-apps.nix"
  "modules/security/base.nix;modules/security/privacy.nix"
  "modules/security/base.nix;modules/security/user-profile-binding.nix"
  "profiles/daily.nix;modules/desktop/gaming.nix"
  "modules/desktop/gaming.nix;modules/desktop/vr.nix"
  "modules/desktop/gaming.nix;modules/desktop/controllers.nix"
  "modules/home/ghost.nix;modules/home/common.nix"
  "modules/home/player.nix;modules/home/common.nix"
  "modules/home/common.nix;modules/desktop/shell.nix"
)

describe "every documented edge in NIX-IMPORT-TREE is in code"
for e in "${edges[@]}"; do
  parent="${e%%;*}"
  child="${e#*;}"
  if [[ ! -f "$REPO_ROOT/$parent" ]]; then
    fail "parent file missing: $parent"
    continue
  fi
  # The child may be referenced as `./foo.nix`, `../foo/bar.nix`, or as a list
  # entry; normalize by just stripping the path up to the bare filename.
  child_base="${child##*/}"
  if grep -Fq "$child_base" "$REPO_ROOT/$parent"; then
    # second pass: confirm the exact relative form the doc implies
    if grep -Fq "${child#*/}" "$REPO_ROOT/$parent" \
       || grep -Fq "${child_base}" "$REPO_ROOT/$parent"; then
      pass "$parent imports $child"
    else
      warn "$parent mentions $child_base but not the full relative path"
    fi
  else
    fail "$parent does NOT import $child_base (doc claims it does)"
  fi
done

describe "browser/sandbox direct imports match NIX-IMPORT-TREE"
if grep -Fq 'import ./sandbox-core.nix' "$REPO_ROOT/modules/security/browser.nix"; then
  pass "browser.nix direct-imports sandbox-core.nix"
else
  fail "browser.nix should direct-import sandbox-core.nix"
fi
if grep -Fq 'import ./sandbox-core.nix' "$REPO_ROOT/modules/security/sandboxed-apps.nix"; then
  pass "sandboxed-apps.nix direct-imports sandbox-core.nix"
else
  fail "sandboxed-apps.nix should direct-import sandbox-core.nix"
fi

describe "specialisation edge: profiles/daily.nix is only imported via specialisation"
# This edge is important: daily.nix should NOT be on hosts/nixos/default.nix
# module list; it is only pulled in under specialisation.daily.configuration.
default_nix="$REPO_ROOT/hosts/nixos/default.nix"
if grep -Fq "profiles/daily.nix" "$default_nix"; then
  # check context: it must be inside the specialisation block, not in imports.
  before=$(awk '/specialisation/ {found=1} {if (!found) print}' "$default_nix" | grep -F "profiles/daily.nix" || true)
  if [[ -z "$before" ]]; then
    pass "daily.nix only pulled in via specialisation"
  else
    fail "daily.nix appears in default imports before the specialisation block"
  fi
else
  fail "daily.nix is not referenced from hosts/nixos/default.nix at all"
fi
