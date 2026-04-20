# Publication refactor plan (v2 — framework model)

Canonical plan for the "personal project → publication-ready hardening framework" refactor. Single source of truth for this multi-stage pass. Do not delete until the plan is fully executed or superseded.

v1 (single-axis knob-ification) was superseded by v2 (two orthogonal axes + library framework) after operator feedback during planning.

## 0. Vision

The target is not "a dotfiles repo with options". The target is a **composable hardening framework**:

1. A NixOS user with an **existing flake** imports `nixosModules.<feature>` from this repo and integrates specific capabilities (kernel hardening, sandboxed browsers, VM tooling, gaming, VR) into their own config.
2. A NixOS user **without** a config forks the whole repo, edits identity in a few well-known places, and gets a working hardened workstation.
3. The **original operator** uses the same modules to run their specific machine as one reference consumer of the library.

All three use-cases share the same code path. The library is the primary artifact; the operator's running machine is one example of consuming it.

## 1. Design principles

1. **Two orthogonal axes.** The system axis (specialization: kernel, services, sandbox policy, firewall) and the user axis (account: home-manager, shell, identity, group membership, home layout) are independent. The current `paranoid ↔ ghost` and `daily ↔ player` 1:1 coupling is accidental and must be dissolved. Forkers can add a new specialization without adding a user; forkers can add a user without a new specialization; the same user can be active on multiple specializations.
2. **Structural assertions, not name-based.** Governance never asserts "ghost not in wheel". It asserts "no user active on a wheel-restricted profile may be in wheel". Invariants live in the structure, not in string matches.
3. **Modules are plug-and-play.** Every module declares its own options alongside its implementation. `myOS.<domain>.<feature>.enable` + `config = lib.mkIf cfg.enable { ... }` is the canonical shape. A module must not depend on sibling modules being imported.
4. **Defaults preserve current behaviour.** After each stage the operator's machine must produce the same derivation (or an obvious whitespace-level diff) as before.
5. **Identity is never in tracked files.** Operator identity (git name/email, personal mic alias, personal repo paths) lives in gitignored `*.local.nix` files loaded via `lib.optional (pathExists ...)` imports. Tracked files carry only defaults (null / sensible public defaults).
6. **Every stage is independently shippable.** One stage = one atomic commit; repo stays green after each.
7. **Tests remain the safety net.** Tests parameterise over names; adding a new user or specialization must not require editing tests.
8. **Governance stays strict under default config.** Debug mode is the only way to relax invariants, and it is explicit, logged, and visible in every rebuild.

## 2. The two-axis model

### 2.1 System axis — `myOS.profile`

A specialization is a **system posture**: kernel parameters, sysctls, firewall rules, service enablement, sandbox policy, boot-time kernel options.

Reference specializations:
- `paranoid` — hardened workstation posture (current default)
- `daily` — permissive gaming/social posture

A forker can declare a new profile `family` or `vm-host` without touching the user layer.

### 2.2 User axis — `myOS.users.<name>.*`

An account is a **user persona**: home-manager config, shell, extra groups, home layout (persistent vs tmpfs+allowlist), wheel permission, identity (git, mic, workspace paths).

Reference accounts:
- `ghost` — paranoid-style user (tmpfs home, no wheel, locked-down)
- `player` — daily-style user (persistent home, wheel, gaming stack)

### 2.3 Binding the two axes — host config

A host's `default.nix` imports profiles + accounts + local overrides and declares:

```nix
myOS.profile = "paranoid";                      # default boot profile
myOS.users.ghost.activeOnProfiles  = [ "paranoid" ];
myOS.users.player.activeOnProfiles = [ "daily" ];
specialisation.daily.configuration.myOS.profile = "daily";
```

A user with `activeOnProfiles = [ "paranoid" "daily" ]` would be unlocked on both. A user with `activeOnProfiles = []` is declared but always locked (useful for transient / cold-wallet accounts).

### 2.4 User submodule shape (final design)

```nix
myOS.users = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
    options = {
      enable = lib.mkOption { type = types.bool; default = true; };

      # Activation
      activeOnProfiles = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Profile names under which this user is unlocked and home-mounted.";
      };

      # Unix identity
      description = lib.mkOption { type = types.str; default = ""; };
      uid         = lib.mkOption { type = types.nullOr types.int; default = null; };
      shell       = lib.mkOption { type = types.package; default = pkgs.zsh; };
      extraGroups = lib.mkOption { type = types.listOf types.str; default = []; };

      # Permissions (governance-checked)
      allowWheel = lib.mkOption {
        type = types.bool; default = false;
        description = "Whether this user may have 'wheel' in extraGroups. Governance asserts.";
      };

      # Home layout
      home.persistent = lib.mkOption { type = types.bool; default = true; };
      home.allowlist  = lib.mkOption { type = types.listOf types.str; default = []; };

      # Home-manager binding
      homeManagerConfig = lib.mkOption { type = types.nullOr types.path; default = null; };

      # Identity (defaults null; filled by gitignored *.local.nix)
      identity.git.name   = lib.mkOption { type = types.nullOr types.str; default = null; };
      identity.git.email  = lib.mkOption { type = types.nullOr types.str; default = null; };
      identity.audio.micSourceAlias      = lib.mkOption { type = types.nullOr types.str; default = null; };
      identity.workspace.autoUpdateRepoPath = lib.mkOption { type = types.nullOr types.str; default = null; };
    };
  }));
  default = {};
};
```

### 2.5a Feature scope distribution (system / user / both)

Features do not all live on the same axis. The framework distinguishes three scopes, and every feature module declares its scope explicitly (both by convention and by which option paths it uses).

| scope | what it controls | declared at | consumed by |
|---|---|---|---|
| **system-scope** | global to the host — kernel, services, firewall, packages installed system-wide, sandbox-core primitives, audit daemon, scanners | `options.myOS.<domain>.<feature>.*` | NixOS modules |
| **user-scope** | per-user — home-manager config, shell, git identity, per-user launcher defaults, per-user autostart | `options.myOS.users.<name>.<domain>.<feature>.*` | home-manager modules (via `osConfig.myOS.users.${name}.*`) |
| **cross-cutting (both)** | the system must install/enable a resource AND the user must opt in | BOTH namespaces declared in the same file | the feature module wires the system side; home-manager fragments wire the user side |

#### 2.5a.1 Scope-classification table (current repo features)

| feature | scope | system-side | user-side |
|---|---|---|---|
| kernel hardening | system | `myOS.security.kernelHardening.*` | — |
| sandbox-core (bwrap primitive) | system | `myOS.security.sandbox.*` | — |
| sandboxed browsers (safe-firefox, safe-tor, safe-mullvad) | cross-cutting | `myOS.security.sandbox.browsers` (installs wrappers) | `myOS.users.<name>.browser.safeDefault` (sets user default browser) |
| Mullvad app / WireGuard | system | `myOS.security.{wireguardMullvad,wireguard}.*` | — |
| VM tooling | cross-cutting | `myOS.security.sandbox.vms` (libvirtd service) | `myOS.users.<name>.vmAccess.enable` (adds user to libvirtd group) |
| Flatpak framework | system | `myOS.desktop.flatpak.enable` | — |
| Flatpak apps (Signal, Bitwarden) | user | — | `myOS.users.<name>.flatpak.apps = [ ... ]` |
| ClamAV / AIDE | system | `myOS.security.scanners.*` | — |
| Plasma / Hyprland | cross-cutting | `myOS.desktopEnvironment` | `myOS.users.<name>.desktop.*` (per-user appearance) |
| Gaming stack (Steam, gamescope, gamemode) | system | `myOS.gaming.*` | — |
| Controllers | system | `myOS.gaming.controllers.enable` | — |
| VR (wivrn) | cross-cutting | `myOS.gaming.vr.enable` | `myOS.users.<name>.vr.enable` (realtime group, per-user headset config) |
| Shell (zsh + starship + aliases) | user | — | `myOS.users.<name>.shell.*` |
| Git identity | user | — | `myOS.users.<name>.identity.git.*` |
| Mic loopback alias (`echo_mic`) | user | — | `myOS.users.<name>.identity.audio.micSourceAlias` |
| Theme (Stylix) | cross-cutting | `myOS.theme.*` (system defaults) | `myOS.users.<name>.theme.override` (optional per-user override) |
| Japanese input (fcitx5 + mozc-ut) | cross-cutting | `myOS.i18n.japanese.enable` (installs fcitx5 + JP fonts) | `myOS.users.<name>.i18n.japanese.autoStart` (per-user session startup) |
| Brazilian locale | system | `myOS.i18n.brazilian.enable` (locale + keymap) | — |
| Hostname | system | `myOS.host.hostName` | — |
| Timezone | cross-cutting | `myOS.host.timeZone` (default for everyone) | `myOS.users.<name>.host.timeZoneOverride` (override via TZ env) |
| Keyboard layout | cross-cutting | `myOS.host.xkb.layout` | `myOS.users.<name>.host.xkb.layoutOverride` |
| Auto-update service | cross-cutting | `myOS.autoUpdate.enable` (systemd timer) | `myOS.users.<name>.autoUpdate.repoPath` (which repo to update) |
| Debug mode (this stage) | system | `myOS.debug.*` | — |

"cross-cutting" means the feature declares options at both scopes. "user" means only the user-scoped knob exists; "system" means only the system-scoped knob exists.

#### 2.5a.2 User-scoped option contribution pattern

Multiple modules extend `myOS.users.<name>.*` via NixOS option merging. A feature module contributes its user-side options by declaring:

```nix
# Inside the feature module file (e.g. modules/i18n/japanese.nix)
options.myOS.users = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    options.i18n.japanese.autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start fcitx5 automatically in the user's Wayland session.";
    };
  });
};
```

NixOS merges the submodule type across every module that declares it, so each feature can contribute its own user-side options in its own file. This keeps feature knowledge co-located: one file per feature declares both the system-side and user-side options and wires both sides in the same `config` block.

If merging proves fragile, the fallback is a centralized `modules/core/user-options/` directory where each file is an imported submodule fragment — same semantics, one extra indirection.

#### 2.5a.3 Home-manager binding

Home-manager fragments read per-user config via `osConfig`:

```nix
# modules/home/i18n-japanese.nix (home-manager fragment)
{ osConfig, config, lib, pkgs, ... }:
let
  userCfg = osConfig.myOS.users.${config.home.username} or {};
  jp = userCfg.i18n.japanese or { autoStart = false; };
in {
  # ... per-user config using jp.autoStart
}
```

Accounts (`accounts/ghost.nix`, `accounts/player.nix`) import the home-manager fragments they want:

```nix
# accounts/player.nix
{
  myOS.users.player = {
    activeOnProfiles = [ "daily" ];
    # ... base config ...
    homeManagerConfig = ../modules/home/player.nix;  # or inline
  };
}
```

`modules/home/player.nix` then imports feature fragments:

```nix
{ ... }: {
  imports = [
    ./common.nix
    ./i18n-japanese.nix   # per-user Japanese binding
    ./shell.nix           # per-user zsh/starship
    # ... etc
  ];
}
```

#### 2.5a.4 Precedence for cross-cutting options

Where an option can be set at either scope (e.g. `myOS.host.timeZone` vs `myOS.users.<name>.host.timeZoneOverride`), user-scoped setting wins when non-null; otherwise system-scoped default applies.

#### 2.5a.5 Rationale

- System- and user-scopes are **orthogonal**, matching the two-axis model (§2).
- Each feature module stays **self-contained** — one file declares both scopes and wires both sides.
- **Extension** is straightforward for forkers: add a new feature module, declare both scopes, write the home-manager fragment.
- **Integrators** (external flake consumers) can cherry-pick system-scoped modules without pulling any user-side baggage.
- **Governance** can reason about both scopes using the same mechanism (`myOS.users._activeOn` for "is this user active", plus direct reads from system options).

### 2.5b Governance assertions (restated structurally)

Before (name-based):
```nix
assertions = [{
  assertion = !(builtins.elem "wheel" (config.users.users.ghost.extraGroups or []));
  message = "ghost must not be in wheel on paranoid";
}];
```

After (structural):
```nix
assertions = lib.mapAttrsToList (name: userCfg: {
  assertion = !(userCfg.activeOnProfiles != [] &&
                builtins.elem cfg.myOS.profile userCfg.activeOnProfiles &&
                !userCfg.allowWheel &&
                builtins.elem "wheel" userCfg.extraGroups);
  message = "user ${name} is active on profile ${cfg.myOS.profile} with allowWheel=false but has 'wheel' in extraGroups";
}) cfg.myOS.users;
```

Same semantics under the default ghost-on-paranoid binding; works automatically for new profiles and new users.

## 3. Target directory shape

```
dotfiles/
├── flake.nix                          # exposes nixosModules.* + nixosConfigurations.nixos
├── modules/                           # THE LIBRARY (importable by external flakes)
│   ├── core/
│   │   ├── default.nix                # namespace entry point
│   │   ├── options.nix                # ONLY cross-cutting: myOS.profile, myOS.gpu, myOS.host
│   │   ├── boot.nix
│   │   ├── debug.nix                  # NEW in Stage 1 — myOS.debug.*
│   │   └── users-framework.nix        # NEW in Stage 4 — myOS.users.* option space
│   ├── security/                      # each file: options + config in same file
│   │   ├── kernel-hardening.nix
│   │   ├── sandbox-core.nix
│   │   ├── browser.nix
│   │   ├── sandboxed-apps.nix
│   │   ├── vm-tooling.nix
│   │   ├── privacy.nix
│   │   ├── governance.nix             # structural assertions
│   │   ├── impermanence.nix           # consumes user.home.allowlist
│   │   ├── scanners.nix               # consumes user home paths via myOS.users
│   │   ├── flatpak.nix
│   │   ├── wireguard.nix
│   │   ├── secure-boot.nix
│   │   ├── secrets.nix
│   │   └── i18n.nix                   # NEW — jp/br toggles
│   ├── desktop/
│   │   ├── base.nix
│   │   ├── plasma.nix
│   │   ├── hyprland.nix
│   │   ├── greeter.nix
│   │   ├── theme.nix
│   │   ├── shell.nix
│   │   ├── gaming.nix
│   │   ├── controllers.nix
│   │   ├── vr.nix
│   │   └── auto-update.nix            # NEW — extracted from base.nix
│   ├── gpu/
│   │   ├── nvidia.nix
│   │   └── amd.nix
│   └── home/                          # home-manager fragments (NOT user bindings)
│       ├── common.nix
│       ├── ghost.nix                  # pure hm config; no user-name binding
│       └── player.nix                 # pure hm config; no user-name binding
├── profiles/                          # reference SYSTEM postures
│   ├── paranoid.nix                   # pure system posture; does NOT reference users
│   └── daily.nix                      # pure system posture; does NOT reference users
├── accounts/                          # NEW — reference USER personas
│   ├── ghost.nix                      # tracked defaults; imports ghost.local.nix if exists
│   └── player.nix                     # tracked defaults; imports player.local.nix if exists
├── hosts/                             # reference HOST instantiations
│   └── nixos/                         # the operator's machine (one of many possible consumers)
│       ├── default.nix                # imports profiles + accounts + local.nix
│       ├── fs-layout.nix              # parameterised on myOS.users
│       ├── hardware-target.nix        # gitignored
│       └── local.nix                  # gitignored — system-level operator overrides
├── templates/                         # Stage 6 — flake templates for external consumers
│   └── workstation/
│       └── flake.nix
├── tests/                             # unchanged structure; content parameterised
├── scripts/                           # installer etc
└── docs/
    ├── FORK-GUIDE.md                  # NEW — "you forked this; do these N things"
    ├── INTEGRATION-GUIDE.md           # NEW — "you have a flake; import these modules"
    ├── CUSTOMIZATION.md               # NEW — every myOS.* option reference
    ├── REFACTOR-PLAN.md               # this file
    ├── maps/                          # governance / audit / source coverage
    ├── pipeline/                      # install / test / recovery / post-stability
    └── governance/
        ├── PROJECT-STATE.md           # moved from repo root
        └── REFERENCES.md              # moved from repo root
```

## 4. Override model

Two override layers, both gitignored. Neither uses a magic filename — they are `lib.optional (pathExists …)` imports.

### 4.1 System overrides — `hosts/<hostname>/local.nix`

System-axis operator overrides live here. Examples:

```nix
# templates/default/hosts/nixos/local.nix — gitignored
{
  myOS.i18n.japanese.enable = true;
  myOS.i18n.brazilian.enable = true;
  myOS.host.hostName = "my-actual-hostname";
  myOS.autoUpdate.enable = true;
}
```

### 4.2 User overrides — `accounts/<username>.local.nix`

User-axis overrides (identity) live here. Examples:

```nix
# accounts/player.local.nix — gitignored
{
  myOS.users.player.identity.git.name  = "Elaina";
  myOS.users.player.identity.git.email = "48662592+oestradiol@users.noreply.github.com";
  myOS.users.player.identity.audio.micSourceAlias = "Fifine_Microphone";
  myOS.users.player.identity.workspace.autoUpdateRepoPath = "/home/player/dotfiles";
}
```

Both override paths are loaded via:
```nix
imports = lib.optional (builtins.pathExists ./local.nix) ./local.nix;
```

### 4.3 Integrator pattern (external flake)

Integrators bypass both override files and set options directly in their own flake:

```nix
# my-existing-flake.nix
{
  inputs.hardening.url = "github:oestradiol/NixOS";
  outputs = { nixpkgs, hardening, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      modules = [
        hardening.nixosModules.core
        hardening.nixosModules.security-kernel
        hardening.nixosModules.security-sandbox-core
        hardening.nixosModules.security-sandbox-browsers
        hardening.nixosModules.users-framework
        {
          myOS.profile = "paranoid";
          myOS.security.kernelHardening.nosmt = true;
          myOS.users.alice = {
            activeOnProfiles = [ "paranoid" ];
            home.persistent = true;
            allowWheel = true;
            extraGroups = [ "wheel" "networkmanager" ];
            homeManagerConfig = ./home/alice.nix;
            identity.git = { name = "Alice"; email = "alice@example.com"; };
          };
        }
      ];
    };
  };
}
```

## 5. Flake outputs (target)

```nix
{
  nixosModules = {
    # Full stack
    default = { imports = [ ./modules/core ./modules/security ./modules/desktop ./modules/gpu ]; };

    # Core
    core                         = ./modules/core;
    core-debug                   = ./modules/core/debug.nix;
    users-framework              = ./modules/core/users-framework.nix;

    # Security (one import per coherent capability)
    security                     = ./modules/security;
    security-kernel-hardening    = ./modules/security/kernel-hardening.nix;
    security-sandbox-core        = ./modules/security/sandbox-core.nix;
    security-sandbox-browsers    = ./modules/security/browser.nix;
    security-sandboxed-apps      = ./modules/security/sandboxed-apps.nix;
    security-vm-tooling          = ./modules/security/vm-tooling.nix;
    security-privacy             = ./modules/security/privacy.nix;
    security-impermanence        = ./modules/security/impermanence.nix;
    security-flatpak             = ./modules/security/flatpak.nix;
    security-scanners            = ./modules/security/scanners.nix;
    security-wireguard           = ./modules/security/wireguard.nix;
    security-secure-boot         = ./modules/security/secure-boot.nix;
    security-governance          = ./modules/security/governance.nix;
    security-i18n                = ./modules/security/i18n.nix;

    # Desktop
    desktop                      = ./modules/desktop;
    desktop-plasma               = ./modules/desktop/plasma.nix;
    desktop-hyprland             = ./modules/desktop/hyprland.nix;
    desktop-gaming               = ./modules/desktop/gaming.nix;
    desktop-controllers          = ./modules/desktop/controllers.nix;
    desktop-vr                   = ./modules/desktop/vr.nix;
    desktop-auto-update          = ./modules/desktop/auto-update.nix;

    # GPU
    gpu-nvidia                   = ./modules/gpu/nvidia.nix;
    gpu-amd                      = ./modules/gpu/amd.nix;
  };

  # Reference consumer (the operator's own machine)
  nixosConfigurations.nixos = ...;

  # Bootstrap templates
  templates.workstation = {
    path = ./templates/workstation;
    description = "Hardened workstation bootstrap using the oestradiol/NixOS framework";
  };
}
```

## 6. Stage plan (revised)

Each stage lands one atomic commit; repo stays green between stages.

### Stage 1 — `myOS.debug` knob (immediate unblock)

**Goal:** declarative replacement for the two ad-hoc debug edits.

**Unchanged from v1.** See §7.1 for design.

### Stage 2 — Option co-location

**Goal:** every module declares its own options. `modules/core/options.nix` shrinks to cross-cutting scaffolding (profile, gpu, host) plus namespace roots.

**Scope:**
- Move `myOS.security.sandbox.*` into the sandbox modules.
- Move `myOS.security.{aide,agenix,impermanence,persistMachineId,...}` into their modules.
- Move `myOS.security.wireguardMullvad.*` into `wireguard.nix`.
- Move `myOS.security.kernelHardening.*` into a new `modules/security/kernel-hardening.nix` (split out from `base.nix` + `core/boot.nix`).
- Move `myOS.gaming.*`, `myOS.vr.*` into their modules.
- `modules/core/options.nix` after Stage 2: `myOS.profile`, `myOS.gpu`, `myOS.desktopEnvironment`, `myOS.persistence.root` — nothing else.

No behavioural change. `tests/lib/eval-cache.nix` attr paths unchanged (all still resolvable; the declaration site moved, not the path).

### Stage 3 — Knob-gate currently-hardcoded subsystems

**Goal:** every feature that is currently unconditionally on becomes `myOS.<path>.enable` with current-behaviour default.

**New knobs (all default to current behaviour):**
- `myOS.desktop.flatpak.enable` (true)
- `myOS.security.scanners.clamav.enable` (true)
- `myOS.security.scanners.aide.enable` (already exists — verify)
- `myOS.autoUpdate.enable` + `myOS.autoUpdate.repoPath` (enable=true; repoPath default derived from active daily user)
- `myOS.gaming.enable` (true, gated by profile = daily default; top-level gate)
- `myOS.gaming.{steam,gamescope,gamemode}.enable` (all true when gaming enabled)
- `myOS.gaming.vr.enable` (true; was always-imported)
- `myOS.gaming.controllers.enable` (already exists)
- `myOS.i18n.japanese.enable` + `myOS.i18n.japanese.{inputMethod,fonts}.enable` (finer split — D5c option)
- `myOS.i18n.brazilian.enable` + `myOS.i18n.brazilian.{locale,keyboard}.enable`
- `myOS.host.hostName` (default `"nixos"`)
- `myOS.host.timeZone` (default `"America/Sao_Paulo"`)
- `myOS.host.defaultLocale` (default `"en_GB.UTF-8"`)
- `myOS.networking.primaryInterface` (default `"enp5s0"`)

After Stage 3: no service is turned on "just because". Every enabled feature has a visible knob lineage.

**Pause for greenlight after Stage 3.** The operator reviews the fully knob-gated repo before we pull the two-axis decoupling trigger.

### Stage 4 — User/profile decoupling (GREENLIGHT REQUIRED)

**Goal:** implement the two-axis model in §2. This is the largest semantic shift.

**Steps (executed as Stage 4a/4b/4c sub-commits):**

- **4a** — Introduce `modules/core/users-framework.nix` with the `myOS.users.<name>.*` submodule option space (§2.4). No consumer yet; just the option shell.
- **4b** — Rewrite `modules/core/users.nix` to read from `myOS.users` instead of hardcoding `player` / `ghost`. Introduce `accounts/ghost.nix` and `accounts/player.nix` as data files. `profiles/*.nix` stop declaring `home-manager.users.*`; that moves into the account files. Hosts import accounts explicitly.
- **4c** — Update every consumer (`impermanence.nix`, `scanners.nix`, `vm-tooling.nix`, `fs-layout.nix`, `governance.nix`) to read from `myOS.users` attrset instead of literal names. Governance assertions become structural (§2.5). Tests parameterised.

**Exit criteria:**
- Repo produces same derivation as before Stage 4 (default ghost/player identity).
- `grep -rn '"player"\|"ghost"' modules/ profiles/ tests/lib/ templates/default/hosts/nixos/fs-layout.nix` returns only default values in `accounts/*.nix` and the activation-predicate defaults.
- Adding a synthetic test user via `myOS.users.alice = { ... }` in a test fixture works with zero other edits.

### Stage 5 — Identity separation

**Goal:** no tracked file carries operator identity.

- `modules/home/player.nix` loses git name/email; reads from `config.myOS.users.player.identity.git.*` (with sensible fallbacks if null — e.g. don't configure git if both fields null).
- `modules/desktop/shell.nix` loses `Fifine_Microphone`; reads from `config.myOS.users.<active-daily-user>.identity.audio.micSourceAlias`.
- `modules/desktop/auto-update.nix` reads `config.myOS.users.<active-daily-user>.identity.workspace.autoUpdateRepoPath`.
- `accounts/player.local.nix` (gitignored) added to operator's machine with current identity.
- `accounts/ghost.local.nix` (gitignored) with ghost's identity.
- `templates/default/hosts/nixos/local.nix` (gitignored) with system-level overrides (jp, br, hostname, tz).
- `example/{local.nix,player.local.nix,ghost.local.nix}.sample` (tracked) showing the pattern.

### Stage 6 — Framework separation (flake outputs + templates)

**Goal:** the repo becomes importable by external flakes.

- `flake.nix` adds `nixosModules.<feature>` outputs (§5).
- `templates.workstation` output: a minimal flake that imports this as an input and sets up a hardened workstation with one reference user.
- Validate: add a `tests/integration/` subsuite that builds a synthetic external-flake consumer (uses this flake as an input) and checks it evaluates.
- Rename namespace? Pending operator decision (Q-NAMESPACE). If renaming, this is where it happens.

### Stage 7 — Tests and governance sweep

**Goal:** `grep -rn 'player\|ghost'` in `tests/` returns nothing except tests that explicitly test the *default* account values.

- `tests/lib/common.sh::detect_profile` reads user names from the eval cache.
- `tests/lib/eval-cache.nix` queries `myOS.users.*.name` (or the attrs' names directly).
- Every hardcoded name becomes a lookup.

### Stage 8 — Publication polish

- `README.md` rewritten as a framework pitch.
- `docs/FORK-GUIDE.md` — reference-config fork workflow.
- `docs/INTEGRATION-GUIDE.md` — external-flake integration workflow.
- `docs/CUSTOMIZATION.md` — option reference (one section per `myOS.*` namespace).
- `docs/maps/FEATURES.md`, `docs/maps/HARDENING-TRACKER.md`, `docs/maps/SOURCE-COVERAGE.md` — updated for new structure.
- `docs/pipeline/{INSTALL-GUIDE,TEST-PLAN,RECOVERY,POST-STABILITY}.md` — updated for new structure.
- `CHANGELOG.md` — staged history of this refactor.
- Move `PROJECT-STATE.md` and `REFERENCES.md` into `docs/governance/`.
- Tag `v0.1.0-framework`.

## 7. Stage 1 (`myOS.debug`) detailed design

### 7.1 Option space

```nix
# modules/core/debug.nix
{ config, lib, ... }:
let cfg = config.myOS.debug;
in {
  options.myOS.debug = {
    enable = lib.mkEnableOption "repo-wide debug mode (relaxes some governance invariants)";

    crossProfileLogin.enable = lib.mkEnableOption ''
      allow users of the non-active profile to authenticate at the greeter
      (i.e. on paranoid, player's hashedPasswordFile is set; on daily, ghost's is set).
      The account-lock invariant in users.nix is skipped.
    '';

    paranoidWheel.enable = lib.mkEnableOption ''
      allow the paranoid-profile user (ghost, by reference config) to be in wheel.
      Governance stops asserting "ghost not in wheel".
    '';

    verbose.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;     # matches current repo: --show-trace is on by default
      description = "Enable --show-trace on all flake-rebuild aliases.";
    };

    warnings.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Emit a NixOS warning on every rebuild listing which debug sub-flags are on.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.warnings.enable) {
      warnings =
        lib.optional cfg.crossProfileLogin.enable
          "myOS.debug.crossProfileLogin.enable is ON — password hashes set on both profiles; account-lock invariant relaxed."
        ++ lib.optional cfg.paranoidWheel.enable
          "myOS.debug.paranoidWheel.enable is ON — paranoid user is in wheel; governance invariant relaxed.";
    })
  ];
}
```

`myOS.debug.enable` is the master gate. Setting any `*.enable` sub-flag without `myOS.debug.enable = true` is a no-op (governance does not relax, passwords are not cross-set). This is enforced by wrapping every downstream check as `cfg.enable && cfg.<sub>.enable`.

### 7.2 Wiring

- **`modules/core/users.nix`:** the account-lock branches are guarded by `lib.mkIf (!(cfg.myOS.debug.enable && cfg.myOS.debug.crossProfileLogin.enable))`. When debug+crossProfileLogin is on, both accounts get `hashedPasswordFile` regardless of `myOS.profile`.
- **`modules/core/users.nix`:** ghost's `extraGroups` conditionally includes `"wheel"` when `cfg.myOS.debug.enable && cfg.myOS.debug.paranoidWheel.enable`.
- **`modules/security/governance.nix`:** the "ghost not in wheel on paranoid" assertion is skipped when `cfg.myOS.debug.enable && cfg.myOS.debug.paranoidWheel.enable`.
- **Revert the current ad-hoc edits** in `modules/core/users.nix` (both the `hashedPasswordFile` set for player-on-paranoid and the `wheel` in ghost's extraGroups). They become pure `myOS.debug.*`-driven behaviour.

### 7.3 Tests

`tests/static/180-debug-mode.sh`:
- `myOS.debug.enable` defaults to false on both profiles.
- Sub-flags default to the intended defaults (`verbose.enable = true`, `warnings.enable = true`, others `false`).
- With `myOS.debug.enable = false`, enabling a sub-flag does nothing (eval shows no `hashedPasswordFile` on the inactive user).
- With both enabled, the expected fields are set.
- With `paranoidWheel.enable = true`, ghost's extraGroups contains `"wheel"` on paranoid eval.
- With both flags off (default), the current governance assertion about ghost+wheel is active.

### 7.4 Files touched in Stage 1

| file | change |
|---|---|
| `modules/core/debug.nix` | NEW — options + warnings wiring |
| `modules/core/default.nix` (or templates import it) | add `./modules/core/debug.nix` to imports |
| `modules/core/users.nix` | revert ad-hoc edits; guard cross-profile password on debug knob; guard ghost wheel on debug knob |
| `modules/security/governance.nix` | guard the wheel assertion on debug knob |
| `tests/lib/eval-cache.nix` | add `myOS.debug.*` attrs |
| `tests/static/180-debug-mode.sh` | NEW |
| `docs/maps/HARDENING-TRACKER.md` | add debug-mode row |
| `docs/maps/FEATURES.md` | add debug-mode short section |

## 8. Consolidated decisions

The operator has resolved (in v1):
- **D1 depth** — all 8 stages.
- **D6 cadence** — stages 1–3 autonomous, greenlight before 4.

The operator has reshaped (v2):
- **D2 (user abstraction)** — supersedes into the full two-axis decoupling (§2).
- **D3 (profile naming)** — keep `paranoid` / `daily` (well-documented, descriptive).
- **D4 (personal data)** — move to gitignored `*.local.nix` files under `accounts/` and `hosts/<host>/`.
- **D5 (jp/br defaults)** — finer knobs (D5c), all default to current behaviour to preserve the operator's machine; operator's `templates/default/hosts/nixos/local.nix` (gitignored) explicitly sets `myOS.i18n.japanese.enable = true` and `myOS.i18n.brazilian.enable = true`; published fork defaults are off.

All design decisions have been resolved:

### Q-ACTIVATION — XOR of list or predicate (RESOLVED)

Final design: both options exist, exactly one must be set per user. Operator-requested XOR invariant.

```nix
myOS.users.<name> = {
  # Common path: static list, easy to introspect
  activeOnProfiles   = [ "paranoid" ];   # nullOr (listOf str), default null
  # Escape hatch: arbitrary predicate for multi-profile / compound conditions
  activationPredicate = null;            # nullOr (functionTo bool), default null
};
```

Governance asserts `(activeOnProfiles != null) != (activationPredicate != null)` — i.e. exactly one must be non-null. Both null or both set is a build error with a clear message.

Internal `_activeOn` computed option synthesises the active-profile check:
```nix
_activeOn = profile:
  if config.activeOnProfiles != null  then builtins.elem profile config.activeOnProfiles
  else if config.activationPredicate != null then config.activationPredicate profile
  else false;  # unreachable; governance catches
```

Consumers (`users.nix`, `governance.nix`, `impermanence.nix`, `scanners.nix`, `fs-layout.nix`) call `user._activeOn cfg.myOS.profile` — uniform interface regardless of whether the user declared a list or a predicate.

### Q-NAMESPACE — keep `myOS`, rename in Stage 8 (RESOLVED)

Ship Stages 1–7 with `myOS.*`. Stage 8 (publication polish) performs a single atomic rename commit covering every option path, test, doc, and eval-cache entry. Reduces cognitive load during the structural refactor; naming becomes a single focused pass at the end. Name will be chosen at Stage 8 (candidates: `paranix`, `shieldOS`, `hardos`, or something operator-provided).

### Q-LIB-SCOPE — per-feature outputs (DEFAULTED)

At Stage 6, `flake.nix` exposes one `nixosModules.<feature>` per coherent capability as listed in §5 (~25 entries). Integrators import exactly what they need. `default` aggregates everything for whole-framework consumers.

### Q-LOCAL-NIX — `pathExists` imports (DEFAULTED)

Override files load via `imports = lib.optional (builtins.pathExists ./local.nix) ./local.nix;`. Works for both `hosts/<host>/local.nix` (system overrides) and `accounts/<name>.local.nix` (user overrides). No magic filename special-casing; the convention is documented in FORK-GUIDE.md.

## 9. Open questions log (filled in during execution)

- _(none yet; append discoveries here as refactor progresses)_

---

**Last stage completed:** none (v2 plan authored).

**Next:** operator resolves Q-ACTIVATION / Q-NAMESPACE / Q-LIB-SCOPE / Q-LOCAL-NIX → executor runs Stage 1 → Stage 2 → Stage 3 → pause for greenlight → Stage 4+.
