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

describe "profile home mounts are structurally correct (template-agnostic)"
# Discover users from the framework's myOS.users configuration
user_names_json=$(nix_eval 'myOS.users.__names')
if [[ "$user_names_json" == "null" || "$user_names_json" == "[]" ]]; then
  fail "no users declared in myOS.users"
  exit 1
fi

# For each user, verify their home mount matches their persistence configuration
mapfile -t all_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
for u in "${all_users[@]}"; do
  active_paranoid=$(nix_eval "myOS.users.${u}._activeOn")
  active_daily=$(nix_eval_daily "myOS.users.${u}._activeOn")
  persistent=$(nix_eval "myOS.users.${u}.home.persistent")

  # Check paranoid profile mount state
  if [[ "$active_paranoid" == "true" ]]; then
    # User is active on paranoid - their home should be mounted
    fs_type=$(nix_eval "fileSystems./home/${u}.fsType")
    if [[ "$persistent" == "true" ]]; then
      assert_eq "$fs_type" '"btrfs"' "paranoid: ${u} home (persistent) is btrfs"
    else
      assert_eq "$fs_type" '"tmpfs"' "paranoid: ${u} home (tmpfs) is tmpfs"
      # Check backing store for tmpfs homes
      backing=$(nix_eval "fileSystems./persist/home/${u}.fsType")
      assert_eq "$backing" '"btrfs"' "paranoid: ${u} backing home is persistent btrfs"
    fi
  else
    # User is inactive on paranoid - their home should be absent
    fs_type=$(nix_eval "fileSystems./home/${u}.fsType")
    assert_eq "$fs_type" 'null' "paranoid: ${u} home is absent (inactive)"
  fi

  # Check daily profile mount state
  if [[ "$active_daily" == "true" ]]; then
    fs_type_daily=$(nix_eval_daily "fileSystems./home/${u}.fsType")
    # Daily typically has persistent homes for active users
    if [[ "$persistent" == "true" ]]; then
      assert_eq "$fs_type_daily" '"btrfs"' "daily: ${u} home (persistent) is btrfs"
    fi
  else
    # User inactive on daily - backing home should be absent if it's a tmpfs user
    if [[ "$persistent" == "false" ]]; then
      backing_daily=$(nix_eval_daily "fileSystems./persist/home/${u}.fsType")
      assert_eq "$backing_daily" 'null' "daily: ${u} backing home is absent (tmpfs user inactive)"
    fi
  fi
done
pass "home mount structure validated for all users"

describe "profile-mount-invariants script checks inactive mounts"
daily_script=$(nix_eval_daily 'systemd.services.profile-mount-invariants.script')
paranoid_script=$(nix_eval 'systemd.services.profile-mount-invariants.script')

# Verify scripts check for inactive users on each profile
for u in "${all_users[@]}"; do
  active_paranoid=$(nix_eval "myOS.users.${u}._activeOn")
  active_daily=$(nix_eval_daily "myOS.users.${u}._activeOn")

  if [[ "$active_daily" != "true" ]]; then
    # User inactive on daily - daily script should forbid their home
    if [[ "$daily_script" == *"! mountpoint -q /home/${u}"* ]]; then
      pass "daily script forbids /home/${u} (inactive user)"
    else
      fail "daily script missing check for inactive user /home/${u}"
    fi
  fi

  if [[ "$active_paranoid" != "true" ]]; then
    # User inactive on paranoid - paranoid script should forbid their home
    if [[ "$paranoid_script" == *"! mountpoint -q /home/${u}"* ]]; then
      pass "paranoid script forbids /home/${u} (inactive user)"
    else
      fail "paranoid script missing check for inactive user /home/${u}"
    fi
  fi
done

describe "disk-backed swap is gated by myOS.storage.swap.enable"
assert_eq "$(nix_eval 'myOS.storage.swap.enable')" 'false' "paranoid: disk-backed swap disabled by default"
assert_eq "$(nix_eval_daily 'myOS.storage.swap.enable')" 'true' "daily: disk-backed swap enabled"
assert_eq "$(nix_eval 'fileSystems./swap.fsType')" 'null' "paranoid: /swap mount absent"
assert_eq "$(nix_eval_daily 'fileSystems./swap.fsType')" '"btrfs"' "daily: /swap mount present"
