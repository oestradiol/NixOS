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
| Mandatory access control (AppArmor) | Madaidan / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/PRE-INSTALL.md` | `modules/security/base.nix` | Live-check loaded AppArmor profiles |
| Mandatory access control (SELinux) | Madaidan / saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | AppArmor chosen instead for wave one |
| Sandboxing (browser, Flatpak) | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/PRE-INSTALL.md` | `modules/security/browser.nix`, `modules/security/flatpak.nix` | Validate `safe-firefox`, Tor Browser, Flatpak permissions |
| Sandboxing (broader per-app sandboxing) | Madaidan / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/POST-STABILITY.md` | `modules/security/sandboxed-apps.nix` | Validate bubblewrap wrappers for VRCX, Windsurf; install Flatpak apps manually |
| Hardened memory allocator | Madaidan / saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/security/base.nix`, `profiles/*.nix` | Keep full rollout off until post-install testing |
| Hardened compilation flags | Madaidan | Documented | `PROJECT-STATE.md`, this ledger | — | Not operationalized repo-wide in wave one |
| Memory-safe languages policy | Madaidan | Documented | `PROJECT-STATE.md`, this ledger | — | Keep as doctrine/research note; not enforceable here |
| Root account hardening doctrine | Madaidan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/PRE-INSTALL.md` | `modules/security/base.nix`, `modules/core/users.nix`, `modules/security/governance.nix` | Root locked (`!`), su wheel-only; verify after install |
| Firewalls / nftables | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | `modules/security/networking.nix` | Validate real Mullvad/WireGuard interface behavior |
| Identifiers / machine-id / profile separation | Madaidan | Implemented+Manual | `PROJECT-STATE.md`, `docs/INSTALL-GUIDE.md` | `modules/security/impermanence.nix`, `modules/security/governance.nix` | daily: persistent (stability); paranoid: randomized (privacy); verify with `cat /etc/machine-id` before/after reboot |
| File permissions / ownership hygiene | Madaidan / Trimstray | Documented | `PROJECT-STATE.md`, this ledger | various modules | Run post-install permission audit |
| Core dumps | Madaidan | Implemented | this ledger, `docs/TEST-PLAN.md` | `modules/security/base.nix` | `systemd.coredump.extraConfig` disables storage; verify with `coredumpctl` after install |
| Swap strategy | Madaidan / saylesss88 | Implemented | `PROJECT-STATE.md`, `docs/INSTALL-GUIDE.md` | `hosts/nixos/hardware-target.nix`, `modules/security/base.nix`, `scripts/install-nvme-rebuild.sh` | zram + 8GB Btrfs swapfile on `@swap` subvolume; swapfile created by install script |
| PAM hardening | Madaidan | Implemented+Manual | this ledger, `docs/TEST-PLAN.md` | `modules/security/base.nix`, `modules/vr.nix` | `su` restricted to wheel; verify PAM stack after install |
| Microcode updates | Madaidan / Trimstray | Implemented | `PROJECT-STATE.md` | `hosts/nixos/hardware-target.nix` | Validate active microcode on rebuilt host |
| IPv6 privacy extensions | Madaidan | Implemented | `PROJECT-STATE.md`, this ledger | `modules/security/base.nix` | sysctl `use_tempaddr=2` for all/default; verify with `ip -6 addr` after install |
| Partitioning and mount options | Madaidan / Trimstray / saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md` | `hosts/nixos/hardware-target.nix`, `hosts/nixos/install-layout.nix` | Execute destructive install carefully |
| Entropy hardening | Madaidan | Not yet implemented | `PROJECT-STATE.md`, this ledger | — | Deferred to late-game; not separately operationalized |
| Editing files as root / sudoedit discipline | Madaidan | Documented | this ledger, `docs/PRE-INSTALL.md` | — | Use documented admin workflow; not enforced in code |
| Distribution-specific NixOS hardening | saylesss88 / nix-mineral | Implemented+Manual | `docs/audit/SOURCE-COVERAGE-MATRIX.md` | whole repo | Audit module-by-module after install |
| Physical security | Madaidan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/RECOVERY.md` | Secure Boot / TPM modules | Requires firmware settings, passphrase discipline |
| Best-practice doctrine | Madaidan / Trimstray | Documented | `docs/PRE-INSTALL.md` | — | Human discipline remains required |
| Minimal installation | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md` | install script + host layout | Execute with care |
| LUKS / encrypted install | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md`, `PROJECT-STATE.md` | `hosts/nixos/install-layout.nix` | Perform destructive encrypted install |
| Guided encrypted Btrfs subvolumes | saylesss88 | Implemented+Manual | `docs/INSTALL-GUIDE.md` | `hosts/nixos/hardware-target.nix` | Same as above |
| disko-based install | saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | Manual scripted install chosen instead |
| Installing software declaratively | saylesss88 | Implemented | `PROJECT-STATE.md` | flake + modules | — |
| Users and sudo | saylesss88 | Implemented+Manual | `PROJECT-STATE.md` | `modules/core/users.nix`, `modules/security/governance.nix` | Confirm wheel membership and sudo policy |
| SUID binaries / setuid danger | saylesss88 / Madaidan | Documented | this ledger | `modules/security/base.nix` | Do post-install SUID audit and reduce where safe |
| Capabilities | saylesss88 | Documented | this ledger | — | Review special capability needs for gaming/VR later |
| Impermanence | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/INSTALL-GUIDE.md` | `modules/security/impermanence.nix` | Validate exactly what persists |
| NTS time sync replacement | saylesss88 | Not yet implemented | `PROJECT-STATE.md`, `docs/POST-STABILITY.md` | — | Test on paranoid after stable; may break KDE/Qt time APIs |
| Secure Boot / Lanzaboote | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/POST-STABILITY.md` | `modules/security/secure-boot.nix` | Enroll keys only after first good boot |
| Kernel choice / hardened kernel | saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/core/boot.nix` | Keep daily on compatibility-first path initially |
| sysctl hardening | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/core/boot.nix`, `modules/security/base.nix` | Validate no regressions |
| Boot parameters hardening | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/core/boot.nix` | Validate no regressions |
| Systemd hardening | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, this ledger | `modules/security/browser.nix`, `modules/security/flatpak.nix`, `modules/security/scanners.nix` | NoNewPrivileges, ProtectKernel*, LockPersonality on flatpak-repo/ClamAV/AIDE; expand per-service later |
| Lynis | saylesss88 | Implemented+Manual | `docs/TEST-PLAN.md` | `modules/security/base.nix` | Run on rebuilt host |
| SSH hardening / keygen guidance | saylesss88 | Documented | `docs/POST-STABILITY.md`, this ledger | — | Apply only if enabling SSH later |
| Encrypted secrets | saylesss88 | Implemented+Manual | `PROJECT-STATE.md`, `docs/POST-STABILITY.md` | `modules/security/secrets.nix` | Create real `.age` files |
| doas / run0 over sudo | saylesss88 | Deferred | `PROJECT-STATE.md`, `docs/POST-STABILITY.md` | — | sudo retained for wave one; post-stability analysis required (doas vs run0 vs keep sudo) |
| USB port protection | saylesss88 | Implemented | `PROJECT-STATE.md`, this ledger | `modules/core/boot.nix` | `usbcore.authorized_default=2` on paranoid (internal hubs only); verify peripherals work |
| Firejail | saylesss88 | Rejected | `PROJECT-STATE.md`, this ledger | — | Flatpak+bwrap chosen instead |
| Flatpak | saylesss88 | Implemented | `PROJECT-STATE.md` | `modules/security/flatpak.nix` | — |
| nix-mineral advanced hardening | nix-mineral / saylesss88 | Deferred | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, this ledger | — | Alpha software, different threat model; diff deferred to late game |
| GnuPG agent setup | saylesss88 | Documented+Manual | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, `docs/POST-STABILITY.md` | — | Post-stability user setup |
| Trimstray general checklist | Trimstray | Documented | `docs/audit/SOURCE-COVERAGE-MATRIX.md`, this ledger | many | Use as audit overlay, not blind import |
| Virtualization split | Original plan / Trimstray | Deferred | `PROJECT-STATE.md` | libvirt retained daily-only where relevant | Optional later wave |
| Development & packaging doctrine | Original plan | Documented | `docs/PRE-INSTALL.md` | `modules/core/nix.nix`, Git HM | Not a wave-one focus |
| Configure Git declaratively | Original plan | Implemented | `PROJECT-STATE.md` | `modules/home/common.nix` | — |
| KeePassXC + permanence | Original plan | Implemented+Manual | `PROJECT-STATE.md`, `docs/INSTALL-GUIDE.md`, `docs/POST-STABILITY.md` (section 12) | HM + impermanence modules | Verify real database path |
| PQ / future crypto planning | Original plan | Documented | `PROJECT-STATE.md` | — | No blanket "quantum-ready" claim |
| Update to latest Nix track | Original plan | Implemented | `PROJECT-STATE.md` | `flake.nix` | `nixos-unstable` chosen |
| Alternative home path | Original plan | Implemented | `PROJECT-STATE.md`, `docs/INSTALL-GUIDE.md` | split user homes/subvolumes | Audit if it meets your goals |
| Browser + networking verification | Original plan | Documented | `docs/TEST-PLAN.md`, `docs/PRE-INSTALL.md`, `docs/POST-STABILITY.md` (section 15) | — | Must be executed live |
| Signal | Original plan | Implemented+Manual | `PROJECT-STATE.md` | home modules/profile policy | Validate package availability and profile rules |
| Hardening tests | Original plan | Documented | `docs/TEST-PLAN.md` | — | Must be executed live |
| sudo / SUDO_KILLER | Original plan | Documented | this ledger | — | Deferred but tracked |
| Final AI review pass | Original plan | Implemented | `PROJECT-STATE.md`, audit docs | governance surfaces | Repeat after live install |
| Browser fingerprinting protection | Arkenfox v140+ | Implemented+Manual | `docs/PRE-INSTALL.md`, `docs/POST-STABILITY.md`, `docs/TEST-PLAN.md` | `modules/security/browser.nix` | Daily uses FPP (Fingerprinting Protection) with ETP Strict; Paranoid uses RFP (Resist Fingerprinting). Verify with https://coveryourtracks.eff.org |
| AIDE / ClamAV | Original plan / Trimstray | Implemented+Manual | `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | `modules/security/scanners.nix` | Initialize DB and evaluate usefulness |
| Full graphene-hardened after debug | Original plan | Deferred | `PROJECT-STATE.md`, `docs/PERFORMANCE-NOTES.md` | `modules/security/base.nix` | Enable only after stability/perf testing |
| Mullvad / WebRTC / DNS / Tor Browser verification | Original plan | Documented | `docs/TEST-PLAN.md`, `docs/PRE-INSTALL.md` | networking/browser modules | DNS: daily=system/VPN DNS (no DoH), paranoid=all.dns.mullvad.net via VPN (ads/trackers/malware/gambling). Verify with dnsleaktest.com |
| LUKS header backup procedure | Audit finding (blind spot) | Documented+Manual | `docs/POST-STABILITY.md` | — | Execute after install; test restore on spare container |
| EFI partition backup/verification | Audit finding (blind spot) | Documented+Manual | `docs/POST-STABILITY.md`, `docs/RECOVERY.md` | — | Backup after first boot; keep on external media |
| fstrim/discard configuration | Audit finding (blind spot) | Implemented | `docs/POST-STABILITY.md` | `modules/core/base-desktop.nix` | Option A (fstrim timer) chosen; allowDiscards disabled for LUKS safety |
| Sleep states (suspend/hibernate) | Audit finding (blind spot) | Implemented | `docs/POST-STABILITY.md` | `modules/core/options.nix`, `modules/core/base-desktop.nix`, `profiles/*.nix` | `myOS.security.allowSleep` option (default: false); both profiles explicitly disable |
| Yubikey/FIDO2/Passkey support | Audit finding (blind spot) | Documented | `docs/POST-STABILITY.md` | — | Consider for paranoid tier; requires PAM config |
| WireGuard module security audit | Audit finding (blind spot) | Documented | `docs/POST-STABILITY.md` | — | Monitor CVEs; defense-in-depth via nftables killswitch |
| Lanzaboote nuclear recovery | Audit finding (blind spot) | Documented | `docs/POST-STABILITY.md`, `docs/RECOVERY.md` | — | Extended recovery procedure for SB lockout |
| Bubblewrap GPU passthrough acknowledgment | Audit finding (blind spot) | Documented | `docs/POST-STABILITY.md` | `modules/security/browser.nix` | Isolation claim adjusted; GPU = known escape vector |
| SSH host key rotation policy | Audit finding (blind spot) | Documented+Manual | `docs/POST-STABILITY.md` | — | Procedure for post-stability key rotation |
| Thunderbolt/DMA attack surface | Audit finding (blind spot) | Documented | `docs/POST-STABILITY.md` | — | Consider BIOS disable for paranoid; DMA bypasses all OS hardening |
| First-boot login with mutableUsers | Audit finding (blind spot) | Fixed | `docs/INSTALL-GUIDE.md`, `modules/core/users.nix` | `modules/core/users.nix`, `modules/security/impermanence.nix` | `/etc/{passwd,shadow,group,gshadow,subuid,subgid}` now persisted for tmpfs-root compatibility; first-boot docs corrected (users without password cannot log in) |
| Home impermanence semantics | Audit finding (drift) | Documented | `docs/INSTALL-GUIDE.md`, `modules/security/impermanence.nix` | `modules/security/impermanence.nix` | Two models: player=direct Btrfs subvolume (@home-daily → /home/player); ghost=selective impermanence (@home-paranoid → /persist/home/ghost, tmpfs /home/ghost with allowlist bind-mounts). Both use allowlists for dotfile management. |
| Mullvad interface-based killswitch | Audit finding (maintenance risk) | Fixed | `docs/RECOVERY.md`, `modules/security/networking.nix` | `modules/security/networking.nix` | Removed hardcoded IPs; now interface-based (wg-mullvad, tun0, tun1). Bootstrap DNS leak documented as unavoidable tradeoff. |
| Self-owned WireGuard stack | External review (root architecture fix) | Implemented+Manual | `docs/PRE-INSTALL.md` Section 15, `PROJECT-STATE.md` | `modules/security/wireguard.nix`, `modules/core/options.nix`, `profiles/paranoid.nix` | Replaces Mullvad app on paranoid. Single source of truth: WireGuard config generates firewall. NixOS owns tunnel state AND policy. Requires: endpoint, keys, address configuration |
| VPN architecture split | Design decision | Implemented | `PROJECT-STATE.md` | `profiles/daily.nix`, `profiles/paranoid.nix`, `modules/security/governance.nix` | Daily: Mullvad app (convenience). Paranoid: Self-owned WireGuard (deterministic). Mutual exclusivity enforced via assertion |
| Firefox arkenfox alignment claims | Audit finding (doc drift) | Fixed | `modules/security/browser.nix`, `docs/POST-STABILITY.md` | `modules/security/browser.nix` | Daily: arkenfox-aligned (FPI disabled, ETP Strict + TCP, DoH disabled). Paranoid: FPI enabled (security over alignment), DoH disabled (VPN server DNS only). Both use system/VPN DNS, no DoH |
| Sandbox wrapper trust claims | Audit finding (overstated) | Fixed | `docs/POST-STABILITY.md`, `modules/security/browser.nix` | `modules/security/browser.nix`, `docs/POST-STABILITY.md` | Claims narrowed: GPU passthrough and broad /run,/var binds weaken isolation; "helpful containment" not "hostile-content isolation" |
| Hardened compilation flags | Madaidan | Documented | `docs/POST-STABILITY.md`, this ledger | — | Decision needed: repo-wide hardened compilation |
| Full nix-mineral diff analysis | nix-mineral / saylesss88 | Documented | `docs/POST-STABILITY.md`, this ledger | — | Decision needed: review and adopt applicable techniques |
| Secure Boot key path/persistence | Audit finding (boot-chain bug) | Fixed | `PROJECT-STATE.md`, `docs/PRE-INSTALL.md` | `modules/security/secure-boot.nix`, `modules/security/impermanence.nix`, `scripts/post-install-secureboot-tpm.sh` | pkiBundle changed to `/var/lib/sbctl` (matches sbctl default); path now persisted. Verify enrollment flow after install |
| Governance assertion count drift | Audit finding (trust bug) | Fixed | `README.md`, `PROJECT-STATE.md`, `docs/PRE-INSTALL.md` | `modules/security/governance.nix` | Count corrected to 28 assertions across all docs |
| WebRTC documentation accuracy | Audit finding (doc drift) | Fixed | `PROJECT-STATE.md`, `docs/TEST-PLAN.md`, `docs/POST-STABILITY.md` | `modules/security/browser.nix` | Daily: WebRTC enabled (gaming compromise). Paranoid: WebRTC disabled. All docs now consistent |
| First-boot password comments | Audit finding (correctness) | Fixed | `modules/core/users.nix` | `modules/core/users.nix` | Removed impossible "set via TTY on first boot" wording; added correct pre-boot password setup guidance |
| Flathub trust claim | Audit finding (overclaim) | Fixed | `PROJECT-STATE.md` | — | Narrowed: "verified publisher identity" != "reproducible builds"; reproducibility varies by app |
| PAM profile-binding | Audit finding (high-risk impl) | Implemented+Manual (default: disabled) | `docs/POST-STABILITY.md` | `modules/security/user-profile-binding.nix`, `modules/core/options.nix` | **DISABLED BY DEFAULT** due to high-risk PAM `.text` override. Opt-in via `myOS.security.pamProfileBinding.enable`. Documented verification commands and recovery procedure in POST-STABILITY.md Section 19. |
| Flatpak scanning claim | Audit finding (accuracy) | Fixed | `PROJECT-STATE.md`, `modules/security/scanners.nix` | `modules/security/scanners.nix` | Narrowed: user app data (`~/.var/app`) excluded; system Flatpak under `/var/lib/flatpak` is scanned |
| D-Bus filter browser policy mismatch | Audit finding (design bug) | Fixed | `modules/security/browser.nix` | `modules/security/browser.nix` | Generic wrapper used Firefox-specific D-Bus policy (`--own=org.mozilla.firefox.*`) for all browsers. Fixed by adding `dbusOwnName` parameter; Tor/Mullvad Browser policies disabled pending live verification (marked with TODO) |
| KeePassXC availability claim | Audit finding (doc drift) | Fixed | `docs/POST-STABILITY.md`, `modules/home/player.nix` | — | Documentation claimed KeePassXC in both profiles; actual state was paranoid-only. Corrected documentation to reflect paranoid-only availability (daily uses Bitwarden) |
| DNS/DoH documentation drift | Audit finding (doc drift) | Fixed | `PROJECT-STATE.md`, `docs/POST-STABILITY.md`, `docs/audit/SOURCE-TOPIC-LEDGER.md` | `modules/security/browser.nix` | Multiple docs incorrectly claimed daily uses DoH; actual code has `network.trr.mode = 0` (DoH disabled). All claims corrected: both profiles use system/VPN DNS only, no DoH |
| `/var/lib/systemd` + machine-id rotation | Audit finding (operational risk) | Documented+Manual | `modules/security/impermanence.nix`, `docs/TEST-PLAN.md` | `modules/security/impermanence.nix` | Paranoid persists `/var/lib/systemd` but rotates machine-id (`persistMachineId = false`). Potential systemd state/machine-id mismatch needs live validation. Added code comment and tracking |
| nftables ICMPv6 too broad | External review | Fixed | `modules/security/networking.nix`, `docs/POST-STABILITY.md` | `modules/security/networking.nix` | Changed `ip6 nexthdr icmpv6 accept` to restricted NDP-only types (rs/ra/ns/na: 133,134,135,136). Scoped to non-VPN interfaces only |
| nftables DHCP not interface-scoped | External review | Fixed | `modules/security/networking.nix` | `modules/security/networking.nix` | Scoped DHCP/NDP to `oifname != { vpnIfaces }` - prevents accidental overbreadth if extra interfaces appear |
| nftables interface name brittleness | External review | Documented+Manual | `modules/security/networking.nix`, `docs/POST-STABILITY.md` | `modules/security/networking.nix` | Hardcoded `vpnIfaces` list requires live validation per machine. Added mandatory check: compare `ip link` output against allowed names; FAIL checklist on mismatch |
| nftables framing overstated | External review | Fixed | `docs/POST-STABILITY.md`, `modules/security/networking.nix` | `docs/POST-STABILITY.md` | Removed "ping dark" language. Downgraded claim to "best-effort local fallback policy, not authoritative enforcement". Added explicit warning block about boot-gap fallback purpose |
| nftables state-machine testing | External review | Documented+Manual | `docs/POST-STABILITY.md` | — | Added testing commands for connecting/connected/disconnect/boot states. Documented interaction with Mullvad's early-boot Linux blocker. State testing checklist added to manual validation |
| mullvad.nftablesFallback removed | Simplification | Fixed | `modules/core/options.nix`, `modules/security/networking.nix` | `modules/core/options.nix` | Removed `mullvad.nftablesFallback` option entirely. Daily now relies on Mullvad's built-in lockdown-mode; paranoid uses self-owned WireGuard with deterministic nftables killswitch. Single option `wireguardMullvad.enable` controls mode |
| KeePassXC in daily impermanence | Code drift | Fixed | `modules/security/impermanence.nix`, `docs/INSTALL-GUIDE.md` | `modules/security/impermanence.nix` | Removed `.config/keepassxc` and `.local/share/KeePassXC` from daily (player) persistence list; KeePassXC is paranoid-only. Added Windsurf persistence, noted VRCX ephemeral-by-design |
| D-Bus system bus filtering | Security improvement | Implemented | `modules/security/browser.nix`, `profiles/paranoid.nix` | `modules/security/browser.nix` | Added xdg-dbus-proxy for SYSTEM bus (was unfiltered). Now filters both session and system buses. Allows: NetworkManager, logind. Blocks: unrestricted systemd access |
| D-Bus MPRIS policy | Functional fix | Implemented | `modules/security/browser.nix` | `modules/security/browser.nix` | Added `--talk=org.mpris.MediaPlayer2.*` to enable media player controls (play/pause, track info) when D-Bus filtering enabled |
| D-Bus portal broadcast rules | Functional fix | Implemented | `modules/security/browser.nix` | `modules/security/browser.nix` | Added `--broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/*` to receive portal signals (file picker responses, notification callbacks) |
| Tor/Mullvad D-Bus policies | Pending → Fixed | Fixed | `modules/security/browser.nix` | `modules/security/browser.nix` | Set `dbusOwnName = "org.mozilla.firefox.*"` for both browsers. Research (tor-browser#44050) confirmed they use org.mozilla namespace. Policies now enabled (was null/TODO) |
| D-Bus filtering profile split | Security policy | Implemented | `profiles/paranoid.nix`, `profiles/daily.nix` | `profiles/paranoid.nix` | Paranoid: `dbusFilter = true` (filtered). Daily: `dbusFilter = false` (direct /run bind for compatibility). Test plan and POST-STABILITY docs updated |
| Build-time test infrastructure | Audit improvement | Implemented | `flake.nix`, `scripts/audit-tutorial.sh` | `flake.nix` | Added `checks.x86_64-linux` with nixos-config and paranoid-config evaluation tests; fixed audit-tutorial.sh to fail on errors (removed `|| true`) |

## MONITOR: Ongoing tracking (post-stability)

| Topic | Monitor | Source | Action when triggered |
|-------|---------|--------|---------------------|
| Tor Browser D-Bus namespace | `browser.nix` D-Bus policy | https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050 | If namespace changes to `org.torproject`, update `dbusOwnName` in `safeTor` |
| Mullvad Browser D-Bus namespace | `browser.nix` D-Bus policy | https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050 | If namespace changes to `net.mullvad`, update `dbusOwnName` in `safeMullvad` |
| KDE Plasma 6.8 X11 deprecation | XWayland testing | https://blogs.kde.org/2025/11/26/going-all-in-on-a-wayland-future/ | Plasma 6.8 drops X11 session support entirely. Test all apps under XWayland, verify no hard X dependencies, plan X server disable |
| NVIDIA legacy_580 driver | GPU driver config | https://github.com/NixOS/nixpkgs/issues/503740 | GTX 1060 (Pascal) should use `legacy_580`; migrate from `production` when nixpkgs exposes it |
