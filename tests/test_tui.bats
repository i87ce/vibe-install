#!/usr/bin/env bats

setup() {
  export VIBE_LOG_FILE="$(mktemp)"
  export VIBE_CONF_FILE="$(mktemp)"
  # shellcheck source=../lib/common.sh
  source "${BATS_TEST_DIRNAME}/../lib/common.sh"
  # shellcheck source=../lib/tui.sh
  source "${BATS_TEST_DIRNAME}/../lib/tui.sh"
}

teardown() {
  rm -f "$VIBE_LOG_FILE" "$VIBE_CONF_FILE"
}

@test "tui_save_config writes KEY=true for selected, KEY=false for unselected" {
  tui_save_config "$VIBE_CONF_FILE" "ohmyzsh tmux claude_cli"
  grep -q '^ohmyzsh=true$'   "$VIBE_CONF_FILE"
  grep -q '^tmux=true$'      "$VIBE_CONF_FILE"
  grep -q '^claude_cli=true$' "$VIBE_CONF_FILE"
  grep -q '^docker=false$'   "$VIBE_CONF_FILE"
}

@test "tui_load_config returns space-separated selected keys" {
  cat > "$VIBE_CONF_FILE" <<'EOF'
ohmyzsh=true
tmux=false
claude_cli=true
EOF
  run tui_load_config "$VIBE_CONF_FILE"
  [[ "$output" == *"ohmyzsh"* ]]
  [[ "$output" == *"claude_cli"* ]]
  [[ "$output" != *"tmux"* ]]
}
