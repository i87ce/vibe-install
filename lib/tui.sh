#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# tui.sh — dialog-based checklist, sub-prompts, config save/load.
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# shellcheck disable=SC2034
MOD="tui"

# Catalog: lines of "KEY|SECTION|LABEL|DEFAULT(on|off)"
# Order here drives display order.
# shellcheck disable=SC2034
VIBE_CATALOG=(
  "SEP_SHELL|SHELL|--- TERMINAL & SHELL ---|off"
  "ohmyzsh|SHELL|oh-my-zsh + plugins (git, autosugg, syntax-hl, z)|on"
  "tmux|SHELL|tmux|on"
  "prompt|SHELL|prompt (p10k or starship — chosen later)|on"
  "zshrc|SHELL|.zshrc opinionated modules|on"

  "SEP_CLI|CLI|--- CORE CLI ---|off"
  "cli_git|CLI|git, gh, git-lfs|on"
  "cli_tools|CLI|jq, yq, fzf, ripgrep, bat, eza, fd, tree, htop|on"
  "cli_net|CLI|wget, curl, watch, tldr, mkcert|on"

  "SEP_CLAUDE|CLAUDE|--- CLAUDE CODE & AI ---|off"
  "claude_cli|CLAUDE|Claude Code CLI|on"
  "claude_vertex|CLAUDE|Vertex AI login (project: ea-claw)|on"
  "claude_settings|CLAUDE|settings.json template|on"
  "claude_marketplaces|CLAUDE|Marketplaces (3)|on"
  "claude_plugins|CLAUDE|Plugins (14)|on"
  "claude_statusline|CLAUDE|Statusline|on"
  "claude_teams|CLAUDE|Agent Teams (tmux teammateMode)|on"

  "SEP_EDITOR|EDITOR|--- EDITOR ---|off"
  "obsidian|EDITOR|Obsidian + optional vault symlink|on"

  "SEP_RT|RT|--- DEV RUNTIMES ---|off"
  "rt_node|RT|Node.js via nvm (+pnpm, yarn)|on"
  "rt_python|RT|Python via uv|on"
  "rt_go|RT|Go|on"
  "rt_rust|RT|Rust (rustup)|on"
  "rt_ruby|RT|Ruby (rbenv)|on"
  "rt_java|RT|Java (sdkman)|on"
  "rt_bun|RT|Bun|on"

  "SEP_CNT|CNT|--- CONTAINERS & INFRA ---|off"
  "docker|CNT|Docker Desktop|on"
  "terraform|CNT|Terraform|on"
  "ansible|CNT|Ansible|on"

  "SEP_CLOUD|CLOUD|--- CLOUD & OPS ---|off"
  "gcloud|CLOUD|gcloud SDK (+ beta, gke-gcloud-auth)|on"
  "azure|CLOUD|Azure CLI|on"
  "wrangler|CLOUD|Cloudflare Wrangler|on"
  "m365|CLOUD|Microsoft 365 CLI|on"
  "pwsh|CLOUD|PowerShell 7 + Microsoft.Graph module|on"

  "SEP_BROW|BROW|--- BROWSERS & DEBUG ---|off"
  "chrome|BROW|Google Chrome|on"
  "postman|BROW|Postman|on"

  "SEP_DB|DB|--- DATABASE TOOLS ---|off"
  "db_clients|DB|psql, mysql-client, redis-cli, sqlite|on"
)

# Returns space-separated list of selected keys on stdout; exit 1 if cancelled.
tui_select() {
  local args=(--separate-output --checklist "Select components to install" 30 78 22)
  local entry key label default
  for entry in "${VIBE_CATALOG[@]}"; do
    IFS='|' read -r key _section label default <<< "$entry"
    if [[ "$key" == SEP_* ]]; then
      # Separator: non-selectable, just visual. dialog lacks native separators —
      # render as an unchecked, disabled-looking row by prefixing with spaces.
      args+=("$key" "$label" "off")
    else
      args+=("$key" "$label" "$default")
    fi
  done

  local tmp
  tmp="$(mktemp)"
  if ! dialog --backtitle "vibe-install" --title "Vibe Install — DonTouch" \
       "${args[@]}" 2>"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  local result
  result="$(cat "$tmp")"
  rm -f "$tmp"
  # Strip separator lines
  grep -v '^SEP_' <<< "$result" || true
}
