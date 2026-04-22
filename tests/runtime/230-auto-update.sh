#!/usr/bin/env bash
# Runtime: auto-update timer state. Template-agnostic: only tests if the
# feature is enabled in the booted configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "auto-update feature detection"
autoupdate_enabled=$(config_value "myOS.autoUpdate.enable")
repo_path=$(config_value "myOS.autoUpdate.repoPath")

if [[ "$autoupdate_enabled" != "true" ]]; then
  skip "myOS.autoUpdate.enable = false (or null) — timer not expected"
  exit 0
fi

if [[ "$repo_path" == "null" || -z "$repo_path" ]]; then
  info "myOS.autoUpdate.enable = true but repoPath is null"
  info "timer should be absent (self-gated) — checking absence"
  if has_unit auto-update.timer; then
    warn "auto-update.timer exists despite null repoPath (should be gated)"
  else
    pass "auto-update.timer correctly absent when repoPath unresolved"
  fi
  exit 0
fi

describe "auto-update timer present when enabled + configured"
if has_unit auto-update.timer; then
  pass "auto-update.timer unit exists"
else
  fail "auto-update.timer missing (expected: present when enabled+configured)"
fi

describe "auto-update timer scheduling"
if unit_is_enabled auto-update.timer; then
  pass "auto-update.timer is enabled"
else
  warn "auto-update.timer is not enabled (may be disabled manually)"
fi

# Check the OnCalendar schedule from the unit file
schedule=$(systemctl cat auto-update.timer 2>/dev/null | grep -oP 'OnCalendar=\K[^\s]+' || true)
if [[ -n "$schedule" ]]; then
  pass "auto-update.timer OnCalendar = $schedule"
else
  info "auto-update.timer OnCalendar not visible in unit file"
fi

describe "auto-update service dependencies"
if has_unit auto-update.service; then
  pass "auto-update.service unit exists"
  # Check it has the right type (oneshot expected)
  type=$(systemctl cat auto-update.service 2>/dev/null | grep -oP 'Type=\K[^\s]+' || true)
  if [[ "$type" == "oneshot" ]]; then
    pass "auto-update.service Type = oneshot (correct)"
  else
    info "auto-update.service Type = ${type:-<not found>}"
  fi
else
  fail "auto-update.service missing (required by timer)"
fi

describe "auto-update script references correct repo path"
if has_unit auto-update.service; then
  script_content=$(systemctl cat auto-update.service 2>/dev/null || true)
  if [[ "$script_content" == *"$repo_path"* ]]; then
    pass "service script references configured repoPath"
  else
    info "service script content does not visibly contain repoPath"
    info "configured: $repo_path"
  fi
fi
