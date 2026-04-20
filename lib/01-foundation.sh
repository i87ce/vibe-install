#!/usr/bin/env bash
# 01-foundation.sh — installs Xcode CLT, Homebrew, Rosetta 2 (Apple Silicon).
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
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

install_homebrew() {
  if check_installed brew; then
    log_info "$MOD" "Homebrew: already installed ($(brew --version | head -n1))"
    return 0
  fi
  log_info "$MOD" "Homebrew: installing via official script…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    >>"$VIBE_LOG_FILE" 2>&1 || { log_fail "$MOD" "Homebrew install failed"; return 1; }

  # Post-install shell environment (Apple Silicon vs Intel)
  local brew_shellenv
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_shellenv="/opt/homebrew/bin/brew shellenv"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_shellenv="/usr/local/bin/brew shellenv"
  else
    log_fail "$MOD" "Homebrew installed but binary not found in expected paths"
    return 1
  fi
  eval "$($brew_shellenv)"

  log_ok "$MOD" "Homebrew: installed ($(brew --version | head -n1))"
}

install_rosetta() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    log_info "$MOD" "Rosetta 2: skipped (Intel Mac)"
    return 0
  fi
  if /usr/bin/pgrep -q oahd; then
    log_info "$MOD" "Rosetta 2: already installed"
    return 0
  fi
  log_info "$MOD" "Rosetta 2: installing…"
  # shellcheck disable=SC2015
  softwareupdate --install-rosetta --agree-to-license >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "Rosetta 2: installed" \
    || { log_fail "$MOD" "Rosetta 2: install failed"; return 1; }
}

run_foundation() {
  install_xcode_clt || return 1
  install_homebrew || return 1
  install_rosetta  || return 1
}
