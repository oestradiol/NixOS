# Source Coverage Matrix

## Reading rule
This file records the main external pages reviewed, the visible chapter inventory that was checked, the implementation effect on this repo, and what still remains.

## Source documentation requirement (to be completed)
For a security repo, each important claim should trace to:
- Official docs or upstream manuals (primary)
- Opinionated guides (secondary)
- With exact URLs and date checked

**Current state**: This file is a reading log with source names but not full URL/date pinning. Future updates should add:
- Full URL for each source
- Date checked (YYYY-MM-DD format)
- Specific section/claim referenced

**Template for new entries**:
```
### X. Source Name
Source:
- Full URL: https://example.com/path
- Date checked: YYYY-MM-DD
- Specific sections: [list relevant sections]

Main points captured:
- [key points]
```

Status values:
- `implemented`
- `scaffolded`
- `planned`
- `rejected`
- `note-only`

---

## A. Core install and hardening sources

### 1. NixOS download / minimal install / official manual
Source:
- official download/manual pages

Main points captured:
- start from minimal install media
- stable releases are generally only given security updates, while `nixos-unstable` provides more up-to-date packages and modules; this repo follows `nixos-unstable` by explicit user choice
- install first with a known-good basic boot path before layering more complexity

Repo effect:
- daily/paranoid split kept, but the install flow still stages controls carefully even though the repo now follows `nixos-unstable`
- secure boot moved after first successful normal boot

Status:
- `implemented` as build/install sequencing in docs
- `planned` for final real-machine execution

### 2. NixOS Wiki full disk encryption
Source:
- wiki FDE guidance

Main points captured:
- use LUKS for data-at-rest protection
- understand limits of FDE
- disk layout must match later persistence design

Repo effect:
- encryption remains a foundational requirement for both profiles

Status:
- `planned`

### 3. Hardening NixOS
Source:
- `saylesss88.github.io/nix/hardening_NixOS.html`

Visible chapter inventory reviewed:
- Common Attack Vectors for Linux
- Minimal Installation with LUKS
- Manual Encrypted Install Following the Manual
- Guided Encrypted BTRFS Subvol install using disko
- Installing Software
- Users and SUID Binaries
- The Danger of setuid
- Capabilities
- Impermanence
- Replace timesyncd with a chron job that enables NTS
- Secure Boot
- Choosing your Kernel
- The Hardened Kernel
- sysctl
- Kernel Security Settings
- Further Hardening with sysctl
- Hardening Boot Parameters
- Hardened Memory Allocator
- Hardening Systemd
- Lynis and other tools
- Securing SSH
- Key generation / ssh-keygen / OpenSSH Server
- Encrypted Secrets / Sops-nix Guide
- Auditd
- USB Port Protection
- Doas over sudo
- Firejail
- Flatpak
- SeLinux/AppArmor MAC
- Resources / Advanced Hardening with nix-mineral

What was adopted:
- minimum install + LUKS-first sequencing
- explicit documentation discipline
- least-privilege / reduce SUID exposure direction
- impermanence as a first-class design axis
- secure boot after basic boot works
- kernel/sysctl/systemd hardening as modular baseline
- browser/app sandboxing as layered defense
- Lynis/testing as explicit later phase

What was not adopted as-is:
- not every knob copied blindly
- doas not adopted; repo kept a more conservative placeholder stance
- Firejail not chosen as the main sandbox direction
- SELinux/AppArmor treated as constrained/experimental on NixOS rather than a solved baseline
- NTS time sync replacement deferred (may break KDE/Qt time APIs; test on paranoid after stable)

Repo effect:
- `modules/security/base.nix`
- `modules/security/impermanence.nix`
- `modules/security/secure-boot.nix`
- `modules/security/networking.nix`
- `modules/security/browser.nix`
- testing notes in docs

Status:
- mixed: `implemented` / `scaffolded` / `planned`

### 4. Encrypted Setups
Source:
- `saylesss88.github.io/installation/enc/enc_install.html`

Visible chapter inventory reviewed:
- What does LUKS Encryption Protect?
- The Install
- Option A: Interactive `wpa_cli`
- Option B: Non-Interactive `wpa_passphrase`
- Setting up zram and `/tmp` on RAM
- Setting a Flake for your minimal Install
- Create a Blank Snapshot of `/root`
- Persisting Critical System State
- Reboot

What was adopted:
- encryption-first disk planning
- explicit persistence of critical state only
- awareness that impermanence must match install layout

What remains machine-specific:
- exact disko/disk layout
- exact Btrfs subvolumes
- exact snapshot logic

Status:
- `planned` / `scaffolded`

### 5. Encrypted Impermanence
Source:
- `saylesss88.github.io/installation/enc/encrypted_impermanence.html`

Visible chapter inventory reviewed:
- Getting Started
- `configuration.nix` changes
- Applying Your Impermanence Configuration

What was adopted:
- ephemeral root as an explicit phase after stable base install
- persist only what is declared
- smaller persistent footprint as both cleanliness and security gain

Repo effect:
- impermanence module scaffold and docs

Main unresolved dependency:
- actual `/persist` layout and early mount behavior

Status:
- `scaffolded`

### 6. Secure Boot with Lanzaboote
Source:
- `saylesss88.github.io/installation/enc/lanzaboote.html`
- lanzaboote quick-start and NixOS option docs indirectly referenced

Visible chapter inventory reviewed:
- Important Considerations
- Requirements
- Security Requirements
- Preparation
- Configuring Lanzaboote With Flakes
- Ensure Your Machine is Ready for Secure Boot enforcement
- Enabling Secure Boot and Entering Setup Mode
- What Lanzaboote Actually Secures and Limitations

What was adopted:
- secure boot only after first known-good normal boot
- explicit statement that secure boot protects the boot chain, not userspace integrity by itself
- systemd-boot requirement acknowledged

Repo effect:
- `modules/security/secure-boot.nix`
- docs now sequence this later, not first

Status:
- `scaffolded`

### 7. Network Security
Source:
- `saylesss88.github.io/nix/hardening_networking.html`

Visible chapter inventory reviewed:
- Introduction
- Safe Browsing / Privacy Enhancing Habits
- Why Follow These Basics?
- Protections from Surveillance in the U.S.
- Encrypted DNS
- Setting up Tailscale
- MAC Randomization
- Firewalls
- NixOS Firewall vs nftables Ruleset
- Testing
- OpenSnitch
- Resources

What was adopted:
- network hardening is practical and threat-model dependent
- default firewall + explicit later nftables killswitch work
- testing after each network change
- DNS/privacy settings are secondary to correct full-tunnel enforcement

What was not adopted as-is:
- no Tailscale-specific path chosen as the default architecture
- OpenSnitch not made a baseline requirement

Repo effect:
- `modules/security/networking.nix`
- docs call out Mullvad killswitch details as still machine-specific

Status:
- `scaffolded`

### 8. Browser Privacy
Source:
- `saylesss88.github.io/nix/browsing_security.html`

Visible chapter inventory reviewed:
- Browser/Browsing Security: Defense in Depth
- Methods of Protection
- Fingerprinting
- Fingerprint Testing
- Browsers
- Brave
- Firefox
- Site Isolation & Firefox Links
- LibreWolf
- Search Defaults
- Tor Browser
- TorPlusVPN
- Mullvad-Browser
- Making Your Browser Amnesic, the Nix Way
- Virtual Private Networks

What was adopted:
- browsers are top attack surface
- browser plan should separate exploit resistance, privacy, and anonymity
- role split across browsers is cleaner than trying to make one browser do everything
- leak testing must verify WebRTC and DNS behavior
- arkenfox v140+ now uses FPP (Fingerprinting Protection) by default with ETP Strict; RFP is opt-in
- daily Firefox uses FPP (less breakage), paranoid safe-firefox uses RFP (maximum protection)
- DNS endpoint split: daily uses system/VPN DNS (no DoH), paranoid uses VPN server DNS with all.dns.mullvad.net filtering
- Cookie isolation: daily uses ETP Strict + TCP (arkenfox-aligned), paranoid uses FPI (stronger, not aligned)

Repo effect:
- `modules/security/browser.nix` — 60+ prefs, FPP for daily, RFP for paranoid
- daily: arkenfox-aligned (FPI disabled, ETP Strict + TCP, no DoH - uses system/VPN DNS)
- paranoid: FPI enabled (security over alignment), VPN server DNS only (follows Mullvad guidance)
- daily/paranoid browser split documented in PRE-INSTALL.md, POST-STABILITY.md, TEST-PLAN.md

Status:
- `implemented` — daily: arkenfox-aligned (FPP, ETP Strict + TCP, no DoH). paranoid: FPI + RFP (security over alignment, VPN DNS only)

### 9. GnuPG & gpg-agent
Source:
- `saylesss88.github.io/nix/gpg-agent.html`

Visible chapter inventory reviewed:
- `gpg.fail` warnings and operational caveats
- Key Concepts
- revocation certificate
- offline primary key guidance
- GitHub key publishing
- commit signing
- key backup
- file encryption
- signing and verification
- email encryption
- public key availability
- trust editing

What was adopted:
- GPG belongs in user/tooling layer, not scattered ad hoc
- key hygiene and revocation need explicit operational notes
- commit signing is meaningful, but keys and pinentry must be treated carefully

Repo effect:
- carried into implementation plan as later user-layer work

Status:
- `planned`

### 10. KVM / maximum isolation page
Source:
- `saylesss88.github.io/nix/kvm.html`

Visible chapter inventory reviewed:
- Why This Setup?
- Install secureblue host
- Create NixOS VM
- How host MAC secures guest
- Why hardening guest still matters
- Nix Toolbox
- recovery example
- resources

What was adopted:
- virtualization is a later isolation tier, not first-step baseline
- host/guest split can exceed what a single desktop profile can do

What was not adopted as-is:
- secureblue host + NixOS guest is not made mandatory for your current repo

Status:
- `planned`

### 11. Git
Source:
- `saylesss88.github.io/vcs/git.html`

Visible chapter inventory reviewed:
- Limitations of NixOS Rollbacks
- How Git Helps
- Git Tips
- Atomic Commits
- linear history tips
- Time Travel in Git
- Basic workflow / branching / rebasing
- flake-update example
- Configure Git Declaratively

What was adopted:
- small auditable commits are part of the hardening process
- secrets never go in git or the Nix store
- declarative git config should be part of final user tooling

Repo effect:
- docs now stress commit discipline and secrets handling

Status:
- `implemented` in documentation discipline
- `planned` for declarative git module deepening

---

## B. Cross-check / tension sources

### 12. Madaidan Linux Hardening Guide
Source:
- `madaidans-insecurities.github.io/guides/linux-hardening.html`

Visible chapter inventory reviewed from page TOC:
- distro choice
- kernel hardening
- sysctl
- boot parameters
- hidepid
- kernel attack-surface reduction
- MAC
- sandboxing
- common escapes
- systemd sandboxing
- VMs
- hardened allocator
- compilation flags
- memory-safe languages
- root account / SSH / securetty / su restrictions
- firewalls
- identifiers / machine-id / MAC / timezone / timestamps
- permissions / setuid / umask
- core dumps
- swap
- PAM
- microcode
- IPv6 privacy
- partitioning and mount options
- entropy
- editing files as root
- distribution-specific hardening
- physical security / encryption / UEFI / verified boot / USB / DMA / cold boot
- best practices

How it was used:
- as a pressure source for attack-surface reduction and privilege/sandbox thinking
- not as a literal blueprint, because parts are strongly opinionated and not NixOS-native

What was adopted from the spirit, not literally:
- reduce attack surface
- distrust unnecessary privilege
- prefer layered sandboxing and VMs for stronger boundaries
- harden core dumps, permissions, mount behavior, kernel settings, and physical boot chain where practical

What was not adopted literally:
- non-systemd distro preference
- broad claims that are not directly portable into NixOS architecture

Status:
- `note-only` / `planned`

### 13. Debunking Madaidan's Insecurities
Source:
- `chyrp.cgps.ch/en/debunking-madaidans-insecurities/`

Main use:
- treat hardening advice as contested in places
- avoid turning one guide into dogma
- keep VMs as the strongest practical sandbox boundary
- Doas over sudo
  - `deferred` — sudo retained for wave one; post-stability analysis of doas vs run0 vs keep sudo (see POST-STABILITY.md)

Repo effect:
- more conservative “adopt selectively, test locally” stance

Status:
- `note-only`

### 14. trimstray linux-hardening-checklist
Source:
- `github.com/trimstray/linux-hardening-checklist`

Visible checklist areas reviewed:
- partitioning
- physical access
- bootloader
- kernel
- logging
- users/groups
- filesystem
- permissions
- SELinux & Auditd
- system updates
- network
- services
- tools

Use here:
- secondary checklist lens for mount options, kernel logging restrictions, audit/logging, and permissions

Status:
- `note-only`

### 15. trimstray practical guide
Source:
- `github.com/trimstray/the-practical-linux-hardening-guide`

Visible focus reviewed:
- policy compliance
- SCAP / OpenSCAP
- guide as practical high-level framework, not one distro recipe

Use here:
- justification for audit/checklist/test pass, not for direct copy-paste

Status:
- `note-only`

---

## C. Nix-specific implementation projects

### 16. impermanence
Source:
- `github.com/nix-community/impermanence`

Main points captured:
- impermanence needs both a wiping-root strategy and a persistent mounted volume
- tmpfs root is easiest but has significant drawbacks
- persistent filesystem often needs `neededForBoot = true`
- module handles bind/link persistence after the storage model exists

Repo effect:
- impermanence kept as scaffold, not falsely marked complete

Status:
- `scaffolded`

### 17. agenix
Source:
- `github.com/ryantm/agenix`

Main points captured:
- Nix store is world-readable, so cleartext secrets do not belong there
- agenix stores encrypted `.age` files in the store and decrypts at activation using host keys
- works with existing SSH key infrastructure

Repo effect:
- `modules/security/secrets.nix`
- secrets directory scaffold

Status:
- `scaffolded`

### 18. nix-mineral
Source:
- `github.com/cynicsketch/nix-mineral`

Main points captured:
- alpha software
- assumes unstable for simplicity
- aims to be a drop-in hardening layer, not a total OS redesign
- threat model is non-state adversaries and not anonymity
- notable features include filesystem, kernel, network, module blacklists, entropy hardening

How it was used:
- as a checklist/diff target, not as a wholesale import

What remains to do:
- Compare manual implementation against nix-mineral feature families one by one (deferred to late game)

Status:
- `deferred`

---

## D. Late-game / deferred items
- Full nix-mineral diff — `deferred` (alpha software, different threat model)
- NTS time sync replacement — `not yet implemented` (test on paranoid after stable)
- Hardened memory allocator full rollout — `deferred` (enable after post-install testing)
- Hardened compilation flags policy — `deferred` (rebuild times, GPU driver risk)
- Dedicated entropy-hardening component — `deferred` (not critical for desktop)
- Full SUID/capability pruning program — `deferred` (high breakage risk, paranoid-only candidate)
- AI final review pass — `repeat after live install`
- Remote wipe / dead-man switch — `deferred` (signal service, secure wipe mechanism design)
- Thunderbolt/DMA attack surface — `documented` (consider BIOS disable for paranoid; DMA bypasses all OS hardening)
- Yubikey/FIDO2/Passkey support — `documented` (PAM config required, consider for paranoid tier)
- SSH host key rotation policy — `documented+manual` (post-stability rotation procedure)
- LUKS header backup procedure — `documented+manual` (execute after install; test restore)
- EFI partition backup/verification — `documented+manual` (backup after first boot; external media)
- fstrim/discard configuration — `documented` (decision needed: enable timer or discard)
- Sleep states (suspend/hibernate) — `implemented` (`myOS.security.allowSleep` option, default false; both profiles explicitly disable)
- WireGuard module security audit — `documented` (monitor CVEs; nftables killswitch is defense-in-depth)
- Lanzaboote nuclear recovery — `documented` (extended recovery procedure for SB lockout)
- Bubblewrap GPU passthrough acknowledgment — `documented` (safe-firefox uses --dev-bind /dev/dri; GPU = known escape vector)
