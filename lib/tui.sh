#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# tui.sh — dialog-based checklist, sub-prompts, config save/load.
# Guard against re-sourcing common.sh (readonly color vars would conflict).
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

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
  # --stdout: dialog writes selection to stdout (clean) instead of stderr (mixed with errors).
  # --separate-output: one tag per line.
  local args=(--stdout --separate-output --checklist "Select components to install" 30 78 22)
  local entry key section label default
  for entry in "${VIBE_CATALOG[@]}"; do
    IFS='|' read -r key section label default <<< "$entry"
    # Skip separator rows — dialog has no real separator support; grouping is done
    # via the [SECTION] prefix on each label instead.
    [[ "$key" == SEP_* ]] && continue
    args+=("$key" "[$section] $label" "$default")
  done

  local result
  if ! result="$(dialog --backtitle "vibe-install" --title "Vibe Install — DonTouch" "${args[@]}")"; then
    return 1
  fi
  # Normalize newline-separated tags → space-separated for the rest of the pipeline.
  printf '%s' "$result" | tr '\n' ' ' | sed 's/ *$//'
}

tui_save_config() {
  local out_file="$1"
  local selected="$2"   # space-separated keys
  local entry key
  : > "$out_file"
  for entry in "${VIBE_CATALOG[@]}"; do
    IFS='|' read -r key _rest <<< "$entry"
    [[ "$key" == SEP_* ]] && continue
    if [[ " $selected " == *" $key "* ]]; then
      printf '%s=true\n'  "$key" >> "$out_file"
    else
      printf '%s=false\n' "$key" >> "$out_file"
    fi
  done
}

tui_load_config() {
  local in_file="$1"
  local key val out=""
  while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    if [[ "$val" == "true" ]]; then
      out+="$key "
    fi
  done < "$in_file"
  printf '%s' "${out% }"
}

# tui_prompt_engine — radiolist between p10k and starship. Prints key.
tui_prompt_engine() {
  local tmp; tmp="$(mktemp)"
  dialog --backtitle "vibe-install" --title "Prompt engine" \
    --radiolist "Choose your zsh prompt:" 12 60 2 \
    p10k "Powerlevel10k (preconfigured)" on \
    starship "Starship" off 2>"$tmp"
  local choice; choice="$(cat "$tmp")"; rm -f "$tmp"
  printf '%s' "${choice:-p10k}"
}

# tui_ask_vertex — prints "PROJECT REGION"
tui_ask_vertex() {
  local tmp; tmp="$(mktemp)"
  dialog --backtitle "vibe-install" --title "Vertex AI" \
    --form "Vertex AI configuration" 10 60 2 \
      "Project ID:" 1 1 "ea-claw" 1 15 30 0 \
      "Region:"     2 1 "europe-west1" 2 15 30 0 \
    2>"$tmp"
  local project region
  project="$(sed -n '1p' "$tmp")"
  region="$(sed -n '2p' "$tmp")"
  rm -f "$tmp"
  printf '%s %s' "${project:-ea-claw}" "${region:-europe-west1}"
}

# tui_ask_obsidian_vault — prints vault path or empty
tui_ask_obsidian_vault() {
  local tmp; tmp="$(mktemp)"
  dialog --backtitle "vibe-install" --title "Obsidian vault" \
    --inputbox "Path of your Obsidian vault (leave empty to skip symlink):" 10 70 "" \
    2>"$tmp"
  local v; v="$(cat "$tmp")"; rm -f "$tmp"
  printf '%s' "$v"
}

tui_summary() {
  local selected="$1" prompt="$2" vproject="$3" vregion="$4" vault="$5"
  local count; count="$(wc -w <<< "$selected" | tr -d ' ')"
  local msg
  msg=$(cat <<EOF
About to install:
  • $count components selected
  • Prompt: $prompt
  • Vertex AI: $vproject / $vregion
  • Obsidian vault: ${vault:-<skipped>}

Estimated time: 20-30 minutes
Estimated disk usage: ~8 GB

Proceed?
EOF
)
  dialog --backtitle "vibe-install" --title "Confirm" --yesno "$msg" 16 70
}

# tui_run drives the whole interactive flow; exports VIBE_* vars for the orchestrator.
tui_run() {
  local selected
  selected="$(tui_select)" || return 1
  [[ -z "$selected" ]] && { log_fail "$MOD" "No components selected"; return 1; }

  local prompt vertex vault vproject vregion
  if [[ " $selected " == *" prompt "* ]]; then
    prompt="$(tui_prompt_engine)"
  else
    prompt="p10k"
  fi
  if [[ " $selected " == *" claude_vertex "* ]]; then
    vertex="$(tui_ask_vertex)"
    vproject="${vertex% *}"
    vregion="${vertex#* }"
  else
    vproject="ea-claw"; vregion="europe-west1"
  fi
  if [[ " $selected " == *" obsidian "* ]]; then
    vault="$(tui_ask_obsidian_vault)"
  else
    vault=""
  fi

  tui_summary "$selected" "$prompt" "$vproject" "$vregion" "$vault" || return 1

  export VIBE_SELECTED="$selected"
  export VIBE_PROMPT="$prompt"
  export VIBE_VERTEX_PROJECT="$vproject"
  export VIBE_VERTEX_REGION="$vregion"
  export VIBE_OBSIDIAN_VAULT="$vault"

  tui_save_config "$HOME/.vibe-install.conf" "$selected"
  clear
}
