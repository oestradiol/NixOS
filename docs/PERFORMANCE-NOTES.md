# PERFORMANCE NOTES

## Old config vs new daily — systematic comparison

### Identical (zero performance delta)
- SteamOS gaming sysctls (all 8 scheduler params: sched_cfs_bandwidth, sched_latency, sched_min_granularity, sched_wakeup_granularity, sched_migration_cost, sched_nr_migrate, split_lock_mitigate=0, sched_rt_runtime_us=-1) — daily-only
- `vm.max_map_count`, `tcp_mtu_probing`, `tcp_fin_timeout`
- `vm.swappiness` tuned to 150 on daily (up from 30 default) for zram optimization with 16GB RAM
- `ntsync` kernel module + `PROTON_USE_NTSYNC=1`
- Steam, Gamescope (capSysNice), GameMode — identical config
- WiVRn (CUDA, nvenc h265, Nice=-10, RTPRIO=99, memlock=infinity)
- PipeWire (alsa, 32bit, pulse, jack, wireplumber) + rtkit
- NVIDIA driver (production branch, modesetting, `LIBVA_DRIVER_NAME=nvidia`) — temporary fallback from ideal legacy_580 due to nixpkgs#503740
- EarlyOOM (409600/307200 thresholds)
- journald limits (250M runtime/system)
- zram (zstd, 50%)
- KDE Plasma 6 + SDDM

### Added hardening — per-knob impact on gaming

| Knob | Impact | Notes |
|---|---|---|
| `init_on_alloc=1` | **<1%** | Zeroes allocated pages. Most game allocs happen at load time, not hot loops |
| `slab_nomerge` | **Negligible** | ~50-200MB extra RAM. Trivial on a desktop |
| `randomize_kstack_offset=on` | **Negligible** | Per-syscall overhead unmeasurable |
| `debugfs=off` | **Zero** | |
| 20+ hardened sysctls | **Zero** | Restrict debug/admin paths, not gaming workloads |
| `kernel.yama.ptrace_scope=1` | **Zero** | Daily uses 1 for EAC compatibility; paranoid uses 2 for hardening |
| `kernel.perf_event_paranoid=3` | **Zero** | Breaks `perf` profiling, not gaming |
| `net.core.bpf_jit_harden=2` | **Negligible** | Slightly less optimized BPF JIT |
| AppArmor | **~1-3%** on syscall-heavy code | Games are GPU-bound, not syscall-bound |
| Root lock / PAM su | **Zero** | |
| Module blacklist (dccp/sctp/etc) | **Zero** | |
| `security.protectKernelImage` | **Zero** | |
| Core dump disable | **Zero** | |
| Mullvad app (daily only) | **Optional** | When active: ~5-15ms latency. Off by default on daily |
| Self-owned WireGuard (paranoid only) | **Required** | Deterministic, always-on. Minimal overhead vs Mullvad app |
| `page_alloc.shuffle=1` | **<1%** | Randomizes free page list — enabled on both profiles now |

### Moved to paranoid-only (would have had measurable gaming impact)
| Knob | Why moved | Impact if kept |
|---|---|---|
| `init_on_free=1` | Zeroes ALL freed pages — expensive in alloc-heavy workloads | **1-7%** in microbenchmarks |
| `usbcore.authorized_default=2` | Blocks unauthorized USB — paranoid only | Functional, not perf |
| `nosmt=force` (via disableSMT) | Already daily=false | **30-40%** CPU throughput loss |

### Missing from new daily (compared to Old)
| Feature | Status | Action needed |
|---|---|---|
| GRUB + os-prober | Replaced by systemd-boot | **Faster** boot, no action needed |
| Swap file (8GB) | **Replaced by zram + 8GB Btrfs swapfile** | zram for hot pages, Btrfs swap on `@swap` for cold; 8GB matches old size |
| WakeOnLAN | **Implemented daily-only** | Enabled on `enp5s0` for daily profile; excluded from paranoid |
| CUPS printing | Explicitly disabled | Flip in `base-desktop.nix` if needed |
| Controllers (Bluetooth/Xbox) | Implemented as `myOS.gaming.controllers.enable` knob | Set `myOS.gaming.controllers.enable = true` in profile |

## Net assessment

**Estimated total overhead on daily vs Old: <2%**, dominated by `init_on_alloc=1` and AppArmor. Both are in the noise for GPU-bound gaming and VR. The gaming sysctls, driver config, and scheduling are identical.

## What must be benchmarked after install
1. Steam game frametime in 2-3 titles (before/after)
2. VR latency/stability in WiVRn
3. Shader compilation stutter
4. Boot time and login time
5. Idle RAM usage (expect ~50-200MB higher from slab_nomerge + AppArmor)

## Decision rule
If daily is measurably worse in gaming benchmarks, the first knobs to disable are:
1. AppArmor (`myOS.security.apparmor = false` in daily.nix)
2. `init_on_alloc=1` (`myOS.security.kernelHardening.initOnAlloc = false` in daily.nix)
3. `slab_nomerge` (`myOS.security.kernelHardening.slabNomerge = false` in daily.nix)
