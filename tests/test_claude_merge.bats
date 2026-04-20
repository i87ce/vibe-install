#!/usr/bin/env bats

setup() {
  export VIBE_LOG_FILE="$(mktemp)"
  # shellcheck source=../lib/common.sh
  source "${BATS_TEST_DIRNAME}/../lib/common.sh"
  # shellcheck source=../lib/05-claude.sh
  source "${BATS_TEST_DIRNAME}/../lib/05-claude.sh"
  export FAKE_HOME="$(mktemp -d)"
  export FAKE_TEMPLATE="$(mktemp)"
  cat > "$FAKE_TEMPLATE" <<'EOF'
{"env":{"A":"1"},"enabledPlugins":{"p1":true},"extraKnownMarketplaces":{"m1":{"x":1}}}
EOF
}

teardown() {
  rm -rf "$FAKE_HOME" "$FAKE_TEMPLATE" "$VIBE_LOG_FILE"
}

@test "merge_claude_settings creates file when missing" {
  merge_claude_settings "$FAKE_TEMPLATE" "$FAKE_HOME/settings.json"
  [[ -f "$FAKE_HOME/settings.json" ]]
  run jq -r '.env.A' "$FAKE_HOME/settings.json"
  [[ "$output" == "1" ]]
}

@test "merge_claude_settings preserves user keys not in template" {
  echo '{"env":{"USER_KEY":"kept"}, "customUserField": 42}' > "$FAKE_HOME/settings.json"
  merge_claude_settings "$FAKE_TEMPLATE" "$FAKE_HOME/settings.json"
  run jq -r '.env.USER_KEY' "$FAKE_HOME/settings.json"
  [[ "$output" == "kept" ]]
  run jq -r '.customUserField' "$FAKE_HOME/settings.json"
  [[ "$output" == "42" ]]
  run jq -r '.env.A' "$FAKE_HOME/settings.json"
  [[ "$output" == "1" ]]
}

@test "merge_claude_settings unions enabledPlugins" {
  echo '{"enabledPlugins":{"user_plugin":true}}' > "$FAKE_HOME/settings.json"
  merge_claude_settings "$FAKE_TEMPLATE" "$FAKE_HOME/settings.json"
  run jq -r '.enabledPlugins.user_plugin' "$FAKE_HOME/settings.json"
  [[ "$output" == "true" ]]
  run jq -r '.enabledPlugins.p1' "$FAKE_HOME/settings.json"
  [[ "$output" == "true" ]]
}
