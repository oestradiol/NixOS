#!/usr/bin/env bash
# Static: storage-layout invariants.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd grep || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

storage="$REPO_ROOT/modules/core/storage-layout.nix"
base="$REPO_ROOT/modules/security/base.nix"
assert_file "$storage"
assert_file "$base"

describe "/ is tmpfs with adequate capacity"
assert_eq "$(nix_eval 'fileSystems./.fsType')" '"tmpfs"' "/ mount is tmpfs"
size_line=$(nix_eval 'fileSystems./.options' | jq_cmd -r '.[] | select(startswith("size="))' | head -1 || true)
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
assert_eq "$(nix_eval 'fileSystems./tmp.fsType')" '"tmpfs"' "/tmp is a dedicated tmpfs"
tmp_opts=$(nix_eval 'fileSystems./tmp.options')
if jq_cmd -e '. | index("nosuid")' <<<"$tmp_opts" >/dev/null 2>&1; then
  pass "/tmp mount carries nosuid"
else
  fail "/tmp mount missing nosuid (defense-in-depth)"
fi
if jq_cmd -e '. | index("nodev")' <<<"$tmp_opts" >/dev/null 2>&1; then
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

describe "storage module remains the implementation surface"
if grep -Fq 'options.myOS.storage' "$storage"; then
  pass "myOS.storage options are declared in the framework module"
else
  fail "myOS.storage options missing from storage-layout.nix"
fi

describe "reference profile home mounts stay structurally correct"
assert_eq "$(nix_eval_daily 'fileSystems./home/player.fsType')" '"btrfs"' "daily: player home is persistent btrfs"
assert_eq "$(nix_eval_daily 'fileSystems./persist/home/ghost.fsType')" 'null' "daily: ghost backing home is absent"
assert_eq "$(nix_eval 'fileSystems./home/player.fsType')" 'null' "paranoid: player home is absent"
assert_eq "$(nix_eval 'fileSystems./home/ghost.fsType')" '"tmpfs"' "paranoid: ghost home is tmpfs"
assert_eq "$(nix_eval 'fileSystems./persist/home/ghost.fsType')" '"btrfs"' "paranoid: ghost backing home is persistent btrfs"

describe "profile-mount-invariants script checks inactive mounts"
daily_script=$(nix_eval_daily 'systemd.services.profile-mount-invariants.script')
assert_contains "$daily_script" "! mountpoint -q /home/ghost || exit 1" "daily script forbids /home/ghost"
assert_contains "$daily_script" "! mountpoint -q /persist/home/ghost || exit 1" "daily script forbids /persist/home/ghost"
paranoid_script=$(nix_eval 'systemd.services.profile-mount-invariants.script')
assert_contains "$paranoid_script" "! mountpoint -q /home/player || exit 1" "paranoid script forbids /home/player"

describe "disk-backed swap is gated by myOS.storage.swap.enable"
assert_eq "$(nix_eval 'myOS.storage.swap.enable')" 'false' "paranoid: disk-backed swap disabled by default"
assert_eq "$(nix_eval_daily 'myOS.storage.swap.enable')" 'true' "daily: disk-backed swap enabled"
assert_eq "$(nix_eval 'fileSystems./swap.fsType')" 'null' "paranoid: /swap mount absent"
assert_eq "$(nix_eval_daily 'fileSystems./swap.fsType')" '"btrfs"' "daily: /swap mount present"
