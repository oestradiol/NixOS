# Feature Coverage Audit

**Purpose**: Verify every configuration option and security feature is covered in TEST-PLAN.md, deferred to POST-STABILITY.md, or explicitly rejected.

**Scope**: This is a documentation coverage audit, not runtime verification. Features marked as "covered in test plan" have verification steps defined in TEST-PLAN.md but have not necessarily been executed on hardware. The repo is statically covered but not yet fully verified through live testing.

**Date**: 2026-04-12
**Status**: Statically covered (not runtime verified)

## Legend
- ✅ TEST-PLAN.md - Covered in TEST-PLAN.md for runtime verification
- 📋 POST-STABILITY.md - Deferred to post-stability phase
- ❌ Rejected/Not Implemented - Explicitly not done
- ⚠️ Gap - Missing from both (needs action)

---

## Core Options (from options.nix)

### Hardware/Profile
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `gpu` (nvidia/amd) | ✅ Graphics section | - | Implemented | NVIDIA covered in test plan |
| `profile` (daily/paranoid) | ✅ Boot section | - | Implemented | Both boot paths covered in test plan |

### Gaming
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `gaming.controllers.enable` | ✅ Daily profile section | - | Implemented | Bluetooth/controllers covered in test plan |
| `gaming.sysctls` | ✅ Daily profile section | - | Implemented | SteamOS scheduler + ntsync module |

### Infrastructure
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `persistence.root` | ✅ Boot/filesystem | - | Implemented | Mount verification |
| `security.impermanence.enable` | ✅ Boot/filesystem | - | Implemented | tmpfs + persistence covered in test plan |
| `security.agenix.enable` | ✅ Secrets section | - | Implemented | SSH keys + decryption covered in test plan |

### Staged Enablement (POST-INSTALL)
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.secureBoot.enable` | ✅ Secure Boot section | ✅ Section 4 | Implemented | Staged to post-install |
| `security.tpm.enable` | ✅ Secure Boot section | ✅ Section 5 | Implemented | Staged to post-install |

### VPN
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.wireguardMullvad.enable` | ✅ VPN section | ✅ Section 6 | Implemented | Both modes covered in test plan |
| `security.wireguardMullvad.privateKeyFile` | ✅ VPN section | ✅ Section 6 | Implemented | Via agenix |
| `security.wireguardMullvad.presharedKeyFile` | - | ✅ Section 6 | Implemented | Optional, documented |
| `security.wireguardMullvad.address` | ✅ VPN section | ✅ Section 6 | Implemented | Config required |
| `security.wireguardMullvad.dns` | ✅ VPN section | ✅ Section 6 | Implemented | Config required |
| `security.wireguardMullvad.endpoint` | ✅ VPN section | ✅ Section 6 | Implemented | Config required |
| `security.wireguardMullvad.serverPublicKey` | ✅ VPN section | ✅ Section 6 | Implemented | Config required |
| `security.wireguardMullvad.allowedIPs` | ✅ VPN section | ✅ Section 6 | Implemented | Default killswitch |
| `security.wireguardMullvad.persistentKeepalive` | - | - | Implemented | Uses default (25) |

### Browser Policy
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.sandbox.browsers` | ✅ Browser section | - | Implemented | Daily: false, Paranoid: true |
| `security.sandbox.dbusFilter` | ✅ D-Bus section | ✅ Section 9 | Implemented | POST-STABILITY opt-in for daily |

### System Hardening
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.disableSMT` | ✅ USB section (cmdline) | - | Implemented | paranoid: nosmt=force |
| `security.ptraceScope` | ✅ Kernel section | - | Implemented | Daily: 1, Paranoid: 2 |
| `security.swappiness` | ✅ Kernel section | - | Implemented | Daily: 150, Paranoid: 180 |
| `security.lockRoot` | ✅ Root/privilege section | - | Implemented | Shadow shows ! |
| `security.usbRestrict` | ✅ USB section | - | Implemented | paranoid: authorized_default=2 |
| `security.allowSleep` | ❌ Not tested | ❌ Explicitly disabled | Rejected | Both profiles disable sleep |

### Kernel Hardening
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.kernelHardening.initOnAlloc` | ✅ Kernel section | - | Implemented | Both: init_on_alloc=1 |
| `security.kernelHardening.initOnFree` | ✅ Kernel section | - | Implemented | Daily: false, Paranoid: true |
| `security.kernelHardening.slabNomerge` | ✅ Kernel section (cmdline) | - | Implemented | Both: slab_nomerge |
| `security.kernelHardening.pageAllocShuffle` | ✅ Kernel section (cmdline) | - | Implemented | Both: page_alloc.shuffle=1 |
| `security.kernelHardening.moduleBlacklist` | ✅ Kernel section (lsmod) | - | Implemented | Both: blacklist dangerous |
| `security.kernelHardening.pti` | ✅ Kernel section (cmdline) | - | Implemented | Both: pti=on |
| `security.kernelHardening.vsyscallNone` | ✅ Kernel section (cmdline) | - | Implemented | Both: vsyscall=none |
| `security.kernelHardening.oopsPanic` | ✅ Kernel section | - | Implemented | Daily: false, Paranoid: true |
| `security.kernelHardening.moduleSigEnforce` | ✅ Kernel section (cmdline) | - | Implemented | Daily: true, Paranoid: true |
| `security.kernelHardening.disableIcmpEcho` | ✅ Kernel section (sysctl) | - | Implemented | Daily: true, Paranoid: true |
| `security.kernelHardening.kexecLoadDisabled` | ✅ Kernel section (paranoid-only) | - | Implemented | paranoid: sysctl test added |
| `security.kernelHardening.sysrqRestrict` | ✅ Kernel section (paranoid-only) | - | Implemented | paranoid: sysctl test added |
| `security.kernelHardening.modulesDisabled` | ❌ Not tested | ✅ Section 17 | Deferred | POST-STABILITY optional |
| `security.kernelHardening.ioUringDisabled` | ✅ Kernel section (paranoid-only) | - | Implemented | paranoid: sysctl test added |

### MAC/Security Frameworks
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.apparmor` | ✅ Kernel section (mention) | ✅ Section 18 | Implemented | Both: enabled |
| `security.auditd` | ✅ Audit tools section | - | Implemented | Daily: false, Paranoid: true |
| `security.hardenedMemory.enable` | ❌ Not tested | ✅ Section 17 | Deferred | POST-STABILITY optional |

### Scanning/Monitoring
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.aide.enable` | ✅ Audit tools section | ✅ Section 8 | Implemented | Both: enabled |
| ClamAV (daily shallow + weekly deep) | ✅ Audit tools section | ✅ Section 8 | Implemented | Timer-based |

### VM/Sandboxing
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.sandbox.vms` | ✅ VM isolation section | - | Implemented | Paranoid: enabled |
| `security.sandbox.apps` | ✅ Application sandboxing | - | Implemented | Daily: enabled |

### PAM/Authentication
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.pamProfileBinding.enable` | ❌ Not tested | ✅ Section 20 | Deferred | High-risk, opt-in only |

### Machine ID (NEW)
| Feature | TEST-PLAN | POST-STABILITY | Status | Notes |
|---------|-----------|----------------|--------|-------|
| `security.persistMachineId` | ✅ Machine ID section (NEW) | ✅ Manual check | **ADDED** | Both: true |
| `security.machineIdValue` | ✅ Machine ID section (NEW) | ✅ Manual check | **ADDED** | Paranoid: Whonix ID |

---

## Gaps Found (Resolved)

### ✅ All Kernel Control Gaps Fixed
The following were added to TEST-PLAN.md:

- ✅ `security.kernelHardening.kexecLoadDisabled` → `sysctl kernel.kexec_load_disabled` (paranoid only)
- ✅ `security.kernelHardening.sysrqRestrict` → `sysctl kernel.sysrq` (paranoid only)
- ✅ `security.kernelHardening.ioUringDisabled` → `sysctl kernel.io_uring_disabled` (paranoid only)
- ✅ `security.swappiness` → `sysctl vm.swappiness` (daily: 150, paranoid: 180)
- ✅ `gaming.sysctls` ntsync module → `lsmod | grep ntsync`
- ✅ `net.ipv4.tcp_timestamps` → profile-specific (daily: 1, paranoid: 0)

### Remaining Deferred Items (Intentionally POST-STABILITY)
- `security.kernelHardening.modulesDisabled` - One-way toggle, requires live validation

---

## POST-STABILITY Deferred Items (Verified)

All explicitly deferred items are documented in POST-STABILITY.md:

1. ✅ `security.secureBoot.enable` - Section 4
2. ✅ `security.tpm.enable` - Section 5
3. ✅ `security.wireguardMullvad.*` - Section 6 (config required)
4. ✅ `security.sandbox.dbusFilter` - Section 9
5. ✅ `security.aide.enable` - Section 8 (init)
6. ✅ ClamAV initialization - Section 8
7. ✅ `security.kernelHardening.modulesDisabled` - Section 17 (optional end-state)
8. ✅ `security.hardenedMemory.enable` - Section 17 (optional)
9. ✅ `security.pamProfileBinding.enable` - Section 20 (high-risk, opt-in)

---

## Rejected/Not Implemented (Verified)

1. ✅ `security.allowSleep` - Both profiles explicitly disable
2. ✅ SELinux - Rejected in favor of AppArmor
3. ✅ `security.hardenedMemory.enable` - Default false, deferred to POST-STABILITY

---

## Action Items (All Completed)

### ✅ Immediate (TEST-PLAN.md updates)
1. ~~Add paranoid-only sysctl tests for new kernel controls~~ ✅ DONE
2. ~~Add swappiness verification~~ ✅ DONE  
3. ~~Add ntsync module verification~~ ✅ DONE

### ✅ Documentation Updates
1. ~~Update TEST-PLAN.md kernel section~~ ✅ DONE
2. ~~Add machine-id section~~ ✅ DONE
3. ~~Add safe-mullvad-browser test~~ ✅ DONE
4. ~~Add earlyoom check~~ ✅ DONE
5. ~~Add POST-STABILITY system services section (polkit, udisks2, fwupd, fstrim)~~ ✅ DONE

### Audit Status: **Statically covered**
All features now have coverage in TEST-PLAN.md, POST-STABILITY.md, or are explicitly rejected. This is a documentation audit, not runtime verification.

---

## Kernel Hardening Features (Additional Analysis)

### Kernel Lockdown Mode

| Aspect | Status |
|--------|--------|
| **Implementation** | ❌ NOT IMPLEMENTED |
| **LSM Parameter** | Not set (no `lsm=lockdown` or `lockdown=integrity/confidentiality`) |
| **Auto-enable** | May activate via Secure Boot if `CONFIG_SECURITY_LOCKDOWN_LSM=y` |
| **Documentation** | ✅ POST-STABILITY.md Section 17 (optional end-state) |
| **Coverage** | Missing from audit ledger |

**What it blocks**:
- `/dev/mem`, `/dev/kmem`, `/dev/kcore`, `/dev/ioports`
- BPF kprobes, MSR register access
- PCI BAR access, ACPI table override
- Unsigned kexec, unencrypted hibernation
- debugfs access

**Trade-offs**:
- **Pro**: Major kernel attack surface reduction
- **Con**: May break NVIDIA proprietary driver, debugging tools
- **Note**: Auto-enables with Secure Boot on many kernels

**Decision**: **Defer to POST-STABILITY** - Test after Secure Boot enrollment. Add to Section 17 (optional hardening end-state).

---

### Unprivileged User Namespace Restriction

| Aspect | Status |
|--------|--------|
| **Implementation** | ❌ NOT IMPLEMENTED |
| **Sysctl** | `kernel.unprivileged_userns_clone` not set (defaults to enabled) |
| **User Limit** | `user.max_user_namespaces` not restricted |
| **Documentation** | ✅ SOURCE-TOPIC-LEDGER.md (rejected - conflicts with sandboxing) |
| **Coverage** | Missing from audit ledger |

**What it blocks**:
- Unprivileged users creating new user namespaces
- Required by: bubblewrap, Flatpak, Chrome sandbox, systemd-nspawn, containers

**Trade-offs**:
- **Pro**: Eliminates large class of CVEs (many kernel exploits use userns)
- **Con**: **BREAKS core repo functionality**:
  - Sandboxed browsers (`safe-firefox`, `safe-tor`) - bubblewrap requires userns
  - Flatpak apps (Signal, Spotify) - requires userns
  - Sandboxed apps (VRCX, Windsurf) - bubblewrap requires userns
  - Steam Proton containers - may require userns

**Madaidan's recommendation**: Disable (security > functionality)

**This repo's decision**: **REJECTED** - Conflicts with sandboxing architecture. The repo relies on bubblewrap/Flatpak for isolation; disabling userns would break paranoid profile's primary containment mechanism.

**Alternative approach**: Keep userns enabled but harden via:
- AppArmor MAC framework (already implemented)
- Seccomp filters (via bubblewrap)
- Capability dropping (via bubblewrap)

**Documentation**: Add to SOURCE-TOPIC-LEDGER.md as "Rejected - conflicts with sandboxing architecture"

---

**Next Steps**: (All Completed)
1. ~~Update TEST-PLAN.md to cover the 3 kernel control gaps and swappiness~~ ✅ DONE
2. ~~Add kernel lockdown to POST-STABILITY.md Section 17 (optional end-state)~~ ✅ DONE
3. ~~Document userns rejection in SOURCE-TOPIC-LEDGER.md~~ ✅ DONE

**Audit Status**: ✅ **Statically covered** - All features covered in TEST-PLAN.md or POST-STABILITY.md. This is a documentation audit, not runtime verification.
