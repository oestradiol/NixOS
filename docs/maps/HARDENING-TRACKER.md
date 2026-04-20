# Hardening tracker

This file tracks the major hardening/privacy knobs in the repo.

Status values:
- `baseline` = active now in the shared base or `paranoid`
- `daily-softened` = active in base/paranoid, explicitly weakened in `daily`
- `staged` = implemented but off by default
- `deferred` = acknowledged follow-up, not baseline today
- `rejected` = intentionally not part of this repo design
- `absent` = not implemented

## Identity, users, and account model

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| two-account split (`ghost` / `player`) | baseline | keep | `modules/core/users.nix`, `docs/governance/PROJECT-STATE.md` | core governance model |
| `ghost` expected on `paranoid` | baseline | keep | `docs/governance/PROJECT-STATE.md`, `modules/security/governance.nix` | hardened workspace split |
| `player` expected on `daily` | baseline | keep | `docs/governance/PROJECT-STATE.md` | normal desktop split |
| `users.mutableUsers = false` (immutable) | baseline | keep | `modules/core/users.nix`, `docs/maps/PROFILE-POLICY.md` | declarative password management via hashedPasswordFile |
| root account locked | baseline | keep | `modules/security/base.nix` | reduce direct root login surface |
| `ghost` in wheel by default | rejected | do not add | `modules/security/governance.nix` | paranoid user should not have default wheel escalation |
| profile-user binding via account locking | baseline | keep | `modules/core/users.nix`, `docs/pipeline/POST-STABILITY.md` | daily locks ghost, paranoid locks player |
| PAM profile-binding | rejected | superseded | `modules/security/user-profile-binding.nix` | account locking approach is simpler and safer |
| `myOS.debug.enable` master gate | baseline | keep default off | `modules/core/debug.nix` | declarative escape hatch; sub-flags are no-ops without it; must stay off on any stable baseline |
| `myOS.debug.crossProfileLogin.enable` | staged off by default | keep off except when actively debugging login flows | `modules/core/debug.nix`, `modules/core/users.nix` | relaxes profile-user account-lock binding for cross-profile authentication; documented escape for recovery/bootstrap |
| `myOS.debug.paranoidWheel.enable` | staged off by default | keep off except when actively administering paranoid from paranoid | `modules/core/debug.nix`, `modules/core/users.nix`, `modules/security/governance.nix` | adds ghost to wheel and skips the matching governance assertion; escape for emergency admin |
| `myOS.debug.warnings.enable` | baseline on | keep on | `modules/core/debug.nix` | surfaces active debug relaxations in every rebuild; silencing is a footgun |

## Kernel and boot hardening

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| stock kernel packages | baseline | keep | `modules/core/boot.nix` | reliability-first workstation baseline |
| `linux-hardened` kernel | absent | not baseline | none | not chosen due to compatibility/runtime confidence tradeoff |
| `randomize_kstack_offset=on` | baseline | keep | `modules/core/boot.nix` | low-cost kernel hardening |
| `debugfs=off` | baseline | keep | `modules/core/boot.nix` | reduce kernel attack/debug surface |
| `slub_debug=FZP` + `page_poison=1` | baseline | keep | `modules/core/boot.nix` | memory-corruption detection posture |
| `slab_nomerge` | baseline | keep | `profiles/paranoid.nix`, `profiles/daily.nix`, `modules/core/boot.nix` | low-risk hardening |
| `init_on_alloc=1` | baseline | keep | `profiles/*`, `modules/core/boot.nix` | hardening at acceptable cost |
| `init_on_free=1` | daily-softened | keep paranoid-only | `profiles/paranoid.nix`, `profiles/daily.nix` | performance/compatibility tradeoff |
| `page_alloc.shuffle=1` | baseline | keep | `profiles/*`, `modules/core/boot.nix`, `modules/security/governance.nix` | low-cost hardening |
| `nosmt=force` | daily-softened | keep paranoid-only | `profiles/paranoid.nix`, `profiles/daily.nix`, `modules/security/governance.nix` | strong hardening but daily usability/perf cost |
| `usbcore.authorized_default=2` | daily-softened | keep paranoid-only | `profiles/paranoid.nix`, `profiles/daily.nix`, `modules/security/governance.nix` | physical-device friction accepted only on paranoid |
| `pti=on` | baseline | keep | `profiles/*`, `modules/core/boot.nix` | speculative-execution mitigation |
| `vsyscall=none` | baseline | keep | `profiles/*`, `modules/core/boot.nix` | shrink legacy attack surface |
| `oops=panic` | staged | keep off for now | `profiles/*`, `modules/core/boot.nix` | stronger reaction but higher availability risk |
| `module.sig_enforce=1` | staged | keep off for now | `profiles/*`, `modules/core/boot.nix` | good hardening, but runtime/driver friction risk |
| `kernel.modules_disabled=1` | staged | keep off for now | `profiles/*`, `modules/security/base.nix` | strong lock-down, but poor operator recovery margin |
| `kernel.kexec_load_disabled=1` | baseline | keep | `profiles/*`, `modules/security/base.nix`, `modules/security/governance.nix` | reduce alternate-kernel loading surface |
| restricted SysRq | baseline | keep | `profiles/*`, `modules/security/base.nix`, `modules/security/governance.nix` | emergency functions only |
| `kernel.io_uring_disabled=2` on paranoid / `1` on daily | daily-softened | keep | `profiles/*`, `modules/security/base.nix`, `modules/security/governance.nix` | stronger disablement on paranoid |
| module blacklist (dccp/sctp/rds/tipc/firewire) | baseline | keep | `modules/security/base.nix` | remove unused attack surface |
| Secure Boot via Lanzaboote | staged | post-stability rollout | `modules/security/secure-boot.nix`, `scripts/post-install-secureboot-tpm.sh`, `docs/pipeline/POST-STABILITY.md` | valuable, but intentionally not baseline until validated |
| TPM-bound unlock | staged | post-stability rollout | `modules/security/secure-boot.nix`, `docs/pipeline/POST-STABILITY.md` | same reason as above |

## Sysctl / kernel runtime controls

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| `kernel.dmesg_restrict=1` | baseline | keep | `modules/security/base.nix` | reduce info leaks |
| `kernel.kptr_restrict=2` | baseline | keep | `modules/security/base.nix` | reduce kernel pointer leaks |
| `kernel.unprivileged_bpf_disabled=1` | baseline | keep | `modules/security/base.nix` | reduce unprivileged kernel attack surface |
| `net.core.bpf_jit_harden=2` | baseline | keep | `modules/security/base.nix` | BPF JIT hardening |
| `kernel.perf_event_paranoid=3` | baseline | keep | `modules/security/base.nix` | perf restriction |
| ptrace scope | daily-softened | keep split | `profiles/*`, `modules/security/base.nix` | paranoid uses tighter value |
| rp_filter / redirect protections | baseline | keep | `modules/security/base.nix` | sane network hardening defaults |
| IPv6 temporary addresses | baseline | keep | `modules/security/base.nix` | privacy improvement |
| `net.ipv4.tcp_timestamps=0` on paranoid | daily-softened | keep split | `modules/security/privacy.nix` | privacy vs networking/game compatibility |
| `icmp_echo_ignore_all=1` | daily-softened | keep paranoid-only | `profiles/*`, `modules/core/boot.nix` | reduces network discoverability |
| `dev.tty.ldisc_autoload=0` | absent | candidate later | none | useful but not currently encoded |
| `vm.unprivileged_userfaultfd=0` | absent | candidate later | none | useful but not currently encoded |
| `kernel.unprivileged_userns_clone=0` | absent | not chosen | none | conflicts with common desktop/container compatibility |
| `hidepid` for `/proc` | absent | candidate later | none | worth evaluating after stability |
| `/sys` access restriction layer | deferred | maybe later | `docs/pipeline/POST-STABILITY.md` (conceptual only) | high breakage risk on desktop workloads |

## Isolation and execution surfaces

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| bubblewrap wrapper core | baseline | keep | `modules/security/sandbox-core.nix` | shared same-kernel containment layer |
| filtered D-Bus for wrappers | baseline | keep | `modules/security/sandbox-core.nix`, `profiles/*` | reduce ambient bus access |
| wrapped paranoid browsers | baseline | keep | `modules/security/browser.nix`, `profiles/paranoid.nix` | strongest browser baseline short of VMs |
| ordinary Firefox on daily | daily-softened | keep | `modules/security/browser.nix`, `profiles/daily.nix` | compatibility/social use |
| app wrappers for daily non-Flatpak apps | daily-softened | keep | `modules/security/sandboxed-apps.nix`, `profiles/daily.nix` | practical containment for daily tools |
| X11 passthrough in wrappers | daily-softened | keep daily-only | `profiles/daily.nix`, `modules/security/governance.nix` | compatibility relaxation |
| VM tooling layer | baseline on paranoid | keep | `modules/security/vm-tooling.nix`, `profiles/paranoid.nix` | higher-risk escalation path |
| VM tooling on daily | daily-softened | keep off | `profiles/daily.nix` | reduce daily complexity |
| wrapper seccomp | deferred | post-stability | `docs/pipeline/POST-STABILITY.md` | not baseline-ready |
| wrapper Landlock | deferred | post-stability | `docs/pipeline/POST-STABILITY.md` | not baseline-ready |
| Firejail | rejected | do not add | none | repo standardizes on bubblewrap wrappers instead |
| Flatpak | baseline | keep | `modules/security/flatpak.nix` | trusted GUI-app containment layer |

## Browser and privacy posture

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| daily Firefox via enterprise policies | baseline in daily | keep | `modules/security/browser.nix` | stable official policy surface |
| paranoid Firefox via vendored arkenfox wrapper | baseline in paranoid | keep | `modules/security/browser.nix`, `modules/security/arkenfox/user.js` | stronger privacy baseline |
| Tor Browser wrapper | baseline optional | keep | `modules/security/browser.nix` | upstream anonymity model + local containment |
| Mullvad Browser wrapper | baseline optional | keep | `modules/security/browser.nix` | upstream privacy model + local containment |
| Firefox Sync disabled | baseline | keep | `modules/security/browser.nix`, `docs/governance/PROJECT-STATE.md` | privacy and account-linking reduction |
| broad `/etc` bind into wrappers | rejected | do not add | `modules/security/sandbox-core.nix` | wrapper posture intentionally tightened |

## Network / identifiers

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| Mullvad app mode (daily only) | baseline | keep for now | `modules/security/networking.nix`, `docs/governance/PROJECT-STATE.md` | simpler stable baseline for daily/player |
| self-owned WireGuard path | staged | post-stability / optional | `modules/security/wireguard.nix`, `modules/core/options.nix` | stronger repo-owned path, but more operator burden |
| explicit nftables ownership in self-owned WG mode | staged | keep | `modules/security/wireguard.nix` | avoid split authority |
| MAC randomization on paranoid | baseline | keep | `modules/security/privacy.nix` | stronger identifier reduction |
| stable-per-network Wi-Fi MAC on daily | daily-softened | keep | `modules/security/privacy.nix` | privacy with fewer daily breakages |
| firewall-OR-nftables invariant | baseline | keep | `modules/security/governance.nix` | single-packet-filter always active; catches the networking.nix ↔ wireguard.nix coupling |
| daily WoL: UDP 7 (echo) globally open | removed | keep off | `modules/security/networking.nix`, `tests/static/140-firewall-surface.sh` | layer-2 magic packets don't need a firewall port; dead surface removed 2026-04 |
| daily WoL: UDP 9 on `enp5s0` only | baseline | keep | `modules/security/networking.nix` | WoL-over-UDP compatibility, LAN-scoped, never global |
| OpenSnitch | absent | not baseline | none | not currently needed for repo model |

## LAN discovery / mDNS

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| `services.avahi` on paranoid | baseline (off) | keep off | `modules/security/governance.nix`, `modules/desktop/vr.nix` | paranoid doesn't import VR; no mDNS use case; identity beacon |
| `services.avahi` on daily | daily-softened (opt-in) | off unless operator enables `myOS.vr.lanDiscovery` | `modules/desktop/vr.nix`, `modules/core/options.nix` | upstream `wivrn.nix` forces avahi without mkDefault; we gate behind a knob |
| `myOS.vr.lanDiscovery.enable` | baseline (false) | keep default off | `modules/core/options.nix`, `modules/desktop/vr.nix` | connect headset by manual IP; avoid mDNS broadcast |
| `myOS.vr.lanInterfaces` scope | baseline | enforce non-empty when lanDiscovery on | `modules/security/governance.nix`, `tests/static/150-avahi-governance.sh` | prevents avahi broadcast on VPN/bluetooth/guest interfaces when ever enabled |
| WiVRn `openFirewall = true` (upstream) | suppressed | keep off; per-interface rules instead | `modules/desktop/vr.nix`, `tests/static/140-firewall-surface.sh` | upstream opens TCP/UDP 9757 on every interface; we bind to `myOS.vr.lanInterfaces` only |
| `services.geoclue2` (Plasma 6 default) | removed | keep off | `modules/desktop/plasma.nix`, `modules/security/governance.nix` | Wi-Fi BSSID queries to Mozilla Location Service = identity beacon; not referenced by any declared feature |

## Filesystem / tmpfs capacity

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| `/` on tmpfs | baseline | keep | `hosts/nixos/fs-layout.nix`, `docs/maps/FEATURES.md` | impermanence model |
| `/` tmpfs size | baseline (16G) | keep ≥8G | `hosts/nixos/fs-layout.nix`, `tests/static/170-fs-layout.sh` | 4G was empirically too small for KDE + VR + IDE; tmpfs is RAM-backed, cap is upper bound only |
| `/tmp` on its own tmpfs | baseline | keep | `hosts/nixos/fs-layout.nix`, `tests/static/170-fs-layout.sh` | isolates /tmp spikes from /var/lib / /run / /root / home-manager profile paths |
| `/tmp` nosuid+nodev | baseline | keep | `hosts/nixos/fs-layout.nix`, `tests/static/170-fs-layout.sh` | defense-in-depth |
| `boot.tmp.cleanOnBoot = true` | baseline | keep | `modules/security/base.nix`, `tests/static/170-fs-layout.sh` | wipes /tmp across boots |
| `/var/lib/logrotate` persisted | baseline | keep | `modules/security/impermanence.nix` | without it `logrotate.service` fails on tmpfs-full root |

## Operator ergonomics / rebuild

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| specialisation-aware `flake-switch-*` aliases | baseline | keep | `modules/desktop/shell.nix`, `tests/static/160-flake-aliases.sh`, `tests/bugs/030-flake-switch-alias.sh` | single `flake-switch` without `--specialisation` silently targeted paranoid and tripped profile-mount-invariants |
| smart default `flake-switch` (branches on booted spec) | baseline | keep | `modules/desktop/shell.nix` | zero-surprise default that matches the booted profile |
| `flake-rollback` (panic button) | baseline | keep | `modules/desktop/shell.nix` | re-applies `/run/current-system` when a `test` or `switch` misbehaves |
| `flake-dry` (`dry-activate`) | baseline | keep | `modules/desktop/shell.nix` | inspect without applying |
| `--show-trace` on every rebuild alias | baseline | keep while in test phase | `modules/desktop/shell.nix`, `tests/bugs/030-flake-switch-alias.sh` | actionable failures during the debug phase; reconsider once stability is established |

## Secrets, auditing, monitoring

| knob | state | current policy | code/docs | rationale |
|---|---|---|---|---|
| agenix enablement | baseline | keep | `modules/security/secrets.nix`, `profiles/*` | host-side secret path scaffold |
| actual age secrets payloads | staged | fill later | `modules/security/secrets.nix` | scaffolding exists but secrets are not checked in |
| `sops-nix` | absent | not chosen | none | agenix chosen instead |
| audit subsystem + `auditd` on paranoid | baseline | keep | `modules/security/base.nix`, `profiles/paranoid.nix` | visibility layer on hardened profile |
| `auditd` on daily | daily-softened | keep off | `profiles/daily.nix` | lower noise/overhead |
| repo custom audit rules | staged | keep off until validated | `modules/security/base.nix`, `docs/pipeline/POST-STABILITY.md` | upstream compatibility issue / needs revalidation |
| AIDE | baseline | keep | `modules/security/scanners.nix` | integrity monitoring |
| ClamAV | baseline | keep | `modules/security/scanners.nix` | malware scanning / hygiene layer |
| AppArmor framework enablement | baseline | keep | `modules/security/base.nix` | useful baseline despite NixOS limitations |
| custom AppArmor profile library | deferred | post-stability | `docs/pipeline/POST-STABILITY.md` | acknowledged but not baseline-ready |
| SELinux | absent | not chosen | none | not aligned with current repo shape |

## Source links

- saylesss88 Hardening NixOS: https://saylesss88.github.io/nix/hardening_NixOS.html
- saylesss88 Browser Privacy: https://saylesss88.github.io/nix/browsing_security.html
- saylesss88 Lanzaboote: https://saylesss88.github.io/installation/enc/lanzaboote.html
- Madaidan Linux Hardening Guide: https://madaidans-insecurities.github.io/guides/linux-hardening.html
- NixOS / MyNixOS `users.mutableUsers`: https://mynixos.com/nixpkgs/option/users.mutableUsers
