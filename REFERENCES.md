# REFERENCES

Canonical ledger for the external sources this repo depends on for option semantics, platform behavior, and hardening decisions.

## Purpose
- keep the external-source set in one place
- record what each source is used for
- make future re-audits easier
- separate source inventory from repo-state claims in `PROJECT-STATE.md`

## Current usage model
This file is the canonical source index.
`AUDITS.md` is the operational ledger for what has or has not been validated in the repo.

## High-tier reference set

| tier | topic | source | use in repo | repo surfaces | status |
|---|---|---|---|---|---|
| primary | NixOS options/manual | NixOS manual, option search, MyNixOS | exact option/module semantics | repo-wide code and docs | active |
| primary | NixOS operational guidance | NixOS Wiki | install and service/operator guidance | install, recovery, staged features | active |
| primary | Firefox enterprise policies | Mozilla enterprise policy documentation | daily Firefox policy model | `modules/security/browser.nix`, `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | active |
| primary | Firefox hardening baseline | arkenfox | paranoid Firefox baseline and override model | `modules/security/browser.nix`, `modules/security/arkenfox/user.js` | active |
| primary | bubblewrap | bubblewrap man page/docs | wrapper mount/env semantics | `modules/security/sandbox-core.nix`, browser/app wrapper docs | active |
| primary | xdg-dbus-proxy | upstream docs/help output | filtered D-Bus behavior | wrapper policy and browser/app docs | active |
| primary | systemd-resolved | systemd docs | DNS/fallback behavior for the staged WireGuard path | `modules/security/wireguard.nix`, recovery/test docs | active |
| primary | libvirt / virt-install | upstream docs/man pages | VM class automation and lifecycle semantics | `modules/security/vm-tooling.nix`, VM docs | active |
| primary | kernel SysRq docs | kernel documentation | `kernel.sysrq` meaning and documentation accuracy | `modules/security/base.nix`, options/docs | active |
| strong-secondary | Flatpak / xdg-desktop-portal | upstream docs | Flatpak + portal behavior | `modules/security/flatpak.nix`, docs | active |
| strong-secondary | AppArmor | NixOS and upstream docs | framework baseline semantics | `modules/security/base.nix`, docs | active |
| strong-secondary | ClamAV / AIDE | upstream docs | scanner/integrity semantics | `modules/security/scanners.nix`, docs | active |

## Repo policy notes tied to the source set
- use Mozilla enterprise policies for daily Firefox
- use arkenfox only for the paranoid Firefox baseline
- do not force arkenfox onto Tor Browser or Mullvad Browser
- keep wrapper claims limited to local host containment
- keep staged WireGuard claims limited until real-world validation is done
