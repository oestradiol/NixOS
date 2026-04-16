#!/usr/bin/env bash
# Master runner for the repo test suite. Discovers test files under
# tests/{static,runtime,bugs} and invokes them one by one. Honours
# --layer, --verbose, --no-sudo, --fail-fast, --keep-results flags.
#
# Each test file is a self-contained bash script that sources
# tests/lib/common.sh and prints human-readable output. The runner tallies
# per-file pass/fail by reading exit codes and by scanning stdout for the
# TAP-ish `✓` / `✗` / `~` markers emitted by common.sh.

set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
RESULTS_DIR="$SCRIPT_DIR/results"
export REPO_ROOT

# ── colors ────────────────────────────────────────────────────────────────
if [[ -t 1 && "${NO_COLOR:-}" != 1 ]]; then
  C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=; C_DIM=; C_OFF=
fi

# ── args ──────────────────────────────────────────────────────────────────
LAYER="all"
VERBOSE=0
NO_SUDO=0
FAIL_FAST=0
KEEP_RESULTS=0
EXPLICIT_FILES=()

usage() {
  cat <<EOF
Usage: $0 [flags] [test-file...]

Flags:
  --layer {static|runtime|bugs|all}   select layer (default: all)
  --verbose                            stream test output as it runs
  --no-sudo                            skip tests that declare needs_sudo
  --fail-fast                          stop at the first failing file
  --keep-results                       keep previous run logs in results/
  -h, --help                           this help

Explicit file arguments override --layer.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer) LAYER="${2:?}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --no-sudo) NO_SUDO=1; shift ;;
    --fail-fast) FAIL_FAST=1; shift ;;
    --keep-results) KEEP_RESULTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; EXPLICIT_FILES+=("$@"); break ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) EXPLICIT_FILES+=("$1"); shift ;;
  esac
done

case "$LAYER" in
  static|runtime|bugs|all) ;;
  *) echo "invalid --layer: $LAYER" >&2; exit 2 ;;
esac

# ── discover ──────────────────────────────────────────────────────────────
layer_dirs=()
case "$LAYER" in
  static)  layer_dirs=("$SCRIPT_DIR/static") ;;
  runtime) layer_dirs=("$SCRIPT_DIR/runtime") ;;
  bugs)    layer_dirs=("$SCRIPT_DIR/bugs") ;;
  all)     layer_dirs=("$SCRIPT_DIR/static" "$SCRIPT_DIR/runtime" "$SCRIPT_DIR/bugs") ;;
esac

files=()
if [[ ${#EXPLICIT_FILES[@]} -gt 0 ]]; then
  for f in "${EXPLICIT_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "no such file: $f" >&2; exit 2; }
    files+=("$f")
  done
else
  for d in "${layer_dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r -d '' f; do files+=("$f"); done \
      < <(find "$d" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
  done
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No test files to run (layer=$LAYER)." >&2
  exit 2
fi

# ── results dir ───────────────────────────────────────────────────────────
if [[ $KEEP_RESULTS -eq 0 ]]; then
  rm -rf "$RESULTS_DIR"
fi
mkdir -p "$RESULTS_DIR"
LOG_INDEX="$RESULTS_DIR/index.log"
: > "$LOG_INDEX"

# ── header ────────────────────────────────────────────────────────────────
printf '%s=== repo test suite ===%s\n' "$C_CYAN" "$C_OFF"
printf '%s·%s layer=%s files=%d repo=%s\n' "$C_DIM" "$C_OFF" "$LAYER" "${#files[@]}" "$REPO_ROOT"

# Bash version must be >= 4 for most of common.sh (associative arrays, etc.)
if (( BASH_VERSINFO[0] < 4 )); then
  printf '%s✗%s bash >= 4 required (have %s)\n' "$C_RED" "$C_OFF" "${BASH_VERSION}"
  exit 2
fi

# Pre-prime the nix-eval cache so individual tests are instant lookups.
printf '%s·%s priming nix-eval cache (one-time ~20s for both profiles)...' \
  "$C_DIM" "$C_OFF"
prime_log="$RESULTS_DIR/_prime.log"
if (
  # shellcheck source=lib/common.sh
  REPO_ROOT="$REPO_ROOT" source "$SCRIPT_DIR/lib/common.sh" >/dev/null 2>&1
  # Suppress the finalise trap from common.sh so the exit status is ours.
  trap - EXIT
  _tc_prime_cache
) >"$prime_log" 2>&1; then
  printf '\r%s·%s nix-eval cache primed                                         \n' "$C_DIM" "$C_OFF"
else
  printf '\r%s·%s nix-eval cache prime FAILED (tests will fall through per-attr)\n' \
    "$C_YELLOW" "$C_OFF"
  sed 's/^/      /' "$prime_log" | head -10
fi

# ── tallies ───────────────────────────────────────────────────────────────
total_files=${#files[@]}
files_pass=0
files_fail=0
files_skip=0
total_assert_pass=0
total_assert_fail=0
total_assert_skip=0
total_assert_warn=0

start_ts=$(date +%s)

# ── main loop ─────────────────────────────────────────────────────────────
for f in "${files[@]}"; do
  rel="${f#$REPO_ROOT/}"
  log="$RESULTS_DIR/$(basename "$f").log"

  # Sniff metadata by grep so we can skip sudo-only tests cleanly.
  declares_sudo=$(grep -q '^needs_sudo' "$f" && echo yes || echo no)
  declares_root=$(grep -q '^needs_root' "$f" && echo yes || echo no)
  declares_profile=$(grep -m1 '^needs_profile' "$f" | awk '{print $2}' | tr -d '"' || true)

  # Skip decisions.
  if [[ "$declares_sudo" == yes && "$NO_SUDO" -eq 1 ]]; then
    printf '%s~%s %s %s(skip: needs_sudo, --no-sudo set)%s\n' "$C_YELLOW" "$C_OFF" "$rel" "$C_DIM" "$C_OFF"
    files_skip=$((files_skip + 1))
    continue
  fi
  if [[ "$declares_root" == yes && "$(id -u)" -ne 0 ]]; then
    printf '%s~%s %s %s(skip: needs root)%s\n' "$C_YELLOW" "$C_OFF" "$rel" "$C_DIM" "$C_OFF"
    files_skip=$((files_skip + 1))
    continue
  fi
  if [[ -n "$declares_profile" ]]; then
    cur=$(TEST_PROFILE="${TEST_PROFILE:-}" bash -c "
      source '$SCRIPT_DIR/lib/common.sh' >/dev/null 2>&1
      trap - EXIT  # Disable common.sh's finalise trap to prevent summary output
      detect_profile
    " 2>/dev/null || echo unknown)
    if [[ "$cur" != "$declares_profile" ]]; then
      printf '%s~%s %s %s(skip: needs profile %s, running %s)%s\n' "$C_YELLOW" "$C_OFF" "$rel" "$C_DIM" "$declares_profile" "$cur" "$C_OFF"
      files_skip=$((files_skip + 1))
      continue
    fi
  fi

  # Run the file.
  printf '\n%s▶%s %s\n' "$C_BLUE" "$C_OFF" "$rel"
  if [[ $VERBOSE -eq 1 ]]; then
    bash "$f" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
  else
    bash "$f" >"$log" 2>&1
    rc=$?
    # Stream any lines containing ✓/✗/~/·/! so the viewer still sees progress.
    if [[ -s "$log" ]]; then
      while IFS= read -r line; do
        printf '%s\n' "$line"
      done < "$log"
    fi
  fi

  # Per-file tallies (count markers; skips must not inflate fails).
  # `grep -c` always prints a count, so no fallback is needed; a trailing
  # `|| echo 0` would produce "0\n0" on empty matches and break the arith.
  assert_pass=$(grep -c '✓' "$log" 2>/dev/null); assert_pass=${assert_pass:-0}
  assert_fail=$(grep -c '✗' "$log" 2>/dev/null); assert_fail=${assert_fail:-0}
  assert_skip=$(grep -c '^  ~' "$log" 2>/dev/null); assert_skip=${assert_skip:-0}
  assert_warn=$(grep -c '^  !' "$log" 2>/dev/null); assert_warn=${assert_warn:-0}

  total_assert_pass=$((total_assert_pass + assert_pass))
  total_assert_fail=$((total_assert_fail + assert_fail))
  total_assert_skip=$((total_assert_skip + assert_skip))
  total_assert_warn=$((total_assert_warn + assert_warn))

  if [[ $rc -eq 0 ]]; then
    files_pass=$((files_pass + 1))
    printf '%s✓ %s%s\n' "$C_GREEN" "$rel" "$C_OFF"
    echo "PASS $rel $log" >> "$LOG_INDEX"
  else
    files_fail=$((files_fail + 1))
    printf '%s✗ %s (rc=%d)%s\n' "$C_RED" "$rel" "$rc" "$C_OFF"
    echo "FAIL $rel $log" >> "$LOG_INDEX"
    if [[ $FAIL_FAST -eq 1 ]]; then
      printf '%s· --fail-fast requested, stopping.%s\n' "$C_DIM" "$C_OFF"
      break
    fi
  fi
done

end_ts=$(date +%s)
elapsed=$((end_ts - start_ts))

# ── summary ───────────────────────────────────────────────────────────────
printf '\n%s=== summary ===%s\n' "$C_CYAN" "$C_OFF"
printf '  files: %stotal=%d%s %spass=%d%s %sfail=%d%s %sskip=%d%s\n' \
  "$C_DIM" "$total_files" "$C_OFF" \
  "$C_GREEN" "$files_pass" "$C_OFF" \
  "$C_RED"   "$files_fail" "$C_OFF" \
  "$C_YELLOW" "$files_skip" "$C_OFF"
printf '  asserts: pass=%d fail=%d skip=%d warn=%d\n' \
  "$total_assert_pass" "$total_assert_fail" "$total_assert_skip" "$total_assert_warn"
printf '  elapsed: %ds  logs: %s\n' "$elapsed" "$RESULTS_DIR"

if [[ $files_fail -gt 0 ]]; then
  exit 1
fi
exit 0
