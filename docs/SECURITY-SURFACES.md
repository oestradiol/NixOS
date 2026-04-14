# Security surfaces and explicit trust boundaries

This file documents the security model after the repository inversion:

- the **base system** is the hardened workstation baseline
- the default imported profile is **paranoid**
- the boot specialization is **daily**
- every daily weakening is meant to be explicit in code

This is not a proof document. It is a map of what is still exposed, what is deliberately relaxed, and what must not be over-trusted.

## 1. Boundary summary

### High-trust claims the repo can reasonably make

- root is ephemeral when impermanence is enabled
- root account is locked by default
- AppArmor baseline is enabled
- auditd baseline is enabled on the hardened workstation profile (custom audit rules staged off due to nixpkgs compatibility issue - see docs/POST-STABILITY.md)
- browser usage defaults to wrapped browsers rather than base Firefox
- wrapper defaults now keep **X11 off** inside sandboxes unless a profile explicitly re-enables it
- VM tooling is enabled on the hardened workstation profile so hostile work can be escalated out of same-kernel wrappers
- daily is now the explicit relaxation profile rather than the hidden default

### Claims the repo must **not** make

- bubblewrap wrappers are not VM-equivalent isolation
- sandboxed browsers are not strong enough for malware handling
- a normal KDE desktop with NVIDIA, portals, PipeWire, Flatpak, and same-kernel wrappers is not a high-assurance endpoint in the formal sense
- static configuration review is not runtime assurance
- WireGuard hardening is not active until the host supplies real Mullvad keys, endpoint, address, and server key

## 2. Residual surfaces in the hardened workstation baseline

These remain open on the default base/paranoid path.

### 2.1 Shared kernel

All wrappers share the host kernel. Any kernel LPE or kernel-adjacent driver flaw can collapse the wrapper boundary.

Residual risk:
- browser/app compromise can still become full host compromise through the kernel
- GPU, filesystem, namespace, or networking bugs remain high value

### 2.2 GPU device exposure

Wrapped browsers default to GPU access.

Residual risk:
- larger attack surface through DRM, Mesa, NVIDIA stack, and browser GPU paths
- renderer and shader paths remain exposed to hostile content

Why kept:
- a usable workstation browser without GPU access is often unstable or degraded

### 2.3 Wayland socket exposure

Wrapped browsers default to Wayland access.

Residual risk:
- weaker than no GUI access at all
- GUI metadata and compositor interaction remain in scope

Why kept:
- this is the minimum viable path for a modern desktop browser on Plasma Wayland

### 2.4 PipeWire / Pulse exposure

Wrapped browsers default to PipeWire and Pulse sockets.

Residual risk:
- audio stack remains reachable from compromised applications
- microphone/camera mediation still depends on portal and desktop behavior, not just bubblewrap

Why kept:
- notifications, audio, and video calls are normal workstation requirements

### 2.5 Portal / D-Bus exposure

Wrapped browsers use `xdg-dbus-proxy` and xdg-desktop-portal access remains allowed.

Residual risk:
- portal and D-Bus are large and subtle surfaces
- policy mistakes here can widen reach into host services
- filtered D-Bus is better than raw bus access, not equivalent to no bus access

Why kept:
- desktop file pickers, notifications, and other normal workstation behavior depend on portals

### 2.6 Network access from wrapped browsers

Wrapped browsers keep host networking.

Residual risk:
- browser compromise still gets direct network egress unless separately constrained by VPN/firewall/VM placement
- wrappers reduce local host reach more than they reduce remote control possibilities

Why kept:
- ordinary browsing requires network access

### 2.7 Flatpak as a mixed-trust layer

Flatpak remains enabled.

Residual risk:
- Flatpak sandboxing quality depends on per-app permissions and portal behavior
- users can still install poorly-confined Flatpaks
- Flatpak is another policy surface, not an assurance mechanism by itself

### 2.8 KDE Plasma 6 + SDDM + desktop services

The hardened baseline still keeps a full desktop.

Residual risk:
- large GUI and session surface
- display manager, shell integration, notification paths, portal integration, polkit, and user-session tooling remain reachable

Why kept:
- this repo is targeting a usable workstation, not a text-only appliance

### 2.9 NVIDIA stack

NVIDIA remains supported.

Residual risk:
- proprietary driver complexity
- larger kernel and userspace graphics surface
- a stronger isolation design would prefer fewer proprietary kernel-adjacent components

Why kept:
- target hardware compatibility

### 2.10 Persistence allowlists

Impermanence is present, but selected state remains persistent.

Residual risk:
- persistence in approved user paths can survive reboot
- compromise of SSH, GPG, application state, or messenger state can remain meaningful even with ephemeral root

### 2.11 VM tooling is available, not automatically enforced

The hardened baseline enables libvirt/QEMU tooling, but it does not automatically move risky workloads into VMs.

Residual risk:
- operators may still run hostile content in wrappers instead of VMs
- assurance depends on workflow discipline

## 3. Daily specialization weakenings

These are intentional weakenings relative to the hardened workstation baseline.

### 3.1 `sandbox.browsers = false`

Daily falls back to base Firefox instead of wrapped browsers.

Effect:
- removes the local containment layer around the main browser path
- expands host exposure to browser compromise

### 3.2 `sandbox.x11 = true`

Daily re-enables X11 inside wrappers for compatibility.

Effect:
- X11 becomes an explicit desktop compromise instead of an implicit one
- this is one of the largest same-session attack surface increases

### 3.3 `sandbox.apps = true`

Daily enables wrapped non-Flatpak apps like VRCX and Windsurf.

Effect:
- more convenience
- still same-kernel containment only
- more policy complexity

### 3.4 `sandbox.vms = false`

Daily disables the VM tooling layer.

Effect:
- encourages convenience over stronger isolation for risky tasks

### 3.5 `disableSMT = false`

Daily re-enables SMT.

Effect:
- better performance
- weaker side-channel posture

### 3.6 `usbRestrict = false`

Daily permits normal USB behavior.

Effect:
- easier peripheral use
- weaker stance against rogue USB devices

### 3.7 `auditd = false`

Daily disables auditd.

Effect:
- less forensic visibility
- lower noise and lower overhead

### 3.8 `ptraceScope = 1`

Daily relaxes ptrace restrictions.

Effect:
- broader debugging/introspection capability
- weaker boundary between same-user processes

### 3.9 kernel relaxations

Daily disables or relaxes:

- `init_on_free`
- `disableIcmpEcho`
- `kexecLoadDisabled`
- `sysrqRestrict`
- `ioUringDisabled`

Effect:
- reduced memory-hygiene hardening
- larger kernel surface
- better compatibility and recovery for gaming/social workflows

## 4. Staged but not yet trusted

These remain intentionally staged off by default because enabling them without live validation can brick or destabilize the workstation:

- Secure Boot via Lanzaboote
- TPM-bound LUKS workflow
- `module.sig_enforce=1`
- `kernel.modules_disabled=1`
- hardened memory allocator
- self-owned Mullvad WireGuard on the base host until real secrets and endpoints are provisioned

## 5. Operator expectations

Use this repo as a hardened workstation baseline, not as a magical secure desktop.

Escalation rule:
- ordinary browsing: wrapped browser on the hardened profile
- suspicious browsing: risky-browser VM
- unknown files: throwaway-untrusted-file VM
- clearly hostile code: malware-research VM

Do not treat the browser wrappers as sufficient for malware work.
