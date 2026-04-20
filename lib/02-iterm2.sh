#!/usr/bin/env bash
# 02-iterm2.sh — installs iTerm2, Nerd font, and imports shared profile.
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="02-iterm2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_iterm2_app() {
  brew_cask_install "iterm2" "$MOD"
}

install_meslo_nerd_font() {
  if brew list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
    log_info "$MOD" "MesloLG Nerd Font: already installed"
    return 0
  fi
  log_info "$MOD" "MesloLG Nerd Font: tapping homebrew/cask-fonts and installing…"
  brew tap homebrew/cask-fonts >>"$VIBE_LOG_FILE" 2>&1 || true
  brew_cask_install "font-meslo-lg-nerd-font" "$MOD"
}

import_iterm2_profile() {
  local prefs_root="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$prefs_root"
  local target="$prefs_root/vibe-install.json"

  if [[ -f "$target" ]]; then
    local backup_dir="$HOME/.vibe-install/backups"
    mkdir -p "$backup_dir"
    # shellcheck disable=SC2155
    local backup="$backup_dir/iterm2-dynamic-profile.$(date +%Y%m%d%H%M%S).json"
    # mv (not cp) so no stray *.bak file remains inside DynamicProfiles/ — iTerm2
    # scans every file there and would complain about duplicate GUIDs.
    mv "$target" "$backup"
    log_warn "$MOD" "Existing dynamic profile moved to $backup"
  fi

  # Wrap the single-profile JSON dump into iTerm2's dynamic profile envelope.
  # Intentionally DO NOT set "Dynamic Profile Parent Name" — iTerm2 treats an empty
  # string as "unknown parent" and emits a warning. Omitting the key = "no parent".
  jq -n --slurpfile prof "$SCRIPT_DIR/templates/iterm2-profile.json" \
    '{Profiles: [ ($prof[0] | del(."Dynamic Profile Parent Name")) + {"Guid": "vibe-install-default", "Name": "vibe-install"} ]}' \
    > "$target"
  log_ok "$MOD" "iTerm2 dynamic profile installed to ~/Library/Application Support/iTerm2/DynamicProfiles/"
}

run_iterm2() {
  install_iterm2_app || return 1
  install_meslo_nerd_font || return 1
  import_iterm2_profile || return 1
}
