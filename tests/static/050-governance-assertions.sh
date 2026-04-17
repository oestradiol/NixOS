#!/usr/bin/env bash
# Static: every paranoid invariant encoded in modules/security/governance.nix
# is actually present (syntactic check), and the related code surfaces still
# exist. This catches accidental deletions of assertions without replacement.
source "${BASH_SOURCE%/*}/../lib/common.sh"

gov="$REPO_ROOT/modules/security/governance.nix"
users_nix="$REPO_ROOT/modules/core/users.nix"

describe "governance.nix exists with the expected invariants"
assert_file "$gov"

# Each assertion message is searched verbatim. This is intentional: changing
# a message is itself a governance event and should show up in diffs.
expected_messages=(
  "Governance invariant: daily user 'player' must exist."
  "Governance invariant: paranoid user 'ghost' must exist."
  "X server must be disabled system-wide (Wayland-only stack)."
  "Paranoid profile must use sandboxed browsers exclusively (no base Firefox)."
  "Paranoid profile must keep impermanence enabled."
  "Paranoid profile must keep secrets management enabled."
  "Paranoid profile must not enable Steam."
  "Secure Boot path must not coexist with GRUB."
  "Secure Boot path requires EFI variable access."
  "TPM-bound unlock requires systemd in the initrd."
  "This design assumes greetd is enabled as the Wayland-native display manager."
  "Paranoid user must not be in the wheel group by default."
  "Paranoid profile must enable disableSMT (nosmt=force)."
  "Paranoid profile must enable USB restriction (authorized_default=2)."
  "Paranoid profile must enable audit daemon."
  "Paranoid profile must enable the Linux audit subsystem, not just auditd."
  "Paranoid profile must enable VM tooling layer."
  "Paranoid profile must enable initOnFree kernel hardening."
  "Paranoid profile must enable pageAllocShuffle kernel hardening."
  "Paranoid profile must disable kexec_load (kernel.kexec_load_disabled=1)."
  "Paranoid profile must restrict SysRq key (kernel.sysrq)."
  "Paranoid profile must disable io_uring (kernel.io_uring_disabled=2)."
  "Paranoid profile must not enable gamescope."
  "Paranoid profile must not enable gamemode."
  "Paranoid profile must not enable wivrn."
  "Daily profile must not enable hardened memory allocator."
  "GPU option must be set to either 'nvidia' or 'amd'."
  "Paranoid profile must persist machine-id."
  "Paranoid profile must keep a unique host machine-id."
  "Paranoid profile must keep X11 disabled inside bubblewrap sandboxes."
  "Paranoid profile must keep Wayland enabled inside bubblewrap sandboxes."
  "Daily profile must make the X11 compatibility relaxation explicit."
)

describe "every documented invariant is present in governance.nix"
for msg in "${expected_messages[@]}"; do
  if grep -Fq "$msg" "$gov"; then
    pass "invariant: ${msg:0:80}"
  else
    fail "missing invariant" "$msg"
  fi
done

describe "account-locking invariants in users.nix"
# Profile-user binding via account locking is the canonical mechanism.
# The conditions carry a debug-mode escape hatch (crossProfile) that lifts
# both locks together; default state (crossProfile=false) preserves the
# original paranoid↔ghost / daily↔player binding.
if grep -Fq 'hashedPasswordFile = lib.mkIf (isDaily || crossProfile)' "$users_nix" \
   && grep -Fq 'hashedPassword = lib.mkIf (isParanoid && !crossProfile) "!"' "$users_nix" \
   && grep -Fq 'hashedPasswordFile = lib.mkIf (isParanoid || crossProfile)' "$users_nix" \
   && grep -Fq 'hashedPassword = lib.mkIf (isDaily && !crossProfile) "!"' "$users_nix"; then
  pass "player/ghost account locks are conditional on profile (with debug escape hatch)"
else
  fail "account-locking mechanism drifted in users.nix"
fi

# The crossProfile / paranoidWheel shorthands must derive from the debug
# namespace with the master gate gating every sub-flag. This is what makes
# `myOS.debug.*.enable` a no-op when `myOS.debug.enable = false`.
if grep -Fq 'crossProfile = debug.enable && debug.crossProfileLogin.enable' "$users_nix" \
   && grep -Fq 'paranoidWheel = debug.enable && debug.paranoidWheel.enable' "$users_nix"; then
  pass "debug-mode master gate is required for each sub-flag in users.nix"
else
  fail "debug-mode master gate has drifted in users.nix"
fi

# mutableUsers must be false (NOTE: PROFILE-POLICY.md describes a transitional
# plan to keep it true; the actual code enforces false as of this commit).
if grep -Fq 'users.mutableUsers = false;' "$users_nix"; then
  pass "users.mutableUsers = false (declarative passwords)"
else
  fail "users.mutableUsers has drifted; account model is no longer declarative"
fi

describe "profile-mount-invariants service is declared"
fs="$REPO_ROOT/hosts/nixos/fs-layout.nix"
if grep -Fq 'systemd.services.profile-mount-invariants' "$fs"; then
  pass "profile-mount-invariants.service is declared"
else
  fail "profile-mount-invariants.service missing from fs-layout.nix"
fi

describe "assertion count roughly matches documentation (>=30)"
count=$(grep -c 'assertion =' "$gov" || true)
if [[ $count -ge 30 ]]; then
  pass "governance assertion count = $count"
else
  fail "expected >=30 governance assertions, got $count"
fi
