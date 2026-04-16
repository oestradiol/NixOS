#!/usr/bin/env bash
# Static: filesystem layout invariants.
#
# History: the original design used a 4G tmpfs for / and inherited /tmp from /.
# That cap was empirically too small for a KDE Plasma 6 + Windsurf + VR +
# Spotify session; once /tmp filled, /var/lib writes started failing and
# home-manager activation silently dropped the user-profile symlink target.
#
# Current policy:
#   - / on tmpfs, size capped (currently 16G, never less than 8G)
#   - /tmp on its own tmpfs so a /tmp spike cannot starve /var/lib, /run, /root
#   - /tmp mount is nosuid + nodev (defense-in-depth)
#   - boot.tmp.cleanOnBoot must stay true (wipe session cruft on boot)
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd grep || exit 0

fs="$REPO_ROOT/hosts/nixos/fs-layout.nix"
base="$REPO_ROOT/modules/security/base.nix"
assert_file "$fs"
assert_file "$base"

describe "/ is tmpfs with adequate capacity"
if grep -Eq 'fileSystems\."/"\s*=\s*\{' "$fs"; then
  pass "/ mount is declared"
else
  fail "/ mount is not declared"
fi
# Parse size= from the options list. Accept 8G, 16G, 32G, etc., reject 4G.
size_line=$(awk '/fileSystems\."\/"\s*=/,/\};/' "$fs" | grep -oE 'size=[0-9]+[GM]' | head -1 || true)
if [[ -z "$size_line" ]]; then
  fail "/ tmpfs size is not declared"
else
  num=$(echo "$size_line" | sed -E 's/size=([0-9]+).*/\1/')
  unit=$(echo "$size_line" | sed -E 's/size=[0-9]+([GM])/\1/')
  case "$unit" in
    G) size_mb=$(( num * 1024 )) ;;
    M) size_mb=$num ;;
    *) size_mb=0 ;;
  esac
  if (( size_mb >= 8192 )); then
    pass "/ tmpfs $size_line (>= 8G)"
  else
    fail "/ tmpfs $size_line is below the 8G floor" \
      "see: tests/runtime/010-system-health.sh for the live-state check"
  fi
fi

describe "/tmp has its own tmpfs"
# The /tmp split prevents a /tmp spike from starving the rest of the tmpfs root.
if awk '/fileSystems\."\/tmp"\s*=/,/\};/' "$fs" | grep -q 'fsType = "tmpfs"'; then
  pass "/tmp is a dedicated tmpfs"
else
  fail "/tmp is NOT a dedicated tmpfs — any /tmp spike will fill the root fs"
fi
if awk '/fileSystems\."\/tmp"\s*=/,/\};/' "$fs" | grep -q 'nosuid'; then
  pass "/tmp mount carries nosuid"
else
  fail "/tmp mount missing nosuid (defense-in-depth)"
fi
if awk '/fileSystems\."\/tmp"\s*=/,/\};/' "$fs" | grep -q 'nodev'; then
  pass "/tmp mount carries nodev"
else
  fail "/tmp mount missing nodev (defense-in-depth)"
fi

describe "boot.tmp.cleanOnBoot stays true"
if grep -Eq 'boot\.tmp\.cleanOnBoot\s*=\s*true' "$base"; then
  pass "boot.tmp.cleanOnBoot = true"
else
  fail "boot.tmp.cleanOnBoot must be true — without it /tmp accumulates across boots"
fi

describe "profile subvolumes stay declared"
# The dual home Btrfs subvolumes + swap subvol must keep their names stable.
for sv in '@home-daily' '@home-paranoid' '@persist' '@nix' '@log'; do
  if grep -Fq "$sv" "$fs"; then
    pass "Btrfs subvol declared: $sv"
  else
    fail "Btrfs subvol missing from fs-layout: $sv"
  fi
done
