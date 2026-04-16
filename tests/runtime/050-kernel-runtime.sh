#!/usr/bin/env bash
# Runtime: kernel params, sysctls, and blacklisted modules on the booted
# system, cross-checked with the profile.
source "${BASH_SOURCE%/*}/../lib/common.sh"

profile=$(detect_profile)
describe "running on profile: $profile"

describe "kernel command-line contains the shared-base tokens"
for t in \
    randomize_kstack_offset=on \
    debugfs=off \
    slub_debug=FZP \
    page_poison=1 \
    hash_pointers=always \
    slab_nomerge \
    init_on_alloc=1 \
    page_alloc.shuffle=1 \
    pti=on \
    vsyscall=none \
    nvidia_drm.modeset=1; do
  assert_kernel_param "$t"
done

describe "profile-specific kernel params"
if [[ "$profile" == "paranoid" ]]; then
  for t in init_on_free=1 nosmt=force usbcore.authorized_default=2; do
    assert_kernel_param "$t"
  done
else
  for t in init_on_free=1 nosmt=force usbcore.authorized_default=2; do
    assert_kernel_param_absent "$t"
  done
fi

describe "staged params never land on cmdline"
for t in oops=panic module.sig_enforce=1; do
  assert_kernel_param_absent "$t"
done

describe "LSM stack includes apparmor"
# Kernel was built with lsm=landlock,yama,bpf,apparmor per /proc/cmdline
if grep -q 'apparmor' /proc/cmdline; then
  pass "apparmor on kernel cmdline (lsm=...)"
else
  warn "apparmor not on kernel cmdline; may still be active via config"
fi
if [[ -d /sys/kernel/security/apparmor ]]; then
  pass "/sys/kernel/security/apparmor present (apparmor LSM active)"
else
  fail "apparmor LSM is not active"
fi

describe "sysctl: shared-base values"
assert_sysctl "kernel.dmesg_restrict"            "1"
assert_sysctl "kernel.kptr_restrict"             "2"
assert_sysctl "kernel.unprivileged_bpf_disabled" "1"
# net.core.bpf_jit_harden is root-readable only; probe via sysctl -a as root if
# available, otherwise skip. The value is enforced at boot regardless.
if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
  v=$(sudo -n sysctl -n net.core.bpf_jit_harden 2>/dev/null | tr -d '[:space:]')
  if [[ "$v" == "2" ]]; then pass "sysctl net.core.bpf_jit_harden = 2"; else fail "sysctl net.core.bpf_jit_harden != 2" "got: $v"; fi
else
  skip "sysctl net.core.bpf_jit_harden needs root read (declared in base.nix)"
fi
assert_sysctl "kernel.perf_event_paranoid"       "3"
assert_sysctl "fs.protected_symlinks"            "1"
assert_sysctl "fs.protected_hardlinks"           "1"
assert_sysctl "fs.protected_fifos"               "2"
assert_sysctl "fs.protected_regular"             "2"
assert_sysctl "fs.suid_dumpable"                 "0"
assert_sysctl "net.ipv4.tcp_syncookies"          "1"
assert_sysctl "net.ipv4.tcp_rfc1337"             "1"
assert_sysctl "net.ipv6.conf.all.use_tempaddr"   "2"
assert_sysctl "kernel.kexec_load_disabled"       "1"
assert_sysctl "kernel.sysrq"                     "4"
assert_sysctl "vm.max_map_count"                 "2147483642"
assert_sysctl "vm.page-cluster"                  "0"
assert_sysctl "vm.watermark_scale_factor"        "125"
assert_sysctl "vm.watermark_boost_factor"        "0"

describe "sysctl: profile-sensitive values"
if [[ "$profile" == "paranoid" ]]; then
  assert_sysctl "kernel.io_uring_disabled" "2"
  assert_sysctl "kernel.yama.ptrace_scope" "2"
  assert_sysctl "vm.swappiness"            "180"
  assert_sysctl "net.ipv4.tcp_timestamps"  "0"
  assert_sysctl "net.ipv4.icmp_echo_ignore_all" "1"
else
  assert_sysctl "kernel.io_uring_disabled" "1"
  assert_sysctl "kernel.yama.ptrace_scope" "1"
  assert_sysctl "vm.swappiness"            "150"
  assert_sysctl "net.ipv4.tcp_timestamps"  "1"
fi

describe "blacklisted modules are not loaded"
for m in dccp sctp rds tipc firewire_core firewire_ohci; do
  assert_module_absent "$m"
done

describe "daily loads ntsync; paranoid does not"
if [[ "$profile" == "daily" ]]; then
  assert_module_loaded ntsync
else
  assert_module_absent ntsync
fi

describe "kvm-amd (this host is AMD) loaded on both profiles"
assert_module_loaded kvm_amd
