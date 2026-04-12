# PERFORMANCE NOTES

## Purpose
Track the current performance policy and what is intentionally traded away.

## Daily policy
Daily keeps hardening that is low-cost or broadly worth it, while avoiding changes likely to hurt gaming, VR, or social desktop use.

Enabled on daily because cost is usually low:
- `init_on_alloc`
- `slab_nomerge`
- `page_alloc.shuffle`
- `pti=on`
- `vsyscall=none`
- module blacklist

Disabled on daily because breakage or cost is more likely:
- `init_on_free`
- `oops=panic`
- `modules_disabled=1`
- `io_uring_disabled=1`
- hardened allocator rollout

Daily wrapper cost expectations:
- VRCX and Windsurf wrappers may add some startup friction or compatibility debugging
- they should not be treated as a benchmark-neutral change

## Paranoid policy
Paranoid accepts more overhead and breakage.

Enabled on paranoid:
- `init_on_free`
- `oops=panic`
- stricter ptrace policy
- self-owned WireGuard killswitch
- sandboxed browsers
- VM tooling capability layer

## Deferred measurements
Still worth measuring on real hardware:
- daily gaming FPS delta after wrapper changes
- VR latency or compositor issues
- browser GPU acceleration behavior inside paranoid wrappers
- WireGuard throughput under paranoid nftables policy
- any future seccomp or Landlock overhead once implemented

## Rule for future changes
If a hardening change has non-trivial performance cost, document:
- expected cost
- affected workloads
- rollback path
- test result on actual hardware
