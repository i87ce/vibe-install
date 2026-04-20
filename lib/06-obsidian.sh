#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 06-obsidian.sh — Obsidian app + optional vault symlink to ~/.claude.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="06-obsidian"

run_obsidian() {
  local MOD="06-obsidian"
  [[ " $VIBE_SELECTED " == *" obsidian "* ]] || return 0

  brew_cask_install "obsidian" "$MOD"

  local vault="${VIBE_OBSIDIAN_VAULT:-}"
  if [[ -z "$vault" ]]; then
    log_info "$MOD" "vault symlink: skipped (no path provided)"
    return 0
  fi
  if [[ ! -d "$vault" ]]; then
    log_warn "$MOD" "vault path does not exist: $vault — skipping symlink"
    return 0
  fi

  local target="$vault/claude-global"
  if [[ -L "$target" ]]; then
    log_info "$MOD" "symlink $target: already present"
  elif [[ -e "$target" ]]; then
    log_warn "$MOD" "$target exists but is not a symlink — not overwriting"
  else
    # shellcheck disable=SC2015
    # shellcheck disable=SC2088
    ln -s "$HOME/.claude" "$target" \
      && log_ok "$MOD" "symlink created: $target -> ~/.claude"
  fi
}
