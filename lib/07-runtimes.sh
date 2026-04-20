#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 07-runtimes.sh — dev language runtimes and version managers.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="07-runtimes"

install_nvm_and_node() {
  if [[ ! -d "$HOME/.nvm" ]]; then
    log_info "$MOD" "nvm: installing via official script…"
    # shellcheck disable=SC2015
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
      >>"$VIBE_LOG_FILE" 2>&1 || { log_fail "$MOD" "nvm install failed"; return 1; }
    log_ok "$MOD" "nvm: installed"
  else
    log_info "$MOD" "nvm: already installed"
  fi
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
  if ! nvm ls --no-alias default >/dev/null 2>&1; then
    nvm install --lts >>"$VIBE_LOG_FILE" 2>&1 && nvm alias default 'lts/*'
    log_ok "$MOD" "Node.js LTS: installed via nvm"
  else
    log_info "$MOD" "Node.js: already present (via nvm)"
  fi
  # shellcheck disable=SC2015
  npm install -g pnpm yarn >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "pnpm + yarn: installed globally"
}

install_uv() {
  if check_installed uv; then
    log_info "$MOD" "uv: already installed"
    return 0
  fi
  brew_install uv "$MOD"
}

install_go()     { brew_install go "$MOD"; }

install_rust() {
  if check_installed rustup; then
    log_info "$MOD" "rustup: already installed"
    return 0
  fi
  # shellcheck disable=SC2015
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "rustup: installed" \
    || log_fail "$MOD" "rustup install failed"
}

install_ruby_rbenv() {
  brew_install rbenv "$MOD"
  brew_install ruby-build "$MOD"
}

install_sdkman_java() {
  local init="$HOME/.sdkman/bin/sdkman-init.sh"
  if [[ -s "$init" ]]; then
    log_info "$MOD" "sdkman: already installed"
  else
    # If ~/.sdkman exists but init script is missing, sdkman is partially installed.
    [[ -d "$HOME/.sdkman" ]] && log_warn "$MOD" "sdkman dir exists but init script missing — re-running installer"
    # shellcheck disable=SC2015
    curl -s "https://get.sdkman.io" | bash >>"$VIBE_LOG_FILE" 2>&1 \
      && log_ok "$MOD" "sdkman: installed"
  fi
  if [[ ! -s "$init" ]]; then
    log_fail "$MOD" "sdkman: init script still missing after install — skipping Java"
    return 1
  fi
  # shellcheck disable=SC1090,SC1091
  source "$init"
  sdk install java 21-tem >>"$VIBE_LOG_FILE" 2>&1 || true
}

install_bun() {
  if check_installed bun; then
    log_info "$MOD" "bun: already installed"
    return 0
  fi
  brew_install oven-sh/bun/bun "$MOD"
}

run_runtimes() {
  local MOD="07-runtimes"
  local s="$VIBE_SELECTED"
  [[ " $s " == *" rt_node "*   ]] && install_nvm_and_node
  [[ " $s " == *" rt_python "* ]] && install_uv
  [[ " $s " == *" rt_go "*     ]] && install_go
  [[ " $s " == *" rt_rust "*   ]] && install_rust
  [[ " $s " == *" rt_ruby "*   ]] && install_ruby_rbenv
  [[ " $s " == *" rt_java "*   ]] && install_sdkman_java
  [[ " $s " == *" rt_bun "*    ]] && install_bun
  return 0
}
