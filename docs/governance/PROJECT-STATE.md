# PROJECT STATE

Canonical current state: actual architecture, profile split, implemented support boundary, current-stage pipeline, explicit deferred work, and removed/rejected ideas.

## 1. Repository role
One NixOS installation with one shared hardening base, two boot states, and two users:
- shared `base`: the non-bootable policy substrate encoded across `modules/core/*`, `modules/security/*`, and shared desktop plumbing (instantiated via templates/default/hosts/nixos/)
- `paranoid`: instantiates that shared base as the default hardened workstation baseline for the `ghost` user
- `daily`: instantiates that shared base as the explicit relaxation layer for the `player` user

Canonical policy reading:
- `base` should be as hardened as possible, but it is not instantiated alone
- `paranoid` should soften `base` only enough to remain a real workstation for `ghost`, while staying as hardened and private as the current desktop/workstation model allows
- `daily` should soften `base` only enough for `player` to handle socialization, gaming, and ordinary recovery-friendly use, while staying as hardened and private as that use case realistically allows

This repo is not trying to be a high-assurance appliance.
It is a hardened desktop/workstation with explicit same-kernel, desktop-integration, and usability limits.

## 2. Current stable-baseline definition
The repo reaches its first stable machine-usable state when both are complete on target hardware and `docs/pipeline/TEST-PLAN.md` has been used as the runtime-proof checklist:
1. `docs/pipeline/INSTALL-GUIDE.md`
2. `docs/pipeline/TEST-PLAN.md`

Anything in `docs/pipeline/POST-STABILITY.md` is intentionally non-blocking for that first stable version.

## 3. Current architecture

### System model
- one shared hardening base (not a standalone boot profile)
- one encrypted LUKS2 root device
- Btrfs subvolumes under LUKS
- tmpfs root
- impermanence-managed persisted state under `/persist`
- one default profile plus one boot specialization
- Secure Boot and TPM remain staged until after first stable boot and validation

### Users and home model
- `player` is the normal daily account
- `ghost` is the hardened workspace account
- `/home/player` is a fully persistent Btrfs subvolume on daily
- `/home/ghost` is tmpfs on paranoid, with explicit allowlisted persistence into `/persist/home/ghost`
- inactive profile home filesystems are intentionally left unmounted, and a boot-time invariant service checks that cross-profile home mounts are absent

### Browser model
- daily Firefox is the normal `programs.firefox` path configured through Firefox enterprise policies
- paranoid Firefox is `safe-firefox`, a bubblewrap wrapper using the vendored arkenfox baseline plus repo overrides
- Tor Browser and Mullvad Browser keep their upstream browser privacy model; the repo adds local wrapper containment only
- browser wrappers are local host containment, not VM-equivalent isolation
- the paranoid browser wrappers now use a tighter minimal `/etc` allowlist rather than broad `/etc`

### Module structure
```
flake.nix (exports nixosModules library)
templates/default/ (reference implementation)
├── hosts/nixos/default.nix
│   ├── templates/default/hosts/nixos/fs-layout.nix
│   ├── templates/default/hosts/nixos/hardware-target.nix
│   ├── modules/core/options.nix (via hardening.nixosModules)
│   ├── modules/core/boot.nix
│   ├── modules/core/users.nix
│   ├── modules/desktop/base.nix
│   │   └── modules/desktop/theme.nix
│   ├── modules/security/base.nix
│   │   ├── modules/security/governance.nix
│   │   ├── modules/security/networking.nix
│   │   ├── modules/security/wireguard.nix
│   │   ├── modules/security/browser.nix
│   │   │   └── modules/security/sandbox-core.nix
│   │   ├── modules/security/impermanence.nix
│   │   ├── modules/security/secrets.nix
│   │   ├── modules/security/secure-boot.nix
│   │   ├── modules/security/flatpak.nix
│   │   ├── modules/security/scanners.nix
│   │   ├── modules/security/vm-tooling.nix
│   │   ├── modules/security/sandboxed-apps.nix
│   │   │   └── modules/security/sandbox-core.nix
│   │   ├── modules/security/privacy.nix
│   │   └── modules/security/user-profile-binding.nix
│   ├── modules/gpu/nvidia.nix
│   ├── modules/gpu/amd.nix
│   ├── profiles/paranoid.nix
│   └── profiles/daily.nix (specialisation)
│       ├── modules/desktop/gaming.nix
│       │   ├── modules/desktop/vr.nix
│       │   └── modules/desktop/controllers.nix
├── home-manager modules (templates/default/accounts/home/)
│   ├── ghost.nix, player.nix (per-user)
│   └── common.nix (shared baseline via hardening.home-common)
└── flake inputs (home-manager, stylix, impermanence, lanzaboote, agenix)
```

### Sandbox model
- `modules/security/sandbox-core.nix` is the shared bubblewrap constructor
- browser and app wrappers are thin policy layers over that constructor
- wrappers now clear inherited environment variables first and then repopulate only explicit values
- filtered D-Bus via `xdg-dbus-proxy` remains the intended path when enabled
- broad home binds and broad `/var` binds are not part of the default wrapper posture

### Flatpak model
- Flatpak is enabled repo-wide
- Flathub is bootstrapped automatically
- Flatpak is the containment layer for relatively trusted daily GUI apps
- higher-risk software should stay in wrappers or VMs instead of being treated as “safe because Flatpak”
- Signal is intended as a Flatpak path, including on paranoid

### Network model
- both profiles currently use Mullvad app mode by default
- the self-owned WireGuard path exists in-repo but is staged off by default
- when that staged path is enabled later, it requires a pinned literal endpoint `IP:port`
- the staged path owns nftables directly and is designed to avoid a standing non-tunnel DNS exception
- endpoint rotation remains an explicit operator maintenance task when that path is enabled

### VM model
The repo ships a host-side VM tooling layer in `modules/security/vm-tooling.nix` with four canonical classes:
- `trusted-work-vm`
- `risky-browser-vm`
- `malware-research-vm`
- `throwaway-untrusted-file-vm`

Current support boundary:
- host-side class tooling exists
- repo-managed NAT and isolated libvirt networks exist
- class policy is encoded in the launcher and documented in the repo
- guest templates and guest-hardening practice still need live validation

### Monitoring / integrity model
- paranoid enables the Linux audit subsystem and `auditd`
- repo custom audit rules exist but remain staged off by default due to a known nixpkgs compatibility issue
- AppArmor currently means framework enablement plus D-Bus mediation baseline
- custom repo-maintained AppArmor profiles are deferred
- ClamAV and AIDE are present as monitoring/integrity layers
- their scope is now explicitly persistence-aware: durable user/system state, `/boot`, and NixOS system-profile links
- they still need live timer/service validation on the target machine
- they do not prove safety against an already-compromised live kernel; they are file/persistence integrity layers, not a runtime kernel attestation system

## 4. Frozen current-stage decisions
- KDE Plasma 6 + greetd/regreet (Wayland-native) remain the desktop target
- NVIDIA remains enabled initially for target-hardware reliability
- Windows is not part of the steady-state design
- swap remains zram plus an 8 GiB Btrfs swapfile on the daily profile
- daily keeps Steam, VR, Signal, Bitwarden, and general social/desktop compatibility in scope
- paranoid forbids Steam, VR, and Vesktop by default; Signal remains in scope through Flatpak
- controllers are enabled on daily and disabled on paranoid
- Firefox Sync remains disabled by policy
- `nosmt=force` stays paranoid-only
- `init_on_free=1` stays paranoid-only
- wrapped daily apps remain same-kernel containment only
- profile-user binding is enforced via account locking (daily locks ghost, paranoid locks player); the experimental PAM approach remains disabled

## 5. Current pipeline

### Current-stage blocking pipeline
- `docs/pipeline/INSTALL-GUIDE.md`
- `docs/pipeline/TEST-PLAN.md`

### Current-stage support docs
- `docs/maps/SECURITY-SURFACES.md`
- `scripts/README.md`
- `tests/README.md`

### Deferred-only pipeline
- `docs/pipeline/POST-STABILITY.md`

### Operator-local (gitignored)
- `templates/default/hosts/nixos/local.nix` — per-install hardware quirks, conditionally imported by `hosts/nixos/default.nix`; never tracked
- `LOCAL-NOTES.md` (if the operator creates it) — personal notes that must not be published; gitignored
- `switch.log` — transient nixos-rebuild artefact; gitignored

## 6. Support boundary and non-claims
The repo can reasonably claim:
- explicit profile split
- explicit persistence model
- explicit same-kernel wrapper limits
- explicit staged-vs-baseline separation
- explicit VM escalation path for riskier work

The repo must not claim:
- wrapper isolation is VM-equivalent
- the desktop stack is high assurance
- static review alone proves runtime safety
- staged features are part of the baseline before validation

## 7. Removed or rejected ideas
These are not current policy:
- shared Whonix-style machine-id on the host
- describing Tor Browser or Mullvad Browser as arkenfox-managed
- describing daily Firefox as arkenfox-managed
- enabling PAM-based profile-binding (superseded by account locking in `users.nix`)
- treating repo custom audit rules as baseline when they are still staged off

## 8. What counts as post-stability work
Examples of non-blocking work after the first stable baseline:
- Secure Boot and TPM rollout
- re-enabling repo custom audit rules after the upstream issue is fixed and revalidated
- custom AppArmor policy library
- seccomp and Landlock wrapper work
- guest-template refinement for VM classes
- tighter browser/runtime containment trials that are not required for the current minimum functional state
