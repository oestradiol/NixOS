# Repo test suite

Runtime- and governance-aware test harness for this NixOS repo.

## Layout

```
tests/
├── README.md            — this file
├── run.sh               — master runner (filters + summary)
├── lib/
│   └── common.sh        — shared helpers (assert, info, TAP-ish output, nix-eval)
├── static/              — no booted machine required; flake/eval/policy/governance
├── runtime/             — requires the booted system; probes services, mounts, kernel
├── bugs/                — regression tests for known bugs
└── results/             — per-run logs (gitignored)
```

## Target profile

Every test is profile-aware:
- Daily is the player-facing profile. Its expected baseline differs from paranoid.
- The runtime layer auto-detects which profile is booted by reading `/etc/shadow`
  and kernel params, so you do not need to pass `--profile` manually.

## What is covered

Static layer (no root needed):
- repo file structure matches declared truth surfaces
- `nix flake check` passes
- both configurations (`nixos` and the `daily` specialisation) evaluate
- governance assertions compile into the eval
- profile deltas (the 20+ explicit daily softenings) match documented policy
- kernel params, sysctl policy, module blacklist are consistent with profile
- documentation ↔ code drift across `FEATURES.md`, `HARDENING-TRACKER.md`,
  `AUDIT-STATUS.md`, `PROFILE-POLICY.md`

Runtime layer (booted system required, some tests need sudo):
- system health: failed units, journal warnings, boot-time fsck
- filesystem: tmpfs root, Btrfs subvolumes, persist mount, swap
- profile invariants: correct homes mounted, the other profile's homes absent
- users and identity: player unlocked on daily / ghost locked, machine-id persistence
- kernel: applied sysctls, boot params, blacklisted modules not loaded
- networking: NetworkManager, systemd-resolved, firewall, Mullvad daemon, DNS works
- desktop session: greetd/regreet, Plasma 6, Wayland-only (X server disabled)
- audio/input: PipeWire, WirePlumber, RTKit, fcitx5
- gaming (daily): Steam, gamescope, gamemode, ntsync module
- controllers (daily): Bluetooth powered on, xpadneo loaded, udev rules present
- VR (daily): wivrn service, realtime group
- GPU: NVIDIA driver loaded, 32-bit graphics, ozone wayland env
- Flatpak: service active, Flathub remote present, xdg portals
- scanners: ClamAV timers and services exist, AIDE config and service
- AppArmor / auditd: match profile policy
- sandbox wrappers: binaries, D-Bus proxy, shell quoting
- boot loader: systemd-boot entries, loader.conf state, default entry selection
- shell env: zsh, starship, git, gpg-agent, fzf, zoxide
- power management: sleep targets masked, fstrim, zram, earlyoom

Static layer — additions from the 2026-04 pen-test pass:
- `140-firewall-surface.sh`
  No spurious globally-open ports on either profile; WiVRn `openFirewall`
  must be off; port 9757 must be opened only on declared LAN interfaces;
  UDP 7 (echo) must stay removed; UDP 9 (WoL-over-UDP) must be LAN-only.
- `150-avahi-governance.sh`
  Enforces the `myOS.vr.lanDiscovery` policy statically: when the knob is
  off, avahi is off; when on, `allowInterfaces` must be a non-empty subset
  of `myOS.vr.lanInterfaces`. Also checks governance.nix owns the invariant.
- `160-flake-aliases.sh`
  Every `flake-*` alias is declared and routes through the correct
  specialisation; debug-phase requires `--show-trace` everywhere; the smart
  default branches on `/run/current-system/specialisation/daily`.
- `170-fs-layout.sh`
  `/` tmpfs ≥ 8G; `/tmp` is its own tmpfs with `nosuid,nodev`;
  `boot.tmp.cleanOnBoot` stays true; the five canonical Btrfs subvols
  (`@home-daily`, `@home-paranoid`, `@persist`, `@nix`, `@log`) stay declared.

Bugs layer:
- `010-systemd-boot-extrainstall.sh`
  Regression test for the commented-out `extraInstallCommands` in
  `modules/core/boot.nix`. Captures glob match behaviour and loader.conf state.
- `020-profile-mount-switch.sh`
  Regression test for the `flake-switch` alias activating the wrong profile
  when run from a specialisation (captured in `switch.log`). After the
  2026-04 fix, the switch.log lines fire as **warn** (historical artefact).
- `030-flake-switch-alias.sh`
  Regression test for the specialisation-aware alias family introduced in
  the 2026-04 pen-test pass: `flake-switch-daily`, `flake-switch-paranoid`,
  smart-default `flake-switch`, `flake-rollback`, `flake-dry`, plus the
  `--show-trace`-everywhere debug-phase requirement.

## How to run

```bash
# full suite
./tests/run.sh

# only static checks (safe to run anywhere the flake evaluates)
./tests/run.sh --layer static

# only runtime (on the booted target)
./tests/run.sh --layer runtime

# specific test file
./tests/run.sh tests/runtime/020-filesystem.sh

# verbose (stream test stdout/stderr as tests run)
./tests/run.sh --verbose
```

Flags:
- `--layer {static|runtime|bugs|all}` — default `all`
- `--verbose` — stream test output as they run
- `--no-sudo` — skip tests that require `sudo`
- `--fail-fast` — stop at the first failing test
- `--keep-results` — retain old log files in `results/`

Exit codes:
- `0` all tests passed (or skipped)
- `1` at least one test failed
- `2` suite setup error (missing tools, bad invocation)

## Conventions

Each test script:
- sources `tests/lib/common.sh`
- declares at least one `describe "..."` block
- uses `pass`, `fail`, `skip`, or the `assert_*` helpers
- exits 0 if every assertion passed or was skipped, 1 otherwise

A test may declare `needs_sudo` or `needs_profile daily` at the top — the
runner honours both.

## What this suite does NOT claim

- It is not a malware scan or a runtime intrusion detection layer.
- It does not prove the kernel is uncompromised.
- It does not run the staged self-owned WireGuard path.
- It does not validate Secure Boot / TPM rollout (those are `POST-STABILITY`).
