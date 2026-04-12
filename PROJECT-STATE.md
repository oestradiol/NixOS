# PROJECT STATE

## Purpose
Canonical current state: architecture, policy, constraints, implemented support scope, explicit decisions, explicit rejections, and deferred work.

## Repository role
Single NixOS host with two boot specialisations:
- `daily`: maximally hardened within daily usability constraints
- `paranoid`: maximally hardened within paranoid constraints, with expected breakage

Separate users:
- `player` for daily
- `ghost` for paranoid

## Frozen operational decisions
- KDE Plasma 6 remains the desktop target; current design assumes SDDM login and Wayland-first sessions.
- NVIDIA remains enabled initially on both profiles for target-hardware reliability.
- Windows is not part of the steady-state design.
- swap remains split between zram and an 8GB Btrfs swapfile on `@swap`.
- daily keeps Steam, VR, Signal, Bitwarden, and general social/desktop compatibility.
- paranoid forbids Steam, VR, and Vesktop by default; Signal remains allowed.
- controllers are enabled on daily and disabled on paranoid.
- Firefox Sync remains disabled by policy.
- AppArmor framework stays enabled on both profiles; custom repo-maintained AppArmor policies remain deferred until the framework baseline is live-validated.
- `init_on_free=1` stays paranoid-only.
- `nosmt=force` stays paranoid-only.
- selected non-Flatpak daily apps are wrapped with bubblewrap; Signal remains a Flatpak path.

## Current architecture

### System model
- one NixOS installation
- encrypted root with tmpfs root + impermanence
- explicit `/persist` allowlist for state survival
- boot specialisations select profile policy without separate installs
- staged Secure Boot + TPM rollout after first stable encrypted boot

### Repository shape
- `hosts/nixos/` wires host-specific layout and hardware references
- `profiles/daily.nix` and `profiles/paranoid.nix` define profile overrides
- `modules/core/` defines base system wiring and option surface
- `modules/security/` defines hardening, privacy, sandboxing, networking, persistence, governance, secrets, VM tooling, and browser policy
- `docs/` defines install/test/recovery/performance procedures
- `REFERENCES.md` is the canonical external reference ledger
- `AUDITS.md` tracks audit coverage, validation status, source-backed claims, and pending audit work

### Bubblewrap architecture
- one shared sandbox constructor in `modules/security/sandbox-core.nix`
- browser and app modules are thin wrappers over that core
- default posture is strict; every relaxation must be explicit per wrapper
- exact runtime socket exposure replaces broad `/run/user/$UID` exposure
- broad home and broad `/var` binds are not used by default
- filtered D-Bus via `xdg-dbus-proxy` is the intended wrapper path when enabled

### Browser architecture
- daily Firefox uses an in-repo arkenfox-derived baseline, relaxed only where daily usability needs it
- paranoid `safe-firefox` uses the same baseline without the daily relaxations and runs inside the shared sandbox core
- Tor Browser and Mullvad Browser keep their upstream browser-hardening model; the repo adds local wrapper containment only
- wrapper scope is local containment on the host, not VM-equivalent isolation

### AppArmor policy
- current implemented state is framework enablement plus D-Bus mediation baseline
- reboot is required when first enabling the framework
- repo-maintained AppArmor profiles remain deferred
- `killUnconfinedConfinables` stays off for now and is only a post-stability decision
- any future profile rollout should start with explicit validation of loaded profiles, denial logs, and complain/enforce state

### Network architecture
- daily uses Mullvad app mode
- paranoid uses self-owned `networking.wireguard` with nftables killswitch
- paranoid requires a pinned literal endpoint `IP:port`
- paranoid allows no standing non-tunnel DNS exception
- exact non-WireGuard egress exception is limited to that endpoint `IP:port`
- endpoint rotation is therefore an explicit operator maintenance task
- `networking.wireguard` is kept for now because it already matches the repo’s deterministic nftables and option surface; a `systemd.network` migration is deferred unless live validation exposes routing or MTU problems

### VM architecture

#### VM workflow classes
Four VM classes are now canonical:
- `trusted-work-vm`: persistent VM for lower-risk work that still benefits from separation from the main host
- `risky-browser-vm`: browser-focused VM for sites or workflows that should not rely on same-kernel browser containment alone
- `malware-research-vm`: high-risk analysis VM for unknown binaries or clearly hostile content; strongest separation, highest friction
- `throwaway-untrusted-file-vm`: disposable VM for opening unknown documents or archives with minimal host trust

#### VM workflow layers
Every class is defined across these six layers:
1. threat class and intended use
2. host-to-guest boundary policy
3. network policy
4. disposability policy
5. guest hardening baseline
6. operator workflow

#### Current class definitions

##### `trusted-work-vm`
1. Threat class: lower-risk work that still should not live directly on the host.
2. Host-to-guest boundary: clipboard allowed only when intentionally needed; no bidirectional trust by default, no shared folders by default, explicit import/export only, USB passthrough off by default, drag-and-drop off by default, audio allowed if needed, display integration minimal, guest agent justified only if a specific workflow needs it.
3. Network: NAT-only by default; host-VPN-only acceptable when the host network path is already trusted enough for the task.
4. Disposability: persistent VM allowed; snapshot before major changes recommended.
5. Guest baseline: auto-updates on, guest firewall on, browser hardened, no host-share auto-mounts, no password reuse, no identity reuse if the task does not require it.
6. Operator workflow: use for ordinary compartmentalized work that benefits from separation but does not justify the higher-friction classes.

##### `risky-browser-vm`
1. Threat class: websites or web apps too risky for host browsers or same-kernel wrappers alone.
2. Host-to-guest boundary: clipboard off by default, temporary host→guest transfer only when necessary, no shared folders, no USB passthrough, no drag-and-drop, audio only if the site genuinely needs it, minimal display integration, guest agent discouraged.
3. Network: NAT-only or VPN-inside-guest; prefer a path that keeps host browsing identity separate from the guest.
4. Disposability: snapshot reset after risky sessions strongly preferred; disposable overlays acceptable.
5. Guest baseline: hardened browser only, auto-updates on, guest firewall on, no host credentials, no sync accounts reused from the host.
6. Operator workflow: use for suspicious or high-tracking browsing; if browser containment on the host feels insufficient, move the task here instead of weakening host policy.

##### `malware-research-vm`
1. Threat class: hostile binaries or content with active exploitation risk.
2. Host-to-guest boundary: clipboard off, shared folders off, USB passthrough off, drag-and-drop off, audio off unless the sample requires it, minimal display integration, guest agent off unless strictly justified.
3. Network: no network by default; isolated internal network or tightly staged research network only when the task requires it.
4. Disposability: disposable or snapshot-reset-first only; treat persistence as exceptional.
5. Guest baseline: separate identity, no reused passwords, guest firewall on, updates staged carefully, no host shares, no productivity accounts, minimal software footprint.
6. Operator workflow: for unknown binaries or malware-adjacent research, do not rely on bubblewrap; use this class or a stricter offline analysis path only.

##### `throwaway-untrusted-file-vm`
1. Threat class: unknown documents, archives, or media files that are risky but do not require a full malware-research environment.
2. Host-to-guest boundary: clipboard off by default, no shared folders, explicit one-way import folder only, USB passthrough off, drag-and-drop off, audio only if the file type needs it, minimal display integration, guest agent discouraged.
3. Network: no network by default; temporary NAT only if the file must fetch dependencies to render.
4. Disposability: disposable overlay or snapshot reset after each use.
5. Guest baseline: small guest image, auto-updates on, guest firewall on, no account reuse, no host-share auto-mounts.
6. Operator workflow: open unknown files here first; promote to `malware-research-vm` if the behavior looks actively suspicious.

- `modules/security/vm-tooling.nix` is the host capability/tooling layer for the VM workflow defined below
- it provides libvirt/QEMU/KVM support, repo-managed NAT + isolated networks, and the `repo-vm-class` launcher
- the launcher encodes class defaults for boundary policy, network mode, disposability, guest boot shape, and minimal operator workflow
- host defaults remain conservative: no USB redirection by default, no automatic browser/app coupling, and no implicit clipboard or host-share trust
- the workflow is explicitly defined across four classes and six policy layers
- host-side enforcement is automated through repo-managed libvirt networks plus the `repo-vm-class` launcher
- guest image contents still remain operator-supplied and must be validated per class
- guest templates and real-world tuning still need live trials before any class is treated as fully proven

## Policy

### Daily policy
Goal: preserve gaming, VR, socialization, normal browsing, and desktop reliability while enabling low-friction hardening unlikely to break normal use.

Daily policy means:
- enable transparent or low-cost hardening by default
- avoid known high-breakage hardening unless already proven acceptable for daily use
- keep browser use convenient while still anchored to an arkenfox-derived baseline
- allow app compatibility concessions where needed for daily-driver usability
- keep security/privacy controls explicit through options rather than ad hoc edits

### Paranoid policy
Goal: push host hardening, wrapper hardening, and network policy hard without pretending the repo can remove usability requirements or same-kernel limits. During the first staged rollout, paranoid only needs to reach minimum functional state after daily is already operable. After that, post-stability work treats paranoid as the place to pursue the maximum achievable hardening under the repo's stated constraints through careful trials and validation.

Paranoid policy means:
- enforce stronger hardening through explicit profile overrides
- require stricter governance assertions
- prefer pinned and deterministic network policy
- keep a usable desktop
- keep networked browsers
- keep Wayland/X11/display integration
- keep audio/portal/session usability
- treat bubblewrap wrappers as same-kernel containment, not sufficient hostile-workload isolation
- document all meaningful breakage and workaround paths in `docs/RECOVERY.md` and validate them through `docs/TEST-PLAN.md`

## Constraints

### Daily constraints
Daily must still support:
- gaming
- VR
- controllers and Bluetooth accessories
- desktop portals and file chooser flows
- social and messaging apps
- ordinary browsing without wrapper friction
- NVIDIA reliability on the target hardware path

### Paranoid constraints
Paranoid remains constrained by:
- same-kernel boundary for bubblewrap wrappers
- browser need for network access
- required Wayland/X11/display integration
- required audio/portal/session usability
- possible GPU/runtime socket needs for usability
- incomplete hostile-workload VM workflow
- pinned-endpoint WireGuard maintenance when the provider changes relay IPs

These constraints define the current meaning of “maximally hardened within paranoid constraints.”

## Implemented state

### Profiles
`daily` currently enables:
- gaming and VR support
- Firefox with an arkenfox-derived baseline plus explicit daily relaxations
- tightened bubblewrap wrappers for VRCX and Windsurf
- Mullvad app mode
- desktop compatibility-oriented defaults

`paranoid` currently enables:
- tighter kernel and system hardening
- browser wrappers
- self-owned WireGuard with pinned endpoint policy
- VM tooling layer
- stricter governance assertions

### Security and privacy state
Implemented now:
- tmpfs root + impermanence
- persisted host-local machine-id on both profiles
- zram plus Btrfs swapfile memory model
- shared bubblewrap core
- filtered D-Bus wrapper path
- exact persistence binds for wrapped apps
- paranoid pinned-endpoint WireGuard policy
- Linux audit subsystem + auditd + repo-maintained paranoid audit rules
- AppArmor framework baseline + D-Bus mediation baseline
- stricter firewall policy for paranoid
- service hardening for selected system services
- ClamAV and AIDE monitoring path
- flatpak remote bootstrap + portal baseline
- fwupd enabled on the base desktop path
- option-driven daily/paranoid hardening split

### Support scope statements
Current supported claims:
- daily Firefox is arkenfox-derived and intentionally relaxed only for daily usability constraints
- paranoid `safe-firefox` is arkenfox-derived and uses the stricter local baseline inside the wrapper
- daily app wrappers provide tightened daily containment for selected non-Flatpak apps
- paranoid browsers provide tightened local browser containment on the host
- paranoid audit path means the Linux audit subsystem is enabled, auditd is enabled, and a repo-maintained rule set is loaded
- AppArmor means the kernel framework and D-Bus mediation baseline are enabled; it does not imply a finished repo-maintained custom profile library yet
- VM tooling is available as a host capability layer

Current unsupported claims:
- wrapper layer is not VM-equivalent isolation
- VM class policy is not yet fully auto-enforced by code; parts remain procedural and test-driven
- seccomp and Landlock are not implemented in the wrapper core
- custom repo-maintained AppArmor policy coverage is not complete yet
- AppArmor follow-up still includes evaluating `killUnconfinedConfinables`, deciding complain-vs-enforce rollout strategy for new profiles, and validating denial-log / D-Bus mediation behavior after each policy addition
- Tor Browser and Mullvad Browser are not claimed to be maximally tightened yet; further containment trials are deferred

## Explicit decisions
- one host, two specialisations
- separate users for daily and paranoid
- tmpfs root + explicit persistence
- Secure Boot + TPM rollout staged after first stable encrypted boot
- daily remains usability-first within a hardened baseline
- paranoid remains security-first within explicit operational constraints
- machine-id stays host-local and unique on both profiles
- paranoid WireGuard endpoint must be a pinned literal `IP:port`
- wrapper logic stays centralized in the shared sandbox core
- Firefox hardening is maintained in-repo as a vendored arkenfox baseline with explicit local overrides
- `networking.wireguard` stays for now instead of a `systemd.network` migration because it already matches the current repo firewall design and secret wiring; migration remains conditional on live issues, not assumed necessary, and is tracked in `docs/POST-STABILITY.md` for evaluation if routing, MTU, DNS, or interface-ordering issues appear
- anything unfinished must be deferred into `docs/POST-STABILITY.md` / `AUDITS.md` or explicitly rejected

## Explicit rejections
- shared Whonix machine-id on the host
- documenting bubblewrap wrappers as strong isolation or VM-equivalent isolation
- hostname-based paranoid WireGuard endpoints
- standing non-WireGuard DNS exception for paranoid
- silently implying unfinished VM workflow policy is complete
- silently implying seccomp or Landlock are already active in the wrapper core
- silently implying AppArmor already has a finished repo-maintained policy set
- silently claiming Tor Browser or Mullvad Browser wrapper limits are fully explored already

## Deferred items
These remain deferred until implemented and live-validated:
- wrapper seccomp wiring
- wrapper Landlock wiring
- per-app seccomp policy generation
- stricter no-GPU browser variants
- further Tor Browser and Mullvad Browser containment trials
- stronger wrapper tightening after runtime proof where safe
- custom AppArmor policy rollout after framework-baseline validation
- VM workflow completion
- Secure Boot + TPM final rollout after daily stability
- hardened allocator rollout after stability testing
- greetd / tuigreet migration
- `modules_disabled=1` after module-load validation
- any experimental revisit of Whonix-style shared machine-id behavior, only as a documented experiment and not as current policy
- experimental `myOS.security.pamProfileBinding.enable` rollout after a dedicated lockout-recovery rehearsal

## Trust boundaries and truthfulness rules
- static review is not runtime proof
- wrapper behavior on target hardware remains subject to live validation
- doc claims must match code and current support scope
- unfinished work must exist somewhere on the pipeline: `PROJECT-STATE.md`, `AUDITS.md`, `docs/TEST-PLAN.md`, `docs/POST-STABILITY.md`, or `docs/RECOVERY.md`

## Known remaining trust gaps
Static review cannot prove:
- all wrappers behave correctly on the target GPU/session stack
- exact portal and D-Bus needs for every wrapped app on target hardware
- full boot/install/recovery success on the real machine
- full VM guest-isolation workflow quality without further policy work

## Canonical routing
- install prep only → `docs/PRE-INSTALL.md`
- install procedure only → `docs/INSTALL-GUIDE.md`
- current-stage validation only → `docs/TEST-PLAN.md`
- deferred/aggressive work only → `docs/POST-STABILITY.md`
- failure map and recovery only → `docs/RECOVERY.md`
- performance only → `docs/PERFORMANCE-NOTES.md`
- references / external-source ledger → `REFERENCES.md`
- audits, validations, source-backed claims, and pending audits → `AUDITS.md`
