# Security surfaces and explicit trust boundaries

This file maps the current repo security model. It is not a proof document.

## 1. Boundary summary

### Claims the repo can reasonably make
- root is ephemeral when impermanence is enabled
- users active on different profiles have distinct home persistence models (template-defined)
- inactive profile home filesystems are not mounted, and boot-time invariants check that separation
- the paranoid profile defaults to sandboxed browsers
- daily uses normal Firefox with repo-managed enterprise policies
- paranoid Firefox uses a sandboxed wrapper plus vendored arkenfox baseline and repo overrides
- AppArmor framework baseline is enabled
- the Linux audit subsystem and `auditd` are enabled on paranoid
- VM tooling exists on paranoid for escalating higher-risk work out of same-kernel wrappers

### Claims the repo must not make
- bubblewrap wrappers are VM-equivalent isolation
- the desktop stack is high assurance
- Flatpak makes hostile software safe
- staged features are baseline-ready before validation
- static review is runtime proof

## 2. Residual surfaces in the current paranoid baseline

### 2.1 Shared kernel
All wrappers still share the host kernel.

### 2.2 GPU exposure
Wrapped browsers may expose GPU devices.

### 2.3 GUI/socket exposure
Wrapped browsers still rely on desktop graphics/session sockets.

### 2.4 PipeWire / Pulse exposure
Audio/video-related runtime surfaces remain reachable where allowed.

### 2.5 Portal / D-Bus exposure
Filtered D-Bus and portals remain part of the browser/app wrapper model.

### 2.6 Network access from wrapped browsers
Wrapped browsers keep network access unless you move the task into a VM.

### 2.7 Flatpak as a mixed-trust layer
Flatpak is enabled for relatively trusted GUI apps, not as the hostile-workload boundary.

### 2.8 Full desktop environment
Desktop environment is optional via `myOS.desktopEnvironment` option:
- `plasma` (default): KDE Plasma 6 + greetd/regreet + normal desktop services
- `hyprland`: Hyprland Wayland compositor + greetd/regreet
- `none`: Manual Wayland compositor setup (no greeter)

### 2.9 NVIDIA stack
The current baseline still accepts NVIDIA complexity for target-hardware reliability.

### 2.10 Persistence allowlists
Selected state still persists by design.

### 2.11 File-based monitoring limits
ClamAV and AIDE can watch durable files and boot-survival surfaces, but they cannot guarantee detection of an already-compromised live kernel.

### 2.12 VM tooling is available, not automatic
Risky tasks still depend on operator discipline.

## 3. Daily specialization weakenings

### 3.1 `sandbox.browsers = false`
Daily uses normal Firefox instead of sandboxed browsers for its main browser path.

### 3.2 `sandbox.x11 = true`
Daily re-enables X11 inside wrappers for compatibility.

### 3.3 `sandbox.apps = true`
Daily enables wrapped non-Flatpak apps via the sandbox framework.

### 3.4 `sandbox.vms = false`
Daily disables the VM tooling layer.

### 3.5 `disableSMT = false`
Daily re-enables SMT.

### 3.6 `usbRestrict = false`
Daily permits normal USB behavior.

### 3.7 `auditd = false`
Daily disables `auditd` and the audit subsystem baseline used on paranoid.

### 3.8 `ptraceScope = 1`
Daily relaxes ptrace restrictions.

### 3.9 selected kernel relaxations
Daily relaxes several kernel hardening choices compared with paranoid.

## 4. Staged but not baseline
These remain intentionally outside the first stable baseline:
- Secure Boot via Lanzaboote
- TPM-bound unlock
- self-owned WireGuard host path
- repo custom audit rules
- custom AppArmor profile library
- wrapper seccomp
- wrapper Landlock
- PAM profile-binding (superseded by account locking in `users.nix`)

## 5. Operator expectation
Use the repo as a hardened workstation baseline.

Escalation rule:
- ordinary browsing: daily Firefox or paranoid wrapped browser, depending on task and trust level
- suspicious browsing: `risky-browser-vm`
- unknown files: `throwaway-untrusted-file-vm`
- clearly hostile code: `malware-research-vm`

Do not treat same-kernel wrappers as the malware boundary.
