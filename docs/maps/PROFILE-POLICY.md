# Profile policy

This file defines the intended governance model for the repo.

## 1. Canonical model

### `base`
`base` is **not** a bootable profile.

`base` means the shared hardening baseline encoded across:
- `hosts/nixos/default.nix`
- `modules/core/*`
- `modules/security/*`
- shared desktop stack in `modules/desktop/base.nix`

This is the common policy substrate that both boot states inherit.

### `paranoid`
`paranoid` is the default boot state.
It instantiates the shared base with the strongest workstation-safe settings the repo currently considers baseline for `ghost`.

Intent:
- keep same-kernel desktop usability
- maximize hardening and privacy within that limit
- prefer wrappers and VMs over compatibility
- avoid gaming/social relaxations unless explicitly justified

### `daily`
`daily` is a specialization that instantiates the same shared base, then softens explicit controls for `player`.

Intent:
- remain hardened and privacy-aware
- re-enable the compatibility required for socialization, gaming, and ordinary desktop recovery
- make each relaxation explicit and auditable

### `ghost`
`ghost` is the hardened workspace account.
Expected boot state: `paranoid`.

### `player`
`player` is the daily desktop account.
Expected boot state: `daily`.

## 2. Policy rule set

### Rule A: shared base first
A control should live in the shared base unless there is a concrete reason it must differ between `paranoid` and `daily`.

### Rule B: relaxations must be explicit
`daily` should only override base behavior when the compatibility gain is real and documented.

### Rule C: `paranoid` is workstation-hard, not appliance-hard
The repo is a hardened workstation, not a high-assurance appliance.
`paranoid` should push hardening as far as possible **without lying** about the residual desktop/kernel exposure.

### Rule D: phase separation matters
Every notable knob belongs to exactly one phase/state:
- baseline now
- softened in `daily`
- staged pending validation
- deferred post-stability
- rejected for this repo

### Rule E: source influence is not source obedience
External guides influence the repo. They do not automatically become policy.

## 3. Current architectural reading

The current code already fits this model reasonably well:
- shared base policy lives in `modules/security/base.nix`, `modules/core/boot.nix`, `modules/core/users.nix`, `modules/security/networking.nix`, `modules/security/privacy.nix`, `modules/security/browser.nix`, `modules/security/impermanence.nix`, and related imports
- `profiles/paranoid.nix` defines the hardened workstation defaults
- `profiles/daily.nix` is an explicit relaxation layer

So the repo does **not** need a new standalone `base` profile file right now.
That would likely add naming symmetry without adding real clarity.

## 4. Current policy verdict

### Good parts
- the profile split is real, not rhetorical
- most important `daily` weakenings are explicit in `profiles/daily.nix`
- governance assertions already enforce several paranoid invariants
- staged surfaces are mostly kept out of the baseline path

### Weak parts
- `users.mutableUsers = true` is operationally understandable but should be tracked as an explicit temporary policy decision

## 5. Decision on repo structure

Keep the current file split.

Reason:
- installation, testing, recovery, and policy are different document roles
- merging them would reduce auditability
- the real missing piece was a navigation/governance layer, not fewer files

This folder is that layer.

## 6. Immediate governance decisions

### `users.mutableUsers`
Current state: keep `true` for now.

Reason:
- current install flow still expects imperative password setting during install/first boot
- current repo does not yet ship a finished encrypted-secret pipeline for user password material
- switching to `false` before that exists would make user lifecycle more brittle and less recoverable

Future move condition:
- only switch after password material is delivered declaratively through `hashedPasswordFile` or equivalent secret-backed inputs and the install docs are rewritten around that model

### Kernel posture
Current state: keep the stock kernel package set with an explicit hardening layer.

Reason:
- the repo already encodes a meaningful hardening subset through boot params, sysctls, module blacklist, `io_uring` restrictions, ptrace restrictions, and profile-specific differences
- `linux-hardened` is not currently chosen because baseline reliability on the target workstation still matters more than theoretical completeness

### Staged kernel knobs
These stay staged until runtime validation and recovery confidence improve:
- `module.sig_enforce=1`
- `oops=panic`
- `kernel.modules_disabled=1`
- stronger lockdown-style posture not currently encoded

## 7. Reading map

For the actual knob inventory, go to `HARDENING-TRACKER.md`.
For source-by-source coverage, go to `SOURCE-COVERAGE.md`.
