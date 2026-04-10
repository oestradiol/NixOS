# Source Topic Ledger

This is the canonical source-topic ledger.

Purpose:
- pin every reviewed hardening topic to one explicit status
- say where it lives in code/docs
- say what still requires manual execution
- say what was explicitly rejected or deferred

Status values:
- **Implemented** — present in code or scripts now
- **Implemented+Manual** — repo support exists, but you must complete external/manual steps
- **Documented** — captured in canonical docs or audit surfaces, but not materially encoded in code
- **Deferred** — intentionally postponed
- **Rejected** — intentionally not chosen in wave one
- **Missing external input** — cannot finish without missing user/source material

| Topic | Source family | Status | Canonical location | Code location | Manual action / note |
|---|---|---:|---|---|---|
| Kernel hardening | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | `modules/core/boot.nix`, `modules/security/base.nix` | Validate kernel params and compatibility on hardware |
| Mandatory access control (AppArmor) | Madaidan / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/audit/POINT-BY-POINT-VERIFICATION.md` | `modules/security/base.nix` | Live-check loaded AppArmor profiles |
| Mandatory access control (SELinux) | Madaidan / saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | AppArmor chosen instead for wave one |
| Sandboxing (browser, Flatpak) | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/AUDIT-TUTORIAL.md` | `modules/security/browser.nix`, `modules/security/flatpak.nix` | Validate `safe-firefox`, Tor Browser, Flatpak permissions |
| Sandboxing (broader per-app sandboxing) | Madaidan / saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/IMPLEMENTATION-PLAN.md` | — | Expand later with Nixpak/bwrap rules per app |
| Hardened memory allocator | Madaidan / saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/security/base.nix`, `profiles/*.nix` | Keep full rollout off until post-install testing |
| Hardened compilation flags | Madaidan | Documented | `PROJECT-STATE.md`, this ledger | — | Not operationalized repo-wide in wave one |
| Memory-safe languages policy | Madaidan | Documented | `PROJECT-STATE.md`, this ledger | — | Keep as doctrine/research note; not enforceable here |
| Root account hardening doctrine | Madaidan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/AUDIT-TUTORIAL.md` | `modules/security/base.nix`, `modules/core/users.nix`, `modules/security/governance.nix` | Root locked (`!`), su wheel-only; verify after install |
| Firewalls / nftables | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | `modules/security/networking.nix` | Validate real Mullvad/WireGuard interface behavior |
| Identifiers / machine-id / profile separation | Madaidan | Implemented+Manual | `docs/PERSISTENCE-MAP.md`, `docs/TRUST-MODEL.md` | `modules/security/impermanence.nix`, HM user modules | Verify machine-id persistence and no cross-user state bleed |
| File permissions / ownership hygiene | Madaidan / Trimstray | Documented | `docs/PERSISTENCE-MAP.md`, this ledger | various modules | Run post-install permission audit |
| Core dumps | Madaidan | Implemented | this ledger, `docs/TEST-PLAN.md` | `modules/security/base.nix` | `systemd.coredump.extraConfig` disables storage; verify with `coredumpctl` after install |
| Swap strategy | Madaidan / saylesss88 | Implemented | `PROJECT-STATE.md`, `docs/PERSISTENCE-MAP.md` | `hosts/nixos/hardware-target.nix`, `modules/security/base.nix` | zram + 8GB Btrfs swapfile on `@swap` subvolume |
| PAM hardening | Madaidan | Implemented+Manual | this ledger, `docs/TEST-PLAN.md` | `modules/security/base.nix`, `modules/vr.nix` | `su` restricted to wheel; verify PAM stack after install |
| Microcode updates | Madaidan / Trimstray | Implemented | `PROJECT-STATE.md` | `hosts/nixos/hardware-target.nix` | Validate active microcode on rebuilt host |
| IPv6 privacy extensions | Madaidan | Implemented | `PROJECT-STATE.md`, this ledger | `modules/security/base.nix` | sysctl `use_tempaddr=2` for all/default; verify with `ip -6 addr` after install |
| Partitioning and mount options | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md`, `docs/PERSISTENCE-MAP.md` | `hosts/nixos/hardware-target.nix`, `hosts/nixos/install-layout.nix` | Execute destructive install carefully |
| Entropy hardening | Madaidan | Not yet implemented | `PROJECT-STATE.md`, this ledger | — | Deferred to late-game; not separately operationalized |
| Editing files as root / sudoedit discipline | Madaidan | Documented | this ledger, `docs/AUDIT-TUTORIAL.md` | — | Use documented admin workflow; not enforced in code |
| Distribution-specific NixOS hardening | saylesss88 / nix-mineral | Implemented+Manual | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, `docs/audit/RESEARCH-GROUNDING.md` | whole repo | Audit module-by-module after install |
| Physical security | Madaidan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/RECOVERY.md` | Secure Boot / TPM modules | Requires firmware settings, passphrase discipline |
| Best-practice doctrine | Madaidan / Trimstray | Documented | `docs/AUDIT-TUTORIAL.md`, `docs/audit/RESEARCH-GROUNDING.md` | — | Human discipline remains required |
| Minimal installation | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md` | install script + host layout | Execute with care |
| LUKS / encrypted install | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md`, `PROJECT-STATE.md` | `hosts/nixos/install-layout.nix` | Perform destructive encrypted install |
| Guided encrypted Btrfs subvolumes | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md`, `docs/PERSISTENCE-MAP.md` | `hosts/nixos/hardware-target.nix` | Same as above |
| disko-based install | saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | Manual scripted install chosen instead |
| Installing software declaratively | saylesss88 | Implemented | `PROJECT-STATE.md`, `docs/IMPLEMENTATION-PLAN.md` | flake + modules | — |
| Users and sudo | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/TRUST-MODEL.md` | `modules/core/users.nix`, `modules/security/governance.nix` | Confirm wheel membership and sudo policy |
| SUID binaries / setuid danger | saylesss88 / Madaidan | Documented | this ledger, `docs/IMPLEMENTATION-PLAN.md` | `modules/security/base.nix` | Do post-install SUID audit and reduce where safe |
| Capabilities | saylesss88 | Documented | this ledger | — | Review special capability needs for gaming/VR later |
| Impermanence | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/PERSISTENCE-MAP.md` | `modules/security/impermanence.nix` | Validate exactly what persists |
| NTS time sync replacement | saylesss88 | Not yet implemented | `PROJECT-STATE.md`, `docs/POST-INSTALL.md` | — | Test on paranoid after stable; may break KDE/Qt time APIs |
| Secure Boot / Lanzaboote | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/POST-INSTALL.md` | `modules/security/secure-boot.nix` | Enroll keys only after first good boot |
| Kernel choice / hardened kernel | saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/core/boot.nix` | Keep daily on compatibility-first path initially |
| sysctl hardening | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/core/boot.nix`, `modules/security/base.nix` | Validate no regressions |
| Boot parameters hardening | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/core/boot.nix` | Validate no regressions |
| Systemd hardening | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, this ledger | `modules/security/browser.nix`, `modules/security/flatpak.nix`, `modules/security/scanners.nix` | NoNewPrivileges, ProtectKernel*, LockPersonality on flatpak-repo/ClamAV/AIDE; expand per-service later |
| Lynis | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/security/base.nix` | Run on rebuilt host |
| SSH hardening / keygen guidance | saylesss88 | Documented | `docs/POST-INSTALL.md`, this ledger | `modules/security/base.nix` | Apply only if enabling SSH later |
| Encrypted secrets | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/POST-INSTALL.md` | `modules/security/secrets.nix` | Create real `.age` files |
| doas / run0 over sudo | saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | sudo retained for wave one; revisit later |
| USB port protection | saylesss88 | Implemented | `PROJECT-STATE.md`, this ledger | `modules/core/boot.nix` | `usbcore.authorized_default=2` on paranoid (internal hubs only); verify peripherals work |
| Firejail | saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | Flatpak+bwrap chosen instead |
| Flatpak | saylesss88 | Implemented | `PROJECT-STATE.md` | `modules/security/flatpak.nix` | — |
| nix-mineral advanced hardening | nix-mineral / saylesss88 | Deferred | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, this ledger | — | Alpha software, different threat model; diff deferred to late game |
| Trimstray general checklist | Trimstray | Documented | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, this ledger | many | Use as audit overlay, not blind import |
| Virtualization split | Original plan / Trimstray | Deferred | `PROJECT-STATE.md`, `docs/TRUST-MODEL.md` | libvirt retained daily-only where relevant | Optional later wave |
| Development & packaging doctrine | Original plan | Documented | `docs/IMPLEMENTATION-PLAN.md`, this ledger | `modules/core/nix.nix`, Git HM | Not a wave-one focus |
| Configure Git declaratively | Original plan | Implemented | `PROJECT-STATE.md` | `modules/core/home-common.nix` | — |
| KeePassXC + permanence | Original plan | Implemented+Manual | `PROJECT-STATE.md`, `docs/PERSISTENCE-MAP.md` | HM + impermanence modules | Verify real database path |
| PQ / future crypto planning | Original plan | Documented | `PROJECT-STATE.md`, `docs/TRUST-MODEL.md` | — | No blanket “quantum-ready” claim |
| Update to latest Nix track | Original plan | Implemented | `PROJECT-STATE.md` | `flake.nix` | `nixos-unstable` chosen |
| Alternative home path | Original plan | Implemented | `PROJECT-STATE.md`, `docs/PERSISTENCE-MAP.md` | split user homes/subvolumes | Audit if it meets your goals |
| Browser + networking verification | Original plan | Documented | `docs/TEST-PLAN.md`, `docs/AUDIT-TUTORIAL.md` | — | Must be executed live |
| IRC / Signal / Matrix / Telegram policy | Original plan | Implemented+Manual | `PROJECT-STATE.md`, `docs/TRUST-MODEL.md` | home modules/profile policy | Validate package availability and profile rules |
| Hardening tests | Original plan | Documented | `docs/TEST-PLAN.md` | — | Must be executed live |
| sudo / SUDO_KILLER | Original plan | Documented | `docs/audit/MASTER_COVERAGE_MATRIX.md`, this ledger | — | Deferred but tracked |
| Malware Knowledge chat reconciliation | Original plan | Missing external input | `PROJECT-STATE.md`, master matrix | — | Need source content to complete |
| Final AI review pass | Original plan | Implemented | `PROJECT-STATE.md`, audit docs | governance surfaces | Repeat after live install |
| Remote wipe / dead-man switch | Original plan | Deferred | `PROJECT-STATE.md`, `docs/IMPLEMENTATION-PLAN.md` | — | Optional later wave |
| AIDE / ClamAV | Original plan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | `modules/security/scanners.nix` | Initialize DB and evaluate usefulness |
| Full graphene-hardened after debug | Original plan | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/security/base.nix` | Enable only after stability/perf testing |
| Mullvad / WebRTC / DNS / Tor Browser verification | Original plan | Documented | `docs/TEST-PLAN.md`, `docs/AUDIT-TUTORIAL.md` | networking/browser modules | Must be executed live |
