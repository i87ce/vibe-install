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

# Mempalace MCP requires a dedicated venv because Homebrew Python's pyexpat is
# broken on recent macOS (libexpat symbol mismatch). uv downloads a standalone
# CPython that carries its own libexpat, side-stepping the issue entirely.
MEMPALACE_VENV="$HOME/.local/share/mempalace/venv"

install_mempalace_mcp() {
  if ! check_installed uv; then
    log_warn "$MOD" "mempalace: uv not found — skipping (enable rt_python)"
    return 0
  fi
  if ! check_installed claude; then
    log_warn "$MOD" "mempalace: claude CLI not found — skipping"
    return 0
  fi

  if [[ -x "$MEMPALACE_VENV/bin/python3" ]] \
     && "$MEMPALACE_VENV/bin/python3" -c "import mempalace" 2>/dev/null; then
    log_info "$MOD" "mempalace venv: already set up"
  else
    log_info "$MOD" "mempalace: creating dedicated venv…"
    mkdir -p "$(dirname "$MEMPALACE_VENV")"
    uv venv "$MEMPALACE_VENV" --python 3.13 >>"$VIBE_LOG_FILE" 2>&1 \
      || { log_fail "$MOD" "mempalace: venv creation failed"; return 1; }
    # shellcheck disable=SC1091
    source "$MEMPALACE_VENV/bin/activate"
    uv pip install mempalace >>"$VIBE_LOG_FILE" 2>&1 \
      || { log_fail "$MOD" "mempalace: pip install failed"; return 1; }
    deactivate 2>/dev/null || true
    log_ok "$MOD" "mempalace: venv ready at $MEMPALACE_VENV"
  fi

  local current_cmd
  current_cmd="$(claude mcp list 2>/dev/null | grep '^mempalace:' || true)"
  local expected="$MEMPALACE_VENV/bin/python3 -m mempalace.mcp_server"
  if [[ "$current_cmd" == *"$expected"* ]]; then
    log_info "$MOD" "mempalace MCP: already registered with venv python"
    return 0
  fi
  claude mcp remove mempalace >>"$VIBE_LOG_FILE" 2>&1 || true
  claude mcp add mempalace -- "$MEMPALACE_VENV/bin/python3" -m mempalace.mcp_server \
    >>"$VIBE_LOG_FILE" 2>&1 \
    || { log_fail "$MOD" "mempalace: MCP registration failed"; return 1; }
  log_ok "$MOD" "mempalace MCP: registered ($expected)"
}

run_claude() {
  local MOD="05-claude"
  local selected="$VIBE_SELECTED"

  [[ " $selected " == *" claude_cli "* ]]          && install_claude_cli
  [[ " $selected " == *" claude_settings "* ]]     && merge_claude_settings \
                                                     "$SCRIPT_DIR/templates/claude-settings.json.template" \
                                                     "$HOME/.claude/settings.json"
  # Plugins + marketplaces are written inside the settings template, so claude_marketplaces
  # and claude_plugins are effectively satisfied by claude_settings. We keep them as flags
  # so doctor can verify, but no separate install step needed.
  [[ " $selected " == *" claude_plugins "* ]]      && install_mempalace_mcp
  [[ " $selected " == *" claude_statusline "* ]]   && install_statusline
  [[ " $selected " == *" claude_teams "* ]]        && enable_agent_teams
  [[ " $selected " == *" claude_vertex "* ]]       && vertex_login

  return 0
}
