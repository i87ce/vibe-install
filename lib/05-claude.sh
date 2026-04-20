#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 05-claude.sh — Claude Code CLI, settings.json merge, statusline, Agent Teams.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="05-claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_claude_cli() {
  if check_installed claude; then
    log_info "$MOD" "claude CLI: already installed ($(claude --version 2>/dev/null || echo unknown))"
    return 0
  fi
  # Depends on node/npm — Phase 8 runtimes installs nvm, but claude needs node available now.
  if ! check_installed node; then
    log_info "$MOD" "node not found — installing via brew to bootstrap claude CLI"
    brew_install node "$MOD"
  fi
  log_info "$MOD" "Installing @anthropic-ai/claude-code globally…"
  # shellcheck disable=SC2015
  npm install -g @anthropic-ai/claude-code >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "claude CLI: installed ($(claude --version))" \
    || { log_fail "$MOD" "claude CLI install failed"; return 1; }
}

vertex_login() {
  if ! check_installed gcloud; then
    log_warn "$MOD" "gcloud SDK not yet installed — skipping auth, run again after cloud module"
    return 0
  fi
  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    log_info "$MOD" "Vertex AI: application-default credentials already present"
    return 0
  fi
  log_info "$MOD" "Launching 'gcloud auth application-default login' (opens browser)…"
  # shellcheck disable=SC2015
  gcloud auth application-default login \
    && log_ok "$MOD" "Vertex AI: logged in" \
    || { log_fail "$MOD" "gcloud auth failed"; return 1; }
}

# jq-based deep merge: user settings override template for scalars; objects are unioned.
merge_claude_settings() {
  local template="$1" target="$2"
  local rendered tmp
  rendered="$(mktemp)"
  render_template "$template" "$rendered" \
    "VERTEX_PROJECT=${VIBE_VERTEX_PROJECT:-ea-claw}" \
    "VERTEX_REGION=${VIBE_VERTEX_REGION:-europe-west1}" \
    "HOME=$HOME"

  mkdir -p "$(dirname "$target")"

  if [[ ! -f "$target" ]]; then
    mv "$rendered" "$target"
    # shellcheck disable=SC2088
    log_ok "$MOD" "~/.claude/settings.json: created from template"
    return 0
  fi

  tmp="$(mktemp)"
  # `*` is jq's recursive merge. Right side wins for scalars; objects are deep-merged.
  # shellcheck disable=SC2015,SC2088
  jq -s '.[0] * .[1]' "$target" "$rendered" > "$tmp" \
    && mv "$tmp" "$target" \
    && log_ok "$MOD" "~/.claude/settings.json: merged with template (preserved user keys)" \
    || { log_fail "$MOD" "settings.json merge failed"; rm -f "$tmp" "$rendered"; return 1; }
  rm -f "$rendered"
}

install_statusline() {
  mkdir -p "$HOME/.claude"
  cp "$SCRIPT_DIR/templates/claude-statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"
  # shellcheck disable=SC2088
  log_ok "$MOD" "~/.claude/statusline.sh: installed"
}

enable_agent_teams() {
  # teammateMode belongs in ~/.claude.json, not settings.json
  local f="$HOME/.claude.json"
  if [[ ! -f "$f" ]]; then
    echo '{"teammateMode":"tmux"}' > "$f"
    # shellcheck disable=SC2088
    log_ok "$MOD" "~/.claude.json: created with teammateMode=tmux"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2015,SC2088
  jq '.teammateMode = "tmux"' "$f" > "$tmp" \
    && mv "$tmp" "$f" \
    && log_ok "$MOD" "~/.claude.json: teammateMode set to tmux" \
    || { log_fail "$MOD" "patch ~/.claude.json failed"; rm -f "$tmp"; return 1; }
}

run_claude() {
  local selected="$VIBE_SELECTED"

  [[ " $selected " == *" claude_cli "* ]]          && install_claude_cli
  [[ " $selected " == *" claude_settings "* ]]     && merge_claude_settings \
                                                     "$SCRIPT_DIR/templates/claude-settings.json.template" \
                                                     "$HOME/.claude/settings.json"
  # Plugins + marketplaces are written inside the settings template, so claude_marketplaces
  # and claude_plugins are effectively satisfied by claude_settings. We keep them as flags
  # so doctor can verify, but no separate install step needed.
  [[ " $selected " == *" claude_statusline "* ]]   && install_statusline
  [[ " $selected " == *" claude_teams "* ]]        && enable_agent_teams
  [[ " $selected " == *" claude_vertex "* ]]       && vertex_login

  return 0
}
