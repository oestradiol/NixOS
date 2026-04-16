#!/usr/bin/env bash
# Static: sysctl policy per HARDENING-TRACKER.md.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

pj=$(nix_eval 'boot.kernel.sysctl')
dj=$(nix_eval_daily 'boot.kernel.sysctl')

get() {
  # get <json> <key>
  jq_cmd -r --arg k "$2" '.[$k] // empty' <<<"$1"
}

eq_sysctl() {
  # eq_sysctl <key> <want-paranoid> <want-daily> <label>
  local key="$1" pw="$2" dw="$3" label="$4"
  local pv dv
  pv=$(get "$pj" "$key")
  dv=$(get "$dj" "$key")
  if [[ "$pv" == "$pw" && "$dv" == "$dw" ]]; then
    pass "$label"
  else
    fail "$label" "paranoid.$key=$pv (wanted $pw)" "daily.$key=$dv (wanted $dw)"
  fi
}

describe "sysctl shared baseline"
eq_sysctl "kernel.dmesg_restrict"                 "1" "1" "dmesg_restrict"
eq_sysctl "kernel.kptr_restrict"                  "2" "2" "kptr_restrict"
eq_sysctl "kernel.unprivileged_bpf_disabled"      "1" "1" "unprivileged_bpf_disabled"
eq_sysctl "net.core.bpf_jit_harden"               "2" "2" "bpf_jit_harden"
eq_sysctl "kernel.perf_event_paranoid"            "3" "3" "perf_event_paranoid"
eq_sysctl "fs.protected_symlinks"                 "1" "1" "protected_symlinks"
eq_sysctl "fs.protected_hardlinks"                "1" "1" "protected_hardlinks"
eq_sysctl "fs.protected_fifos"                    "2" "2" "protected_fifos"
eq_sysctl "fs.protected_regular"                  "2" "2" "protected_regular"
eq_sysctl "fs.suid_dumpable"                      "0" "0" "suid_dumpable"
eq_sysctl "net.ipv4.tcp_syncookies"               "1" "1" "tcp_syncookies"
eq_sysctl "net.ipv4.tcp_rfc1337"                  "1" "1" "tcp_rfc1337"
eq_sysctl "net.ipv6.conf.all.use_tempaddr"        "2" "2" "ipv6 use_tempaddr"
eq_sysctl "kernel.kexec_load_disabled"            "1" "1" "kexec_load_disabled"
eq_sysctl "kernel.sysrq"                          "4" "4" "sysrq=4 (restricted)"
eq_sysctl "vm.max_map_count"                      "2147483642" "2147483642" "vm.max_map_count"
eq_sysctl "vm.page-cluster"                       "0" "0" "zram: page-cluster"
eq_sysctl "vm.watermark_scale_factor"             "125" "125" "zram: watermark_scale_factor"
eq_sysctl "vm.watermark_boost_factor"             "0" "0" "zram: watermark_boost_factor"

describe "sysctl profile-sensitive"
eq_sysctl "kernel.io_uring_disabled"              "2" "1" "io_uring_disabled (paranoid=2, daily=1)"
eq_sysctl "kernel.yama.ptrace_scope"              "2" "1" "ptrace_scope (paranoid=2, daily=1)"
eq_sysctl "vm.swappiness"                         "180" "150" "swappiness (paranoid=180, daily=150)"

describe "privacy.nix sysctls"
eq_sysctl "net.ipv4.tcp_timestamps"               "0" "1" "tcp_timestamps (paranoid=off, daily=on)"

# net.ipv4.icmp_echo_ignore_all is only present on paranoid (disableIcmpEcho)
describe "paranoid-only: icmp_echo_ignore_all"
pv=$(get "$pj" "net.ipv4.icmp_echo_ignore_all")
dv=$(get "$dj" "net.ipv4.icmp_echo_ignore_all")
# NixOS lib.mkIf returns e.g. the bool itself only when the condition holds
if [[ "$pv" == "true" || "$pv" == "1" ]] && [[ -z "$dv" || "$dv" == "false" ]]; then
  pass "icmp_echo_ignore_all only set on paranoid"
else
  fail "icmp_echo_ignore_all policy wrong" "paranoid=$pv" "daily=$dv"
fi
