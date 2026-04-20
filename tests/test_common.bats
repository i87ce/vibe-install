#!/usr/bin/env bats

setup() {
  export VIBE_LOG_FILE="$(mktemp)"
  # shellcheck source=../lib/common.sh
  source "${BATS_TEST_DIRNAME}/../lib/common.sh"
}

teardown() {
  rm -f "$VIBE_LOG_FILE"
}

@test "log_info writes timestamped INFO line to log file" {
  log_info "test-mod" "hello world"
  run cat "$VIBE_LOG_FILE"
  [[ "$output" =~ \[INFO[[:space:]]\][[:space:]]\[test-mod\][[:space:]]hello\ world ]]
}

@test "log_ok writes OK level line" {
  log_ok "test-mod" "done"
  run grep -c "\[OK" "$VIBE_LOG_FILE"
  [[ "$output" == "1" ]]
}

@test "log_fail writes FAIL level line and returns non-zero" {
  run log_fail "test-mod" "broken"
  [[ "$status" -ne 0 ]]
  grep -q "\[FAIL" "$VIBE_LOG_FILE"
}

@test "log_warn writes WARN level line" {
  log_warn "test-mod" "careful"
  grep -q "\[WARN" "$VIBE_LOG_FILE"
}
