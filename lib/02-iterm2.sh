#!/usr/bin/env bash
# 02-iterm2.sh — installs iTerm2, Nerd font, and imports shared profile.
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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
    # shellcheck disable=SC2155
    local backup="$target.bak.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    log_warn "$MOD" "Existing dynamic profile backed up to $(basename "$backup")"
  fi

  # Wrap the single-profile JSON dump into iTerm2's dynamic profile envelope
  jq -n --slurpfile prof "$SCRIPT_DIR/templates/iterm2-profile.json" \
    '{Profiles: [ $prof[0] + {"Guid": "vibe-install-default", "Dynamic Profile Parent Name": ""} ]}' \
    > "$target"
  log_ok "$MOD" "iTerm2 dynamic profile installed to ~/Library/Application Support/iTerm2/DynamicProfiles/"
}

run_iterm2() {
  install_iterm2_app || return 1
  install_meslo_nerd_font || return 1
  import_iterm2_profile || return 1
}
