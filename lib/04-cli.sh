#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 04-cli.sh — core CLI utilities via Homebrew.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="04-cli"

run_cli() {
  local MOD="04-cli"
  local selected="$VIBE_SELECTED"

  if [[ " $selected " == *" cli_git "* ]]; then
    brew_install git      "$MOD"
    brew_install gh       "$MOD"
    brew_install git-lfs  "$MOD"
  fi

  if [[ " $selected " == *" cli_tools "* ]]; then
    for f in jq yq fzf ripgrep bat eza fd tree htop; do
      brew_install "$f" "$MOD"
    done
    # post-install for fzf keybindings
    if check_installed fzf; then
      "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash \
        >>"$VIBE_LOG_FILE" 2>&1 || log_warn "$MOD" "fzf post-install had warnings"
    fi
    # zoxide is a separate brew
    brew_install zoxide "$MOD"
  fi

  if [[ " $selected " == *" cli_net "* ]]; then
    for f in wget curl watch tldr mkcert; do
      brew_install "$f" "$MOD"
    done
    tldr --update >>"$VIBE_LOG_FILE" 2>&1 || true
  fi
}
