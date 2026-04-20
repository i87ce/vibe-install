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

@test "check_installed returns 0 when command exists" {
  run check_installed "bash"
  [[ "$status" -eq 0 ]]
}

@test "check_installed returns 1 when command is missing" {
  run check_installed "definitely_not_a_command_xyzzy"
  [[ "$status" -eq 1 ]]
}

@test "brew_install is a no-op when formula already installed" {
  # Mock: pretend `brew list` says 'jq' exists
  brew() {
    if [[ "$1" == "list" && "$2" == "--formula" && "$3" == "jq" ]]; then
      return 0
    fi
    echo "brew called with unexpected args: $*" >&2
    return 99
  }
  export -f brew
  run brew_install "jq"
  [[ "$status" -eq 0 ]]
  grep -q "jq: already installed" "$VIBE_LOG_FILE"
}

@test "render_template substitutes {{KEY}} placeholders" {
  local tmp_in tmp_out
  tmp_in="$(mktemp)"
  tmp_out="$(mktemp)"
  echo 'project={{VERTEX_PROJECT}} region={{VERTEX_REGION}} home={{HOME}}' > "$tmp_in"
  render_template "$tmp_in" "$tmp_out" \
    "VERTEX_PROJECT=ea-claw" \
    "VERTEX_REGION=europe-west1" \
    "HOME=/Users/alice"
  run cat "$tmp_out"
  [[ "$output" == "project=ea-claw region=europe-west1 home=/Users/alice" ]]
  rm -f "$tmp_in" "$tmp_out"
}

@test "log_run_header writes delimited block" {
  log_run_header
  run grep -c "^===" "$VIBE_LOG_FILE"
  [[ "$output" -ge "2" ]]
}
