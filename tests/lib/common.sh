#!/usr/bin/env bash
# Shared helpers for the repo test suite. Sourced by every individual test
# script and by run.sh. Intentionally POSIX-ish where possible; real bash
# features only where they pay for themselves.
#
# Public API:
#   describe "<short phrase>"          declare the scope of the following block
#   pass "<msg>"                       record an ok result
#   fail "<msg>" [detail...]           record a failing result
#   skip "<msg>"                       record a skip (does not fail the file)
#   info "<msg>"                       neutral progress line
#   warn "<msg>"                       non-fatal anomaly
#   needs_sudo                         flag file as sudo-requiring (runner skips if --no-sudo)
#   needs_root                         flag file as requiring running as root
#   needs_profile {daily|paranoid}     flag file as profile-specific
#   assert_eq      actual expected msg
#   assert_ne      actual forbidden msg
#   assert_contains haystack needle msg
#   assert_match   regex subject msg
#   assert_file    path msg
#   assert_dir     path msg
#   assert_cmd     "command" msg       runs the command, passes if exit 0
#   assert_not_cmd "command" msg       runs the command, passes if exit != 0
#   assert_service_active  unit msg
#   assert_service_inactive unit msg
#   assert_unit_enabled    unit msg
#   assert_kernel_param    key[=val]   checks /proc/cmdline / kernel-params
#   assert_sysctl          key value
#   assert_module_loaded   mod msg
#   assert_module_absent   mod msg
#   nix_eval "<attrpath>"              returns JSON of the attr path (paranoid config)
#   nix_eval_daily "<attrpath>"        returns JSON of the attr path (daily specialisation)
#   detect_profile                     prints "daily" or "paranoid" based on runtime state
#
# Output: TAP-ish lines on stdout so run.sh can tally without parsing exit codes.
# Assertion failures never abort the test; they record and continue. A test
# script exits 0 iff no assertion failed (skips are allowed).

set -u

# ── constants ─────────────────────────────────────────────────────────────
_tc_red=$'\033[1;31m'
_tc_green=$'\033[1;32m'
_tc_yellow=$'\033[1;33m'
_tc_blue=$'\033[1;34m'
_tc_magenta=$'\033[1;35m'
_tc_cyan=$'\033[1;36m'
_tc_dim=$'\033[2m'
_tc_reset=$'\033[0m'

if [[ ! -t 1 || "${NO_COLOR:-}" == 1 ]]; then
  _tc_red=; _tc_green=; _tc_yellow=; _tc_blue=
  _tc_magenta=; _tc_cyan=; _tc_dim=; _tc_reset=
fi

# ── state ─────────────────────────────────────────────────────────────────
_TC_FILE="${0##*/}"
_TC_PASS=0
_TC_FAIL=0
_TC_SKIP=0
_TC_WARN=0
_TC_CURRENT_DESC="(no describe)"
_TC_NEEDS_SUDO=0
_TC_NEEDS_ROOT=0
_TC_NEEDS_PROFILE=""

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)}"
export REPO_ROOT

# ── small printers ────────────────────────────────────────────────────────
_tc_print() {
  local kind="$1"; shift
  local msg="$*"
  case "$kind" in
    pass)
      printf '  %s✓%s %s\n' "$_tc_green" "$_tc_reset" "$msg"
      ;;
    fail)
      printf '  %s✗%s %s\n' "$_tc_red" "$_tc_reset" "$msg"
      ;;
    skip)
      printf '  %s~%s %s\n' "$_tc_yellow" "$_tc_reset" "$msg"
      ;;
    info)
      printf '  %s·%s %s\n' "$_tc_dim" "$_tc_reset" "$msg"
      ;;
    warn)
      printf '  %s!%s %s\n' "$_tc_magenta" "$_tc_reset" "$msg"
      ;;
    desc)
      printf '%s▸%s %s %s[%s]%s\n' "$_tc_cyan" "$_tc_reset" "$msg" "$_tc_dim" "$_TC_FILE" "$_tc_reset"
      ;;
  esac
}

describe() { _TC_CURRENT_DESC="$*"; _tc_print desc "$*"; }

pass() { _TC_PASS=$((_TC_PASS + 1)); _tc_print pass "$*"; }
fail() {
  _TC_FAIL=$((_TC_FAIL + 1))
  local head="$1"; shift || true
  _tc_print fail "$head"
  if [[ $# -gt 0 ]]; then
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && printf '      %s%s%s\n' "$_tc_dim" "$line" "$_tc_reset"
    done < <(printf '%s\n' "$*")
  fi
}
skip() { _TC_SKIP=$((_TC_SKIP + 1)); _tc_print skip "$*"; }
info() { _tc_print info "$*"; }
warn() { _TC_WARN=$((_TC_WARN + 1)); _tc_print warn "$*"; }

# ── requirements (runner reads env vars) ──────────────────────────────────
needs_sudo()    { _TC_NEEDS_SUDO=1;    export _TC_NEEDS_SUDO; }
needs_root()    { _TC_NEEDS_ROOT=1;    export _TC_NEEDS_ROOT; }
needs_profile() { _TC_NEEDS_PROFILE="$1"; export _TC_NEEDS_PROFILE; }

# ── helpers ───────────────────────────────────────────────────────────────
# require_cmd <name>: skip cleanly if the binary is missing.
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    skip "required command missing: $1"
    return 1
  fi
  return 0
}

# ── assertions ────────────────────────────────────────────────────────────
assert_eq() {
  local actual="$1" expected="$2" msg="${3:-assert_eq}"
  if [[ "$actual" == "$expected" ]]; then
    pass "$msg"
  else
    fail "$msg" "expected: $(printf '%q' "$expected")" "actual:   $(printf '%q' "$actual")"
  fi
}

assert_ne() {
  local actual="$1" forbidden="$2" msg="${3:-assert_ne}"
  if [[ "$actual" != "$forbidden" ]]; then
    pass "$msg"
  else
    fail "$msg" "forbidden value is present: $(printf '%q' "$actual")"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$msg"
  else
    fail "$msg" "missing substring: $(printf '%q' "$needle")" "in:               $(printf '%q' "$haystack")"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_not_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$msg"
  else
    fail "$msg" "forbidden substring present: $(printf '%q' "$needle")"
  fi
}

assert_match() {
  local regex="$1" subject="$2" msg="${3:-assert_match}"
  if [[ "$subject" =~ $regex ]]; then
    pass "$msg"
  else
    fail "$msg" "regex:   $regex" "subject: $subject"
  fi
}

assert_file() {
  local path="$1" msg="${2:-file exists: $1}"
  if [[ -f "$path" ]]; then pass "$msg"; else fail "$msg" "missing: $path"; fi
}

assert_dir() {
  local path="$1" msg="${2:-dir exists: $1}"
  if [[ -d "$path" ]]; then pass "$msg"; else fail "$msg" "missing dir: $path"; fi
}

assert_cmd() {
  local cmd="$1" msg="${2:-command succeeds: $1}"
  local out rc
  out=$(eval "$cmd" 2>&1); rc=$?
  if [[ $rc -eq 0 ]]; then
    pass "$msg"
  else
    fail "$msg" "rc=$rc" "$out"
  fi
}

assert_not_cmd() {
  local cmd="$1" msg="${2:-command fails: $1}"
  local out rc
  out=$(eval "$cmd" 2>&1); rc=$?
  if [[ $rc -ne 0 ]]; then
    pass "$msg"
  else
    fail "$msg" "expected non-zero exit but got 0" "$out"
  fi
}

assert_service_active() {
  local unit="$1" msg="${2:-service active: $1}"
  if systemctl is-active --quiet "$unit"; then
    pass "$msg"
  else
    local state; state=$(systemctl is-active "$unit" 2>&1 || true)
    fail "$msg" "state: $state"
  fi
}

assert_service_inactive() {
  local unit="$1" msg="${2:-service inactive: $1}"
  if ! systemctl is-active --quiet "$unit"; then
    pass "$msg"
  else
    fail "$msg" "unit is active when it should not be"
  fi
}

assert_unit_enabled() {
  local unit="$1" msg="${2:-unit enabled: $1}"
  local state; state=$(systemctl is-enabled "$unit" 2>&1 || true)
  case "$state" in
    enabled|enabled-runtime|static|alias|generated|linked|indirect|transient)
      pass "$msg ($state)"
      ;;
    *)
      fail "$msg" "is-enabled reports: $state"
      ;;
  esac
}

assert_unit_exists() {
  local unit="$1" msg="${2:-unit defined: $1}"
  if systemctl cat "$unit" >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg" "systemctl cat $unit failed"
  fi
}

# assert_kernel_param 'slab_nomerge' — matches bare token or key=value
assert_kernel_param() {
  local token="$1" msg="${2:-kernel param: $1}"
  local params; params=$(tr -s ' ' '\n' < /proc/cmdline)
  if [[ "$token" == *=* ]]; then
    local key=${token%%=*}
    if grep -Fxq "$token" <<<"$params"; then
      pass "$msg"
    else
      local cur; cur=$(grep "^${key}=" <<<"$params" || true)
      fail "$msg" "expected: $token" "got:      ${cur:-<absent>}"
    fi
  else
    if grep -Fxq "$token" <<<"$params"; then
      pass "$msg"
    else
      fail "$msg" "token not on /proc/cmdline"
    fi
  fi
}

assert_kernel_param_absent() {
  local token="$1" msg="${2:-kernel param absent: $1}"
  local params; params=$(tr -s ' ' '\n' < /proc/cmdline)
  local key=${token%%=*}
  if [[ "$token" == *=* ]]; then
    if grep -Fxq "$token" <<<"$params"; then
      fail "$msg" "forbidden token present: $token"
    else
      pass "$msg"
    fi
  else
    if grep -q "^${key}\\(=\\|$\\)" <<<"$params"; then
      fail "$msg" "forbidden token present: $token"
    else
      pass "$msg"
    fi
  fi
}

assert_sysctl() {
  local key="$1" want="$2" msg="${3:-sysctl $1 = $2}"
  local got
  if ! got=$(sysctl -n "$key" 2>/dev/null); then
    fail "$msg" "sysctl key not readable: $key"
    return
  fi
  # sysctl may return with leading/trailing whitespace for multi-valued keys
  got=$(printf '%s' "$got" | tr -s '[:space:]' ' ' | sed -e 's/^ //' -e 's/ $//')
  if [[ "$got" == "$want" ]]; then
    pass "$msg"
  else
    fail "$msg" "expected: $want" "actual:   $got"
  fi
}

assert_module_loaded() {
  local mod="$1" msg="${2:-module loaded: $1}"
  if lsmod 2>/dev/null | awk '{print $1}' | grep -Fxq "$mod"; then
    pass "$msg"
  else
    fail "$msg" "$mod is not currently loaded"
  fi
}

assert_module_absent() {
  local mod="$1" msg="${2:-module not loaded: $1}"
  if lsmod 2>/dev/null | awk '{print $1}' | grep -Fxq "$mod"; then
    fail "$msg" "forbidden module is loaded: $mod"
  else
    pass "$msg"
  fi
}

assert_mountpoint() {
  local path="$1" msg="${2:-mountpoint: $1}"
  if mountpoint -q "$path" 2>/dev/null; then
    pass "$msg"
  else
    fail "$msg" "$path is not a mount point"
  fi
}

assert_not_mountpoint() {
  local path="$1" msg="${2:-not a mountpoint: $1}"
  if mountpoint -q "$path" 2>/dev/null; then
    fail "$msg" "$path is unexpectedly a mount point"
  else
    pass "$msg"
  fi
}

# ── nix eval helpers (cached) ─────────────────────────────────────────────
#
# Each `nix eval` call takes ~10s because the flake evaluator has to
# parse every module and build the option graph. Running one call per
# attribute in a suite of 30+ attrs would take many minutes. Instead we
# pre-evaluate both profiles in a single call each, using the batch
# expression in `tests/lib/eval-cache.nix`, and cache the resulting JSON.
# Subsequent `nix_eval`/`nix_eval_daily` calls are instant `jq` lookups.
#
# Cache invalidation: the cache files are regenerated whenever any .nix
# file under the repo is newer than the cache. A user can also force a
# rebuild with TEST_CACHE_REBUILD=1.

TC_CACHE_DIR="${TC_CACHE_DIR:-$REPO_ROOT/tests/.cache}"
mkdir -p "$TC_CACHE_DIR" 2>/dev/null || true

_tc_jq=""
_tc_ensure_jq() {
  if [[ -n "$_tc_jq" ]]; then return 0; fi
  if command -v jq >/dev/null 2>&1; then
    _tc_jq=$(command -v jq); return 0
  fi
  # Nix shell fallback. `nix shell` builds the binary on first use then caches.
  if command -v nix >/dev/null 2>&1; then
    local got
    got=$(nix --extra-experimental-features 'nix-command flakes' \
            shell nixpkgs#jq --command bash -c 'command -v jq' 2>/dev/null || true)
    if [[ -n "$got" && -x "$got" ]]; then
      _tc_jq="$got"
      return 0
    fi
  fi
  return 1
}

# Compute the cache-newer-than-any-.nix check. Returns 0 if stale.
_tc_cache_stale() {
  local cache="$1"
  [[ "${TEST_CACHE_REBUILD:-0}" == "1" ]] && return 0
  [[ -s "$cache" ]] || return 0
  local newest
  newest=$(find "$REPO_ROOT" \
    -path "$REPO_ROOT/tests" -prune -o \
    -path "$REPO_ROOT/.git"   -prune -o \
    -type f \( -name '*.nix' -o -name 'flake.lock' \) -printf '%T@\n' 2>/dev/null \
    | sort -nr | head -1)
  local cache_ts
  cache_ts=$(stat -c '%Y' "$cache" 2>/dev/null || echo 0)
  # If any .nix is newer than the cache, it's stale.
  awk -v n="${newest:-0}" -v c="${cache_ts:-0}" 'BEGIN { exit (n > c ? 0 : 1) }'
}

# Primes one profile's cache. Returns 0 on success, non-zero on eval failure.
_tc_prime_one() {
  local profile="$1" out="$TC_CACHE_DIR/$1.json"
  if ! _tc_cache_stale "$out"; then return 0; fi
  local err
  err=$(nix --extra-experimental-features 'nix-command flakes' \
    eval --impure --json \
    --expr "import $REPO_ROOT/tests/lib/eval-cache.nix { flakePath = \"$REPO_ROOT\"; profile = \"$profile\"; }" \
    2>&1 > "$out.tmp")
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -f "$out.tmp"
    printf '_tc_prime_one(%s) failed: %s\n' "$profile" "$err" >&2
    return $rc
  fi
  mv -f "$out.tmp" "$out"
  return 0
}

# One-shot prime of both caches. Safe to call repeatedly.
_tc_prime_cache() {
  _tc_ensure_jq || {
    warn "jq not available and could not be bootstrapped via nix shell"
    return 1
  }
  _tc_prime_one paranoid || return $?
  _tc_prime_one daily    || return $?
  return 0
}

# Internal: look up a dotted attr in the given profile's cache. Prints the
# JSON value, or 'null' when the key is absent / the eval failed.
_tc_cache_lookup() {
  local profile="$1" attr="$2"
  local f="$TC_CACHE_DIR/$profile.json"
  _tc_ensure_jq || return 1
  if [[ ! -s "$f" ]]; then
    if ! _tc_prime_one "$profile"; then return 1; fi
  fi
  # The cache object is keyed by the dotted attr string. Each entry is
  # { ok: bool, value?: any }. Return the value, or 'null' when not OK.
  "$_tc_jq" -c --arg k "$attr" '
    .[$k] as $e |
    if $e == null then null
    elif ($e | type) != "object" then null
    elif ($e.ok // false) then $e.value
    else null end
  ' "$f"
}

# nix_eval / nix_eval_daily: look up attr in cache; print JSON or 'null'.
nix_eval()        { _tc_cache_lookup paranoid "$1"; }
nix_eval_daily()  { _tc_cache_lookup daily    "$1"; }

# jq helper for tests that want to pipe. Prefer the cached jq when bootstrapped.
jq_cmd()          { _tc_ensure_jq || return 1; "$_tc_jq" "$@"; }

# ── profile detection ─────────────────────────────────────────────────────
# Priority:
#  1) TEST_PROFILE env
#  2) kernel cmdline has nosmt=force → paranoid, usbcore.authorized_default=2 → paranoid
#  3) shadow fallback: iterate user names declared in `myOS.users` (via
#     the eval cache) and for each check which profile has that account
#     unlocked. Stage 4c: names are no longer hardcoded here; anything
#     declared in `accounts/*.nix` (or by an integrator flake) is picked
#     up automatically.
detect_profile() {
  if [[ -n "${TEST_PROFILE:-}" ]]; then
    printf '%s\n' "$TEST_PROFILE"; return
  fi
  local params; params=$(cat /proc/cmdline 2>/dev/null || true)
  if [[ "$params" == *"nosmt=force"* ]] || [[ "$params" == *"usbcore.authorized_default=2"* ]]; then
    printf 'paranoid\n'; return
  fi
  # Fallback: consult /etc/shadow (requires read privs; may fail for normal users).
  # For each declared user, check which profile marks them active.
  if [[ -r /etc/shadow ]] && _tc_ensure_jq 2>/dev/null; then
    # Discover declared user names from the paranoid cache (both caches
    # agree on who's declared; they differ only on `_activeOn`).
    local names_json
    names_json=$(_tc_cache_lookup paranoid 'myOS.users.__names' 2>/dev/null || echo '[]')
    if [[ -n "$names_json" && "$names_json" != 'null' ]]; then
      local names
      mapfile -t names < <("$_tc_jq" -r '.[]' <<<"$names_json" 2>/dev/null || true)
      for n in "${names[@]}"; do
        local field; field=$(getent shadow "$n" 2>/dev/null | cut -d: -f2 || true)
        [[ "$field" == '!' || -z "$field" ]] && continue
        # Find which profile has this user active.
        local active_paranoid active_daily
        active_paranoid=$(_tc_cache_lookup paranoid "myOS.users.${n}._activeOn" 2>/dev/null || echo null)
        active_daily=$(_tc_cache_lookup daily    "myOS.users.${n}._activeOn" 2>/dev/null || echo null)
        if [[ "$active_paranoid" == 'true' ]]; then
          printf 'paranoid\n'; return
        fi
        if [[ "$active_daily" == 'true' ]]; then
          printf 'daily\n'; return
        fi
      done
    fi
  fi
  printf 'daily\n'
}

# ── finalisation ──────────────────────────────────────────────────────────
# Exit with the correct code based on tallies. Invoked via trap so test files
# don't need to call it explicitly (and can still return early).
_tc_finalise() {
  local rc=$?
  local summary
  summary=$(printf 'pass=%d fail=%d skip=%d warn=%d' "$_TC_PASS" "$_TC_FAIL" "$_TC_SKIP" "$_TC_WARN")
  if [[ $_TC_FAIL -gt 0 ]]; then
    printf '  %s▸ summary%s %s%s%s\n' "$_tc_dim" "$_tc_reset" "$_tc_red" "$summary" "$_tc_reset"
    exit 1
  else
    printf '  %s▸ summary%s %s%s%s\n' "$_tc_dim" "$_tc_reset" "$_tc_green" "$summary" "$_tc_reset"
    exit 0
  fi
}

trap _tc_finalise EXIT
