#!/usr/bin/env bash
# Static: verify the computed kernel params for each profile match policy.
# Uses nix eval on boot.kernelParams, then intersects with HARDENING-TRACKER.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

p_params=$(nix_eval 'boot.kernelParams' | jq_cmd -r '.[]' 2>/dev/null || true)
d_params=$(nix_eval_daily 'boot.kernelParams' | jq_cmd -r '.[]' 2>/dev/null || true)

has() { grep -Fxq "$1" <<<"$2"; }

describe "kernel params shared by both profiles"
for token in \
  "randomize_kstack_offset=on" \
  "debugfs=off" \
  "slub_debug=FZP" \
  "page_poison=1" \
  "hash_pointers=always" \
  "slab_nomerge" \
  "init_on_alloc=1" \
  "page_alloc.shuffle=1" \
  "pti=on" \
  "vsyscall=none" \
  "nvidia_drm.modeset=1"; do
  if has "$token" "$p_params" && has "$token" "$d_params"; then
    pass "shared: $token"
  else
    fail "shared kernel param missing" "token: $token" "paranoid-has: $(has "$token" "$p_params" && echo yes || echo no)" "daily-has:    $(has "$token" "$d_params" && echo yes || echo no)"
  fi
done

describe "paranoid-only kernel params"
for token in \
  "init_on_free=1" \
  "nosmt=force" \
  "usbcore.authorized_default=2"; do
  if has "$token" "$p_params" && ! has "$token" "$d_params"; then
    pass "paranoid-only: $token"
  else
    fail "paranoid-only token misconfigured" "token: $token" "paranoid-has: $(has "$token" "$p_params" && echo yes || echo no)" "daily-has:    $(has "$token" "$d_params" && echo yes || echo no)"
  fi
done

describe "staged params are not present on either profile"
for token in \
  "oops=panic" \
  "module.sig_enforce=1"; do
  if ! has "$token" "$p_params" && ! has "$token" "$d_params"; then
    pass "staged param absent: $token"
  else
    fail "staged param leaked into baseline" "token: $token"
  fi
done

describe "gpu-conditional param"
for token in "nvidia_drm.modeset=1"; do
  if has "$token" "$p_params" && has "$token" "$d_params"; then
    pass "nvidia param present (both profiles currently target nvidia)"
  else
    fail "nvidia_drm.modeset=1 missing" "paranoid-has: $(has "$token" "$p_params" && echo yes || echo no)" "daily-has:    $(has "$token" "$d_params" && echo yes || echo no)"
  fi
done
