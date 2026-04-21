# Source coverage map

This file compresses the relevant hardening source material into repo-governance decisions.

Columns:
- `topic` = source topic cluster
- `repo state` = baseline / daily-softened / staged / deferred / rejected / absent
- `where` = main repo surfaces
- `why` = short governance explanation
- `source` = upstream influence link

## saylesss88 section-by-section coverage

This section tracks the saylesss88 material as a single explicit ledger, one row per unique heading or subheading. Presence here means the source topic was consciously accounted for, not necessarily implemented.

| topic | repo state | where | why | source |
|---|---|---|---|---|
| The Kernel | baseline | `modules/core/boot.nix`, `profiles/*` | repo treats kernel posture as a first-class governance surface | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Choosing your Kernel | baseline | `modules/core/boot.nix`, `profiles/*` | stock kernel plus explicit hardening layer chosen for workstation reliability | https://saylesss88.github.io/nix/hardening_NixOS.html |
| The Hardened Kernel | absent | none | `linux-hardened` is not the current baseline choice | https://saylesss88.github.io/nix/hardening_NixOS.html |
| sysctl | baseline + partial gaps | `modules/security/base.nix`, `modules/security/privacy.nix` | meaningful subset implemented, stricter knobs still incomplete | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Kernel Security Settings | baseline + partial gaps | `modules/security/base.nix` | kernel self-protection sysctls are real but not exhaustive | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Further Hardening with sysctl | baseline + partial gaps | `modules/security/base.nix`, `modules/security/privacy.nix` | extra sysctls are used selectively rather than maximally | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Hardening Boot Parameters | baseline + staged | `modules/core/boot.nix`, `profiles/*` | several boot knobs are active now and stronger ones remain staged | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Hardened Memory Allocator | staged | `modules/security/base.nix`, `profiles/*` | wired but intentionally off by default | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Hardening Systemd | partial | service definitions across `modules/security/*` | targeted hardening exists, but not a broad service-by-service program | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Lynis and other tools | baseline | `modules/security/base.nix`, `modules/security/scanners.nix` | Lynis, AIDE, and ClamAV are used as visibility and integrity layers | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Securing SSH | mostly absent by surface removal | `modules/desktop/base.nix` | the repo disables the SSH server instead of exposing and tuning it | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Key generation | partial | operator workflow, `modules/security/secrets.nix` | key workflows are assumed, but not fully tutorialized in-repo | https://saylesss88.github.io/nix/hardening_NixOS.html |
| ssh-keygen | partial | operator workflow, `modules/security/secrets.nix` | key generation is assumed for SSH and age usage, not encoded as its own workflow doc | https://saylesss88.github.io/nix/hardening_NixOS.html |
| OpenSSH Server | mostly absent by surface removal | `modules/desktop/base.nix` | server-side SSH hardening is largely moot because the service is disabled | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Encrypted Secrets | partial | `modules/security/secrets.nix` | encrypted-secret handling exists as a scaffold rather than a finished pipeline | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Sops-nix Guide | rejected / alternate path | `modules/security/secrets.nix` | repo leans toward agenix-style wiring rather than `sops-nix` | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Auditd | baseline on paranoid | `modules/security/base.nix`, `profiles/paranoid.nix` | enabled on the hardened workstation profile, softened on daily | https://saylesss88.github.io/nix/hardening_NixOS.html |
| USB Port Protection | daily-softened | `profiles/*`, `modules/security/governance.nix` | strong USB restrictions on paranoid, relaxed on daily | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Doas over sudo (Warning Doas is unmaintained) | rejected | `modules/security/base.nix`, `modules/core/users.nix` | repo keeps a restricted sudo model and does not adopt doas | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Firejail | rejected | none | bubblewrap is the standard containment layer instead | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Flatpak | baseline | `modules/security/flatpak.nix` | Flatpak is a chosen GUI-app containment layer | https://saylesss88.github.io/nix/hardening_NixOS.html |
| SeLinux/AppArmor MAC (Mandatory Access Control) | baseline + deferred | `modules/security/base.nix`, `docs/pipeline/POST-STABILITY.md` | AppArmor is enabled, custom profile expansion is deferred, SELinux is not chosen | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Resources (Hardening NixOS) | reference layer | `REFERENCES.md` | tracked as supporting sources rather than repo behavior | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Advanced Hardening with nix-mineral (Community Project) | reference only | `REFERENCES.md` | useful influence source, not adopted wholesale | https://saylesss88.github.io/nix/hardening_NixOS.html |
| Network Security | baseline + staged split | `modules/security/networking.nix`, `modules/security/wireguard.nix`, `modules/security/privacy.nix` | repo has a real network privacy posture, with stronger self-owned networking staged | https://saylesss88.github.io/nix/hardening_networking.html |
| Introduction | baseline as framing | `docs/maps/PROFILE-POLICY.md`, `README.md` | governance uses the same layered, threat-model-first framing | https://saylesss88.github.io/nix/hardening_networking.html |
| Safe Browsing / Privacy Enhancing Habits | reference-guided / operator practice | `README.md`, `docs/maps/PROFILE-POLICY.md` | behavioral browsing hygiene is acknowledged but not machine-enforced | https://saylesss88.github.io/nix/hardening_networking.html |
| Why Follow These Basics? | reference-guided | `docs/maps/PROFILE-POLICY.md` | repo policy explicitly treats operator habits as part of the security model | https://saylesss88.github.io/nix/hardening_networking.html |
| Protections from Surveillance in the U.S. | reference only / jurisdiction-specific | `REFERENCES.md` | source acknowledged, but repo does not encode US-specific policy claims | https://saylesss88.github.io/nix/hardening_networking.html |
| Encrypted DNS | baseline + partial gaps | `modules/security/browser.nix`, `modules/security/networking.nix`, `modules/security/wireguard.nix` | encrypted DNS is partially covered via browser and VPN posture, without a dedicated DNSCrypt stack | https://saylesss88.github.io/nix/hardening_networking.html |
| Setting up Tailscale | absent | none | Tailscale is not part of the current network model | https://saylesss88.github.io/nix/hardening_networking.html |
| MAC Randomization | baseline + daily-softened | `modules/security/privacy.nix`, `profiles/*` | stronger randomization on paranoid, softer stable-per-network behavior on daily | https://saylesss88.github.io/nix/hardening_networking.html |
| Firewalls | baseline + staged split | `modules/security/networking.nix`, `modules/security/wireguard.nix` | baseline uses NixOS firewall abstraction, staged route uses direct nftables ownership | https://saylesss88.github.io/nix/hardening_networking.html |
| NixOS Firewall vs nftables Ruleset | baseline + staged split | `modules/security/networking.nix`, `modules/security/wireguard.nix` | repo explicitly distinguishes abstraction-first baseline from direct ruleset ownership later | https://saylesss88.github.io/nix/hardening_networking.html |
| Testing | baseline | `docs/pipeline/TEST-PLAN.md`, `scripts/audit-tutorial.sh` | repo includes explicit validation surfaces rather than only config claims | https://saylesss88.github.io/nix/hardening_networking.html |
| OpenSnitch | absent | none | not part of the current repo model | https://saylesss88.github.io/nix/hardening_networking.html |
| Resources (Network Security) | reference layer | `REFERENCES.md` | tracked as source support rather than repo behavior | https://saylesss88.github.io/nix/hardening_networking.html |
| Browser Privacy | baseline | `modules/security/browser.nix`, `modules/security/arkenfox/user.js` | browser privacy is a first-class policy surface with daily/paranoid split | https://saylesss88.github.io/nix/browsing_security.html |
| Methods of Protection | baseline | `modules/security/browser.nix`, `docs/maps/PROFILE-POLICY.md` | repo separates privacy, anonymity, and compartmentalization concerns explicitly | https://saylesss88.github.io/nix/browsing_security.html |
| Fingerprinting | baseline + partial gaps | `modules/security/browser.nix`, `modules/security/arkenfox/user.js` | fingerprint resistance is pursued, but not treated as solved | https://saylesss88.github.io/nix/browsing_security.html |
| Fingerprint Testing | absent / operator-managed | none | repo does not include an automated browser fingerprint-test workflow | https://saylesss88.github.io/nix/browsing_security.html |
| Browsers | baseline | `modules/security/browser.nix` | browser choices are explicitly governed by profile and use-case | https://saylesss88.github.io/nix/browsing_security.html |
| LibreWolf | absent | none | not chosen | https://saylesss88.github.io/nix/browsing_security.html |
| Search Defaults | absent / browser-choice dependent | none | repo does not encode a LibreWolf-specific search policy because LibreWolf is not selected | https://saylesss88.github.io/nix/browsing_security.html |
| Tor Browser | baseline optional | `modules/security/browser.nix` | anonymity browser kept available through a local wrapper | https://saylesss88.github.io/nix/browsing_security.html |
| TorPlusVPN | rejected as repo claim | none | repo does not encode this as a normative posture | https://saylesss88.github.io/nix/browsing_security.html |
| Making Your Browser Amnesic, the Nix Way | partial | `modules/security/browser.nix`, `modules/security/impermanence.nix` | some persistence minimization exists, but not a fully amnesic browser policy | https://saylesss88.github.io/nix/browsing_security.html |
| Virtual Private Networks (VPNs) | baseline + staged split | `modules/security/networking.nix`, `modules/security/wireguard.nix` | Mullvad app mode now, self-owned WireGuard later | https://saylesss88.github.io/nix/browsing_security.html |
| Brave | absent | none | not chosen | https://saylesss88.github.io/nix/browsing_security.html |
| Firefox | baseline | `modules/security/browser.nix` | Firefox is the main browser surface in both daily and paranoid forms | https://saylesss88.github.io/nix/browsing_security.html |
| Site Isolation & Firefox Links | partial | `modules/security/browser.nix`, wrapped-browser model | wrapper and Firefox hardening exist, but not every browser-internal isolation nuance is separately tracked | https://saylesss88.github.io/nix/browsing_security.html |
| GnuPG & Agent | partial | `modules/desktop/base.nix` | GPG agent exists, but the full operational playbook is not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| ⚠️ gpg.fail (practical OpenPGP vulnerabilities) (Added on 2026-01-15) | reference-guided | `REFERENCES.md`, `docs/maps/PROFILE-POLICY.md` | repo treats GPG as sharp and fallible rather than magically safe | https://saylesss88.github.io/nix/gpg-agent.html |
| Why this matters even with good key hygiene | reference-guided | `docs/maps/PROFILE-POLICY.md` | good hygiene is treated as necessary but not sufficient | https://saylesss88.github.io/nix/gpg-agent.html |
| How to avoid the sharp edges (actionable) | partial | `modules/desktop/base.nix`, operator workflow | some safe defaults exist, but not the full operational checklist | https://saylesss88.github.io/nix/gpg-agent.html |
| If you automate verification (important) | reference-guided | `docs/maps/PROFILE-POLICY.md` | automation caveats are tracked as governance guidance, not an implemented verifier | https://saylesss88.github.io/nix/gpg-agent.html |
| NixOS/Home-Manager hardening can break GPG (common failure mode) | partial | `modules/desktop/base.nix`, docs | repo acknowledges that hardening/wrapping can interfere with agent and pinentry behavior | https://saylesss88.github.io/nix/gpg-agent.html |
| 🔑 Key Concepts | reference-guided | `REFERENCES.md` | conceptual crypto background is source material, not a repo feature | https://saylesss88.github.io/nix/gpg-agent.html |
| Asymmetric Encryption (Public-Key cryptography) | reference-guided | `REFERENCES.md` | same as above | https://saylesss88.github.io/nix/gpg-agent.html |
| Generate a Revocation Certificate | absent / operator-managed | none | not encoded in repo workflows | https://saylesss88.github.io/nix/gpg-agent.html |
| Remove and Store your Primary Key offline | absent / operator-managed | none | not encoded in repo workflows | https://saylesss88.github.io/nix/gpg-agent.html |
| Add your GPG Key to GitHub | absent / operator-managed | none | repo does not encode GitHub account operations | https://saylesss88.github.io/nix/gpg-agent.html |
| Sign your Commits for Git | partial | `modules/home/common.nix` | git identity/config exists, but signed-commit workflow is not fully enforced | https://saylesss88.github.io/nix/gpg-agent.html |
| Backing up Your Keys | absent / operator-managed | none | not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| Encrypt a File with PGP | absent / operator-managed | none | not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| List your keys and get the key ID | absent / operator-managed | none | not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| Encrypt a file | absent / operator-managed | none | not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| Sign and Verify Signatures | partial | `REFERENCES.md`, operator workflow | source acknowledged, but not encoded as dedicated tooling in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| Email Encryption | absent | none | not part of current repo scope | https://saylesss88.github.io/nix/gpg-agent.html |
| Make your Public Key Highly Available | absent / operator-managed | none | not part of current repo scope | https://saylesss88.github.io/nix/gpg-agent.html |
| Example: Verifying Arch Linux Download | reference only | `REFERENCES.md` | example acknowledged as source pedagogy, not repo behavior | https://saylesss88.github.io/nix/gpg-agent.html |
| Edit your trust level of the key | absent / operator-managed | none | not encoded in repo | https://saylesss88.github.io/nix/gpg-agent.html |
| Secure Boot (Lanzaboote) | staged | `modules/security/secure-boot.nix`, `scripts/post-install-secureboot-tpm.sh`, `docs/pipeline/POST-STABILITY.md` | intentionally deferred until the baseline system is stable | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Important Considerations | staged | `modules/security/secure-boot.nix`, `docs/pipeline/POST-STABILITY.md` | caveats are part of the staged rollout story | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Requirements | staged | `docs/pipeline/POST-STABILITY.md`, `scripts/post-install-secureboot-tpm.sh` | prerequisites are tracked in the post-stability path | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Security Requirements | staged | `docs/pipeline/POST-STABILITY.md` | firmware and setup requirements are operator-managed, not baseline Nix state | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Preparation | staged | `docs/pipeline/POST-STABILITY.md`, script workflow | secure-boot preparation exists as an explicit later phase | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Configuring Lanzaboote With Flakes | staged | `modules/security/secure-boot.nix`, `flake.nix` | flake and module wiring exist, intentionally not baseline-on | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Ensure Your Machine is Ready for Secure Boot enforcement | staged | `scripts/post-install-secureboot-tpm.sh`, `docs/pipeline/POST-STABILITY.md` | readiness checking is part of the post-stability flow | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| Enabling Secure Boot and Entering Setup Mode | staged | `scripts/post-install-secureboot-tpm.sh`, `docs/pipeline/POST-STABILITY.md` | activation flow exists but is deferred | https://saylesss88.github.io/installation/enc/lanzaboote.html |
| What Lanzaboote (Secure Boot) Actually Secures on NixOS and Limitations | staged / explicitly scoped | `docs/maps/PROFILE-POLICY.md`, `docs/pipeline/POST-STABILITY.md` | repo treats verified boot as boot-chain hardening, not whole-system invulnerability | https://saylesss88.github.io/installation/enc/lanzaboote.html |

## Madaidan-driven topic map

This section now tracks the Madaidan guide **section by section**, including items that are absent, deferred, adapted, or not applicable, so coverage is explicit rather than implied by topic clustering.

| topic | repo state | where | why | source |
|---|---|---|---|---|
| 1. Choosing the right Linux distribution | rejected as direct prescription / adapted | `docs/maps/PROFILE-POLICY.md`, `docs/maps/HARDENING-TRACKER.md` | repo stays on NixOS and treats Madaidan's distro-choice advice as influence, not a migration plan | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2. Kernel hardening | baseline + partial gaps | `modules/core/boot.nix`, `modules/security/base.nix`, `modules/security/privacy.nix` | kernel hardening is a real pillar, but not full maximal Madaidan coverage | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.1 Stable vs. LTS | adapted | `modules/core/boot.nix` | repo uses the standard NixOS kernel package set rather than a special LTS/hardened line | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.2 Sysctl | baseline + partial gaps | `modules/security/base.nix`, `modules/core/boot.nix`, `modules/security/privacy.nix` | many sysctls are set; some stricter recommendations remain absent | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.2.1 Kernel self-protection | baseline + partial gaps | `modules/security/base.nix` | includes `kptr_restrict`, `dmesg_restrict`, BPF hardening, kexec disablement, ptrace tightening, but not every Madaidan knob | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.2.2 Network | baseline + partial gaps | `modules/security/base.nix`, `modules/security/privacy.nix` | redirect protections and some privacy sysctls exist; not every network hardening value is present | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.2.3 User space | partial | `modules/security/base.nix` | some user-space relevant sysctls are set, but namespace/userfaultfd/ldisc coverage is incomplete | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.3 Boot parameters | baseline + staged | `modules/core/boot.nix`, `profiles/*` | active boot hardening exists; stronger settings are staged | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.3.1 Kernel self-protection | baseline + staged | `modules/core/boot.nix` | `debugfs=off` active; `oops=panic` and `module.sig_enforce=1` are wired but off | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.3.2 CPU mitigations | baseline + partial gaps | `modules/core/boot.nix` | `pti=on` is active and paranoid can force `nosmt`; repo does not encode every CPU-side mitigation Madaidan discusses | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.3.3 Result | baseline + staged | `docs/maps/HARDENING-TRACKER.md`, `profiles/*` | repo chooses a workstation-oriented partial hardening result rather than full maximal lock-down | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.4 hidepid | absent / deferred | none | not yet enabled due to desktop/usability breakage risk | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.5 Kernel attack surface reduction | baseline + partial gaps | `modules/security/base.nix`, `modules/core/boot.nix`, `profiles/*` | repo reduces attack surface, but not to Madaidan's full extent | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.5.1 Boot parameters | baseline + staged | `modules/core/boot.nix` | attack-surface related boot args exist; stronger enforcement args remain staged or absent | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.5.2 Blacklisting kernel modules | baseline partial | `modules/security/base.nix` | blacklists some network and FireWire modules; does not import Madaidan's maximal blacklist set | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.5.3 rfkill | absent | none | no rfkill policy module in repo | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.6 Other kernel pointer leaks | partial | `modules/security/base.nix` | `kptr_restrict`/`dmesg_restrict` cover part of this class, not every pointer-leak surface | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.7 Restricting access to sysfs | absent / deferred | none | not yet encoded because of likely workstation breakage | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.8 linux-hardened | absent | none | repo intentionally stays on the standard kernel package set | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.9 Grsecurity | absent | none | not available/selected in repo design | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.10 Linux Kernel Runtime Guard | absent | none | not implemented | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 2.11 Kernel self-compilation | rejected | none | repo uses NixOS package/kernel workflows, not self-built custom kernels | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 3. Mandatory access control | baseline + deferred | `modules/security/base.nix`, `docs/pipeline/POST-STABILITY.md` | AppArmor is enabled; strict profile library work is deferred; SELinux not chosen | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4. Sandboxing | baseline | `modules/security/sandbox-core.nix`, `modules/security/sandboxed-apps.nix`, `modules/security/vm-tooling.nix`, `modules/security/flatpak.nix` | repo uses bubblewrap wrappers, dbus filtering, Flatpak, and VMs as layered containment | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.1 Application sandboxing | baseline | `modules/security/sandbox-core.nix`, `modules/security/sandboxed-apps.nix` | explicit wrapper-based app sandboxing is implemented | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2 Common sandbox escapes | baseline + partial gaps | `modules/security/sandbox-core.nix`, `modules/core/options.nix` | repo explicitly addresses several common escape channels, but not every one fully | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2.1 PulseAudio | adapted | `modules/security/sandbox-core.nix`, `modules/desktop/base.nix` | repo uses PipeWire with pulse compatibility and selectively exposes the pulse socket to sandboxes | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2.2 D-Bus | baseline | `modules/security/sandbox-core.nix`, `modules/security/browser.nix`, `profiles/*` | uses xdg-dbus-proxy filtering and profile-controlled D-Bus exposure | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2.3 GUI isolation | partial | `modules/security/sandbox-core.nix` | GUI containment exists through wrappers/portals, but not a complete GUI-isolation story | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2.4 ptrace | baseline | `modules/security/base.nix` | `kernel.yama.ptrace_scope` is explicitly managed | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.2.5 TIOCSTI | absent / unknown | none | no explicit TIOCSTI hardening surface found in repo | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.3 Systemd service sandboxing | partial | `modules/security/flatpak.nix`, `modules/security/scanners.nix` | some custom services are hardened, but repo has not done a broad systematic pass | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.4 gVisor | absent | none | not implemented | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 4.5 Virtual machines | baseline | `modules/security/vm-tooling.nix` | VMs are an explicit higher-isolation boundary in repo policy | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 5. Hardened memory allocator | staged | `modules/security/base.nix`, `profiles/*` | available via `graphene-hardened-light` toggle, off by default | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 6. Hardened compilation flags | absent | none | no repo-wide custom hardening-flags policy layer found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 7. Memory safe languages | reference only | `REFERENCES.md` | useful principle, but not tracked as a repo policy knob | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8. The root account | baseline | `modules/security/base.nix`, `modules/core/users.nix` | repo hardens root primarily by locking it and constraining escalation | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.1 /etc/securetty | absent | none | no explicit securetty management found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.2 Restricting su | baseline | `modules/security/base.nix` | `security.pam.services.su.requireWheel` is tied to root locking | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.3 Locking the root account | baseline | `modules/security/base.nix` | root is locked with `users.users.root.hashedPassword = "!"` when enabled | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.4 Denying root login via SSH | baseline by surface removal | `modules/desktop/base.nix` | OpenSSH server is disabled entirely | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.5 Increasing the number of hashing rounds | absent | none | no explicit password-hash-rounds tuning found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.6 Restricting Xorg root access | adapted | `modules/desktop/base.nix` | repo prefers Wayland stack; no explicit Xorg-root config because SSH/Xorg-root surfaces are not central to current model | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 8.7 Accessing root securely | baseline | `modules/security/base.nix`, `modules/core/users.nix` | repo uses locked root + sudo restrictions rather than a more permissive direct-root model | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 9. Firewalls | baseline + staged split | `modules/security/networking.nix`, `modules/security/wireguard.nix` | NixOS firewall is baseline in app mode; nftables-owned policy is used in staged self-owned WG mode | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10. Identifiers | baseline + partial gaps | `modules/security/privacy.nix`, `modules/security/impermanence.nix`, `modules/security/governance.nix` | repo manages several identifier surfaces, but not all Madaidan suggestions | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.1 Hostnames and usernames | adapted | `modules/core/users.nix`, docs | repo uses explicit role accounts `ghost` and `player`; it does not treat generic usernames as a primary anonymity defense | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.2 Timezones / Locales / Keymaps | absent / not tracked | none | no dedicated anti-fingerprinting policy for these metadata surfaces in repo governance | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.3 Machine ID | baseline | `modules/security/impermanence.nix`, `modules/security/governance.nix` | machine-id is intentionally persisted as a stable unique host identifier, which is a conscious divergence from identity-minimization advice | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.4 MAC address spoofing | baseline + daily-softened | `modules/security/privacy.nix` | paranoid uses random Wi-Fi MACs; daily uses stable-per-network MACs for usability | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.5 Time attacks | partial | `modules/security/privacy.nix`, `modules/security/base.nix` | some timestamp and echo surfaces are handled; other timing/fingerprinting vectors are not | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.5.1 ICMP timestamps | partial | `modules/core/boot.nix` | repo disables ICMP echo in paranoid, but does not document a full ICMP timestamp-specific rule set | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.5.2 TCP timestamps | baseline + daily-softened | `modules/security/privacy.nix` | disabled on paranoid, enabled on daily | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.5.3 TCP initial sequence numbers | absent | none | no `tirdad` or equivalent ISN-randomization layer found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.5.4 Time synchronisation | baseline by default platform behavior | no dedicated repo surface | repo relies on normal NixOS time-sync behavior; no special governance language here | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 10.6 Keystroke fingerprinting | absent | none | not addressed in repo | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 11. File permissions | partial | `modules/security/base.nix`, `modules/core/users.nix` | repo covers some permission surfaces but not a complete file-permissions program | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 11.1 setuid / setgid | partial | `modules/security/scanners.nix` | setuid surfaces are monitored/audited more than aggressively minimized | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 11.2 umask | absent | none | no explicit global umask policy found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 12. Core dumps | baseline | `modules/security/base.nix` | systemd coredump storage/process size are explicitly restricted | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 12.1 sysctl | partial | `modules/security/base.nix` | repo covers some dump-related sysctls via `fs.suid_dumpable`, but not a broader dedicated section | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 12.2 systemd | baseline | `modules/security/base.nix` | `systemd.coredump.extraConfig` is set | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 12.3 ulimit | absent | none | no dedicated global ulimit policy found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 12.4 setuid processes | partial | `modules/security/base.nix`, `modules/security/scanners.nix` | repo limits dumpability and monitors some privileged surfaces, but not as a dedicated setuid-hardening program | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 13. Swap | baseline + daily-softened | `modules/core/storage-layout.nix`, `profiles/daily.nix`, `modules/core/boot.nix`, installer docs/scripts | zram is baseline; daily also uses encrypted-on-disk swapfile for workload spikes | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 14. PAM | partial / blocked | `modules/security/user-profile-binding.nix`, `modules/security/base.nix` | repo uses some PAM hardening, but the more experimental profile-binding path is intentionally blocked | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 15. Microcode updates | absent / unknown | none | no explicit microcode management surface found in repo pass | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 16. IPv6 privacy extensions | baseline + daily-softened | `modules/security/privacy.nix` | IPv6 privacy behavior is profile-aware | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 16.1 NetworkManager | baseline | `modules/security/privacy.nix` | Wi-Fi MAC/privacy behavior is configured through NetworkManager | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 16.2 systemd-networkd | absent | none | not the repo's managed path | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 17. Partitioning and mount options | baseline | `modules/core/storage-layout.nix`, `scripts/rebuild-install.sh`, `docs/pipeline/INSTALL-GUIDE.md` | partitioning, LUKS, Btrfs subvolumes, tmpfs-root, and mount invariants are core repo design | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 18. Entropy | partial | `modules/security/vm-tooling.nix` | entropy is not a first-class host policy area; only some surfaces appear incidentally | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 18.1 Additional entropy sources | absent | none | no dedicated extra-entropy policy found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 18.2 RDRAND | absent | none | no explicit RDRAND trust policy found | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 19. Editing files as root | adapted | workflow/docs | repo leans on declarative editing and `sudoedit`-style caution implicitly, but has no dedicated section for this | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 20. Distribution-specific hardening | adapted | repo-wide NixOS modules | the entire repo is effectively NixOS-specific hardening, but not a line-by-line Madaidan distro appendix | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 20.1 HTTPS package manager mirrors | baseline by Nix defaults / not separately tracked | Nix tooling | not a distinct governance knob in repo docs | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 20.2 APT seccomp-bpf | not applicable | none | APT-specific subsection does not apply to NixOS | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21. Physical security | baseline + staged | install/docs, `modules/security/secure-boot.nix`, `profiles/*` | repo treats this as encryption baseline plus staged boot-chain and USB tightening | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.1 Encryption | baseline | `modules/core/storage-layout.nix`, `scripts/rebuild-install.sh` | LUKS is part of the install baseline | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.2 BIOS / UEFI hardening | staged / operator-managed | `docs/pipeline/POST-STABILITY.md` | firmware hardening is part of post-stability/operator checklist, not encoded fully in Nix | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.3 Bootloader passwords | absent / deferred | none | not implemented in repo | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.3.1 GRUB | not applicable | none | repo uses systemd-boot/Lanzaboote direction, not GRUB | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.3.2 Syslinux | not applicable | none | not used | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.3.3 systemd-boot | baseline + staged | `modules/core/boot.nix`, `modules/security/secure-boot.nix` | systemd-boot is baseline; Secure Boot/Lanzaboote on top is staged | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.4 Verified boot | staged | `modules/security/secure-boot.nix`, `scripts/post-install-secureboot-tpm.sh` | Lanzaboote path exists but is intentionally post-stability | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.5 USBs | daily-softened | `profiles/*`, `modules/security/governance.nix` | USB restriction is enforced for paranoid and softened for daily | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.6 DMA attacks | partial / staged | kernel/IOMMU-related posture not explicitly documented as its own tracker row | repo likely benefits from platform defaults, but this is not a clearly tracked governance item yet | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 21.7 Cold boot attacks | partial by encryption baseline | LUKS docs/install path | disk encryption helps, but repo does not claim a full cold-boot mitigation program | https://madaidans-insecurities.github.io/guides/linux-hardening.html |
| 22. Best practices | baseline | `README.md`, `docs/governance/PROJECT-STATE.md`, `docs/maps/PROFILE-POLICY.md`, `docs/maps/HARDENING-TRACKER.md` | repo governance explicitly treats hardening as layered, staged, and threat-model driven | https://madaidans-insecurities.github.io/guides/linux-hardening.html |

## NixOS policy anchors

| topic | repo state | where | why | source |
|---|---|---|---|---|
| `users.mutableUsers = false` (immutable) | baseline | `modules/core/users.nix` | declarative password management via hashedPasswordFile | https://mynixos.com/nixpkgs/option/users.mutableUsers |
