#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 03-shell.sh — oh-my-zsh + zsh plugins, tmux, prompt engine (p10k or starship).
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="03-shell"
# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_ohmyzsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_info "$MOD" "oh-my-zsh: already installed"
  else
    log_info "$MOD" "oh-my-zsh: installing (unattended)…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      >>"$VIBE_LOG_FILE" 2>&1 || { log_fail "$MOD" "oh-my-zsh install failed"; return 1; }
    log_ok "$MOD" "oh-my-zsh: installed"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  _clone_zsh_plugin() {
    local name="$1" url="$2" dest="$custom/plugins/$1"
    if [[ -d "$dest" ]]; then
      log_info "$MOD" "zsh plugin $name: already present"
    else
      # shellcheck disable=SC2015
      git clone --depth 1 "$url" "$dest" >>"$VIBE_LOG_FILE" 2>&1 \
        && log_ok "$MOD" "zsh plugin $name: cloned" \
        || log_fail "$MOD" "zsh plugin $name: clone failed"
    fi
  }

  _clone_zsh_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
  _clone_zsh_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
}
