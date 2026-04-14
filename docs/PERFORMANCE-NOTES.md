# PERFORMANCE NOTES

Only current performance policy and the tradeoffs that are intentionally accepted.

## Daily policy
Daily keeps hardening that is usually low-cost while avoiding changes likely to hurt gaming, VR, social desktop use, and recovery convenience.

Enabled on daily because cost is usually low:
- `init_on_alloc`
- `slab_nomerge`
- `page_alloc.shuffle`
- `pti=on`
- `vsyscall=none`
- module blacklist

Disabled or relaxed on daily because breakage/cost is more likely:
- `init_on_free`
- `oops=panic`
- `modules_disabled=1`
- hardened allocator rollout
- paranoid browser wrappers for the main Firefox path

Daily wrapper cost expectations:
- VRCX and Windsurf wrappers may add startup friction or compatibility debugging
- they are not benchmark-neutral by default

## Paranoid policy
Paranoid accepts more overhead and more friction.

Enabled or stricter on paranoid:
- `init_on_free`
- stricter ptrace policy
- sandboxed browser path for the main Firefox workflow
- VM tooling capability layer
- tighter wrapper environment and minimal `/etc` browser exposure

## Deferred measurements
Still worth measuring on real hardware:
- daily gaming FPS delta after wrapper changes
- VR latency/compositor issues
- browser GPU acceleration behavior inside paranoid wrappers
- Mullvad app-mode overhead and DNS behavior
- any future seccomp or Landlock overhead once implemented

## Rule for future changes
If a hardening change has non-trivial performance cost, document:
- expected cost
- affected workloads
- rollback path
- real-hardware result
