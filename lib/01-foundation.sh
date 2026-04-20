#!/usr/bin/env bash
# 01-foundation.sh — installs Xcode CLT, Homebrew, Rosetta 2 (Apple Silicon).
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MOD="01-foundation"

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log_info "$MOD" "Xcode CLT: already installed ($(xcode-select -p))"
    return 0
  fi
  log_info "$MOD" "Xcode CLT: triggering install (this opens a GUI prompt)…"
  # Trigger install via softwareupdate for non-interactive fallback
  local placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  touch "$placeholder"
  local label
  label="$(softwareupdate -l 2>/dev/null \
    | grep -E '\*\s*(Command Line|Label: Command Line).*' \
    | tail -n1 | sed -e 's/^[^:]*: //' -e 's/^ *//' -e 's/^\* //')"
  if [[ -n "$label" ]]; then
    sudo softwareupdate -i "$label" --verbose
  else
    # Fallback: GUI flow
    xcode-select --install || true
    log_warn "$MOD" "GUI install triggered — follow the macOS prompt, then rerun this script."
    rm -f "$placeholder"
    return 1
  fi
  rm -f "$placeholder"
  if xcode-select -p >/dev/null 2>&1; then
    log_ok "$MOD" "Xcode CLT: installed"
  else
    log_fail "$MOD" "Xcode CLT: install did not complete"
    return 1
  fi
}
