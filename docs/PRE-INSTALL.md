# PRE-INSTALL

Only the decisions and checks that must be true before you start the install.

## 1. Confirm the target model
- one installation
- default profile = `paranoid`
- boot specialization = `daily`
- `player` = normal daily account
- `ghost` = hardened workspace account

## 2. Confirm the storage plan
You are about to install the repo's expected layout:
- EFI partition labeled `NIXBOOT`
- LUKS2 partition labeled `NIXCRYPT`
- Btrfs subvolumes for `@nix`, `@persist`, `@log`, `@swap`, `@home-daily`, `@home-paranoid`
- tmpfs root

## 3. Confirm secrets and local data you will need
Before install or immediately after first boot, know where these will live:
- user password setup method
- any agenix-managed secret files you will actually use
- Mullvad app credentials/workflow if you use the app path immediately
- if you later enable the staged self-owned WireGuard path: private key, optional preshared key, tunnel address, server public key, and pinned literal endpoint `IP:port`

## 4. Confirm the current baseline profile split
Current repo state:
- daily: `sandbox.apps = true`, `sandbox.browsers = false`, `sandbox.vms = false`, `wireguardMullvad.enable = false`
- paranoid: `sandbox.apps = false`, `sandbox.browsers = true`, `sandbox.vms = true`, `wireguardMullvad.enable = false`
- both profiles currently use Mullvad app mode by default

Browser split:
- daily Firefox = enterprise-policy-managed normal Firefox
- paranoid Firefox = `safe-firefox` wrapper with vendored arkenfox baseline + repo overrides
- Tor Browser / Mullvad Browser = upstream browser model + local wrapper containment only

## 5. Confirm what is staged and not baseline yet
These are not part of the first stable install target:
- Secure Boot rollout
- TPM-bound unlock rollout
- self-owned WireGuard host path
- repo custom audit rules
- PAM profile-binding
- custom AppArmor profile library

## 6. Red flags before you start
Stop and fix these before running the install script:
- you have not backed up the target disk
- you are not willing to wipe the target disk completely
- you have not decided how user passwords will be set before first real boot
- you intend to enable the staged self-owned WireGuard path soon but do not have a pinned literal endpoint `IP:port`
- you are planning to treat post-stability items as blocking for the first machine-usable baseline
