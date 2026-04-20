#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 99-doctor.sh — post-install verification.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="99-doctor"

# shellcheck disable=SC2034
DOCTOR_OK=0
# shellcheck disable=SC2034
DOCTOR_MISS=0
# shellcheck disable=SC2034
DOCTOR_SKIP=0

_check() {
  local label="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "  ${C_GREEN}✓${C_RESET} %s\n" "$label"
    DOCTOR_OK=$((DOCTOR_OK + 1))
  else
    printf "  ${C_RED}✗${C_RESET} %s  ${C_DIM}NOT FOUND${C_RESET}\n" "$label"
    DOCTOR_MISS=$((DOCTOR_MISS + 1))
  fi
}

_skip() {
  local label="$1"
  printf "  ${C_DIM}?${C_RESET} %s  ${C_DIM}SKIPPED${C_RESET}\n" "$label"
  DOCTOR_SKIP=$((DOCTOR_SKIP + 1))
}

doctor_run() {
  # doctor_run uses _check/_skip (not log_*), so it doesn't read MOD — the
  # top-level `MOD="99-doctor"` in this file is kept for anyone who extends it.
  printf "\n${C_CYAN}%s${C_RESET}\n" "Vibe Install — Doctor Report"
  echo "─────────────────────────────────────────────"

  # Foundation
  _check "Xcode CLT"              "xcode-select -p"
  _check "Homebrew"               "brew --version"
  if [[ "$(uname -m)" == "arm64" ]]; then
    _check "Rosetta 2"             "/usr/bin/pgrep oahd"
  else
    _skip  "Rosetta 2 (Intel)"
  fi

  # iTerm2
  _check "iTerm2"                 "test -d /Applications/iTerm.app"
  _check "MesloLG Nerd Font"      "brew list --cask font-meslo-lg-nerd-font"

  # Shell
  _check "oh-my-zsh"              "test -d $HOME/.oh-my-zsh"
  _check "powerlevel10k theme"    "test -d $HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  _check "tmux"                   "command -v tmux"

  # CLI
  for t in git gh git-lfs jq yq fzf rg bat eza fd tree htop wget curl watch tldr mkcert zoxide; do
    _check "$t" "command -v $t"
  done

  # Claude
  _check "claude CLI"             "command -v claude"
  # shellcheck disable=SC2088
  _check "~/.claude/settings.json"   "test -f $HOME/.claude/settings.json"
  _check "statusline.sh"          "test -x $HOME/.claude/statusline.sh"
  # shellcheck disable=SC2088
  _check "~/.claude.json teammateMode" \
    "jq -e '.teammateMode == \"tmux\"' $HOME/.claude.json"

  # Runtimes
  _check "Node.js (via nvm)"      "test -s $HOME/.nvm/nvm.sh"
  _check "pnpm"                   "command -v pnpm"
  _check "yarn"                   "command -v yarn"
  _check "uv"                     "command -v uv"
  _check "Go"                     "command -v go"
  _check "Rust (rustup)"          "command -v rustup"
  _check "rbenv"                  "command -v rbenv"
  _check "SDKMAN"                 "test -s $HOME/.sdkman/bin/sdkman-init.sh"
  _check "Bun"                    "command -v bun"

  # Containers
  _check "Docker Desktop"         "test -d /Applications/Docker.app"
  _check "Terraform"              "command -v terraform"
  _check "Ansible"                "command -v ansible"

  # Cloud
  _check "gcloud"                 "command -v gcloud"
  _check "gke-gcloud-auth-plugin" "command -v gke-gcloud-auth-plugin"
  _check "Azure CLI"              "command -v az"
  _check "wrangler"               "command -v wrangler"
  _check "m365"                   "command -v m365"
  _check "PowerShell 7"           "command -v pwsh"

  # Browsers
  _check "Chrome"                 "test -d /Applications/Google\\ Chrome.app"
  _check "Postman"                "test -d /Applications/Postman.app"

  # DB
  _check "psql"                   "command -v psql"
  _check "mysql (client)"         "command -v mysql"
  _check "redis-cli"              "command -v redis-cli"
  _check "sqlite"                 "command -v sqlite3"

  echo "─────────────────────────────────────────────"
  printf "Summary: %s%d OK%s · %s%d missing%s · %d skipped\n" \
    "$C_GREEN" "$DOCTOR_OK" "$C_RESET" \
    "$C_RED" "$DOCTOR_MISS" "$C_RESET" \
    "$DOCTOR_SKIP"

  # shellcheck disable=SC2015
  (( DOCTOR_MISS > 0 )) && return 1 || return 0
}
