# PRE-INSTALL

Checks and preparation before erasing and reinstalling.

## 1. Disk target
- identify the real target disk
- verify it is the disk you intend to wipe
- confirm you have backups for anything still needed

## 2. Hardware and account assumptions
- confirm GPU target path still matches the repo
- confirm the intended `player` and `ghost` account model
- confirm `users.users.ghost.uid` / group assumptions before install

## 3. Secrets and inputs you must already have
Prepare, but do not commit:
- age identities / encrypted secret material
- if you plan to enable the staged self-owned WireGuard path later: private key file
- if you plan to enable the staged self-owned WireGuard path later: optional preshared key file
- if you plan to enable the staged self-owned WireGuard path later: WireGuard address
- if you plan to enable the staged self-owned WireGuard path later: WireGuard server public key
- if you plan to enable the staged self-owned WireGuard path later: WireGuard endpoint as literal `IP:port`

## 4. Profile understanding
Know the initial profile split before you wipe:
- daily: `sandbox.apps = true`, `sandbox.browsers = false`, `wireguardMullvad.enable = false`
- paranoid: `sandbox.apps = false`, `sandbox.browsers = true`, `wireguardMullvad.enable = false` (self-owned WireGuard module exists but is still staged off by default), `sandbox.vms = true`

## 5. Browser expectations
- daily Firefox is now an arkenfox-derived baseline with explicit daily relaxations
- paranoid `safe-firefox` uses the stricter local version of that baseline inside the browser wrapper
- Tor Browser and Mullvad Browser keep upstream browser hardening; extra wrapper tightening is a later tuning stage, not a pre-install dependency

## 6. WireGuard preparation
The self-owned paranoid WireGuard path requires a pinned endpoint when you choose to enable it later.
Before turning that staged path on, generate or obtain a self-owned WireGuard config and pin the relay as literal `IP:port` from a trusted environment.
Current default repo state keeps this module off until validated with real target secrets and endpoints.

## 7. VM tooling expectations
The VM layer is tooling, not a finished hostile-workload workflow.
Do not wipe/reinstall assuming hostile-workload VM policy is already fully defined.

## 8. Pre-install static checks
Before wiping, confirm the repo still matches intent:
- read `PROJECT-STATE.md`
- read `AUDITS.md`
- run `./scripts/audit-tutorial.sh` if available in a Nix-enabled environment

## 9. Stop conditions
Do not wipe yet if:
- you intend to enable the staged self-owned WireGuard path soon, but the endpoint still uses a hostname
- you intend to enable the staged self-owned WireGuard path soon, but the required WireGuard secrets are missing
- you have not confirmed the target disk
- you have not confirmed the account/UID assumptions

## 10. Hardware-config reconciliation plan
- `hosts/nixos/hardware-install-generated.nix` should be created from the installer after the new layout is mounted
- `hosts/nixos/hardware-target.nix` remains the maintained target file
- merge fresh hardware detection deltas into `hardware-target.nix`; do not overwrite repo-owned layout, impermanence, or profile policy wholesale
