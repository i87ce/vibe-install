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

install_tmux() {
  brew_install tmux "$MOD"
}

install_p10k() {
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local dest="$custom/themes/powerlevel10k"
  if [[ -d "$dest" ]]; then
    log_info "$MOD" "powerlevel10k: already cloned"
  else
    git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$dest" >>"$VIBE_LOG_FILE" 2>&1 \
      || { log_fail "$MOD" "powerlevel10k clone failed"; return 1; }
    log_ok "$MOD" "powerlevel10k: cloned"
  fi
  cp "$SCRIPT_DIR/templates/p10k.zsh" "$HOME/.p10k.zsh"
  # shellcheck disable=SC2088
  log_ok "$MOD" "~/.p10k.zsh: written from template"
}

install_starship() {
  brew_install starship "$MOD"
  mkdir -p "$HOME/.config"
  cp "$SCRIPT_DIR/templates/starship.toml" "$HOME/.config/starship.toml"
  # shellcheck disable=SC2088
  log_ok "$MOD" "~/.config/starship.toml: written"
}

configure_prompt() {
  local choice="$1"   # "p10k" or "starship"
  case "$choice" in
    p10k)     install_p10k ;;
    starship)
      install_starship
      # Toggle the .zshrc lines: comment p10k sourcing, uncomment starship eval
      if [[ -f "$HOME/.zshrc" ]]; then
        # shellcheck disable=SC2016
        sed -i.bak -E \
          -e 's|^\[\[ ! -f ~/\.p10k\.zsh \]\] \|\| source ~/\.p10k\.zsh$|# & (disabled by vibe-install — using starship)|' \
          -e 's|^# eval "\$\(starship init zsh\)".*$|eval "$(starship init zsh)"|' \
          "$HOME/.zshrc"
        log_ok "$MOD" ".zshrc: toggled to starship"
      fi
      ;;
    *) log_warn "$MOD" "Unknown prompt choice: $choice" ;;
  esac
}

install_zshrc() {
  local vproject="${VIBE_VERTEX_PROJECT:-ea-claw}"
  local vregion="${VIBE_VERTEX_REGION:-europe-west1}"

  # Backup existing .zshrc if present
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    local bak
    bak="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
    cp "$HOME/.zshrc" "$bak"
    log_warn "$MOD" "Existing ~/.zshrc backed up to $(basename "$bak")"
  fi

  cp "$SCRIPT_DIR/templates/zshrc.template" "$HOME/.zshrc"

  mkdir -p "$HOME/.config/vibe"
  cp "$SCRIPT_DIR/templates/zshrc.d/10-path.zsh"   "$HOME/.config/vibe/10-path.zsh"
  render_template \
    "$SCRIPT_DIR/templates/zshrc.d/20-tools.zsh" \
    "$HOME/.config/vibe/20-tools.zsh" \
    "VERTEX_PROJECT=$vproject" \
    "VERTEX_REGION=$vregion"
  cp "$SCRIPT_DIR/templates/zshrc.d/30-aliases.zsh" "$HOME/.config/vibe/30-aliases.zsh"

  # Write .zshrc.local only if missing (never overwrite)
  if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cp "$SCRIPT_DIR/templates/zshrc.local.template" "$HOME/.zshrc.local"
    # shellcheck disable=SC2088
    log_ok "$MOD" "~/.zshrc.local: written (empty template)"
  else
    # shellcheck disable=SC2088
    log_info "$MOD" "~/.zshrc.local: preserved"
  fi

  # shellcheck disable=SC2088
  log_ok "$MOD" "zshrc + ~/.config/vibe/*.zsh: installed"
}

run_shell() {
  local MOD="03-shell"
  local selected="$VIBE_SELECTED"

  [[ " $selected " == *" ohmyzsh "* ]] && install_ohmyzsh
  [[ " $selected " == *" tmux "* ]]    && install_tmux
  [[ " $selected " == *" prompt "* ]]  && configure_prompt "${VIBE_PROMPT:-p10k}"
  [[ " $selected " == *" zshrc "* ]]   && install_zshrc

  return 0
}
