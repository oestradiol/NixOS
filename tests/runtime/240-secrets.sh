#!/usr/bin/env bash
# Runtime: agenix secrets subsystem. Template-agnostic: only tests if the
# feature is enabled and secrets are declared.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "secrets subsystem (agenix) detection"
agenix_enabled=$(config_value "myOS.security.agenix.enable")
secret_keys=$(config_value "age.secrets.__keys")

if [[ "$agenix_enabled" != "true" ]]; then
  skip "myOS.security.agenix.enable = false (or null) — secrets not expected"
  exit 0
fi

pass "myOS.security.agenix.enable = true"

describe "agenix identity paths"
# Check the host SSH keys agenix will use for decryption
for key_path in /persist/etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key; do
  if [[ -f "$key_path" ]]; then
    pass "agenix identity key exists: $key_path"
    # Verify it's a valid key format
    if head -1 "$key_path" 2>/dev/null | grep -q "BEGIN OPENSSH PRIVATE KEY\|BEGIN SSH2 ENCRYPTED PRIVATE KEY"; then
      pass "$key_path has valid SSH key format"
    else
      info "$key_path does not appear to be an OpenSSH format key (may be raw)"
    fi
    break
  fi
done

if [[ ! -f /persist/etc/ssh/ssh_host_ed25519_key && ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
  warn "no agenix identity key found at expected paths"
  info "agenix may not be able to decrypt secrets without host key"
fi

describe "declared secrets"
if [[ "$secret_keys" == "null" || "$secret_keys" == "[]" ]]; then
  info "age.secrets is empty (no secrets declared yet)"
  info "this is normal for a fresh install before secrets are added"
else
  # Count the secrets
  count=$(echo "$secret_keys" | jq_cmd 'length' 2>/dev/null || echo 0)
  pass "agenix has $count secret(s) declared"
  
  # Show the names for info
  names=$(echo "$secret_keys" | jq_cmd -r 'join(", ")' 2>/dev/null || true)
  if [[ -n "$names" ]]; then
    info "secret names: $names"
  fi
fi

describe "agenix activation script"
# Check that the agenix activation script runs during system activation
if [[ -d /run/current-system/activate ]]; then
  # Look for agenix in activation scripts
  if find /run/current-system/activate -type f -name '*.sh' 2>/dev/null | xargs grep -l agenix 2>/dev/null | grep -q .; then
    pass "agenix activation script present in system activation"
  else
    info "agenix activation script not found (may use different mechanism)"
  fi
else
  info "activation script directory not in expected location"
fi

describe "secret file paths (if secrets declared)"
# For each declared secret, check if the decrypted file exists
if [[ "$secret_keys" != "null" && "$secret_keys" != "[]" ]]; then
  # The actual secrets are mounted at runtime by agenix
  # Check /run/agenix.d or /run/agenix for the mounted secrets
  for secret_dir in /run/agenix.d /run/agenix /var/run/agenix; do
    if [[ -d "$secret_dir" ]]; then
      pass "agenix runtime directory exists: $secret_dir"
      count=$(find "$secret_dir" -type f 2>/dev/null | wc -l)
      info "$count secret file(s) in $secret_dir"
      break
    fi
  done
fi
