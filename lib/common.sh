#!/usr/bin/env bash
# vibe-install common library — logging, helpers, idempotency primitives.
# Sourced by install.sh and all lib/*.sh modules. Never executed directly.

set -u

# shellcheck disable=SC2034
VIBE_LOG_FILE="${VIBE_LOG_FILE:-$HOME/vibe-install.log}"

# ANSI colors for screen output (used by this file and consumed by downstream modules)
# shellcheck disable=SC2034
readonly C_RESET='\033[0m'
# shellcheck disable=SC2034
readonly C_DIM='\033[2m'
# shellcheck disable=SC2034
readonly C_GREEN='\033[32m'
# shellcheck disable=SC2034
readonly C_YELLOW='\033[33m'
# shellcheck disable=SC2034
readonly C_RED='\033[31m'
# shellcheck disable=SC2034
readonly C_CYAN='\033[36m'

_log() {
  local level="$1"; shift
  local module="$1"; shift
  local msg="$*"
  local ts
  ts="$(date '+%H:%M:%S')"
  printf '[%s] [%-5s] [%s] %s\n' "$ts" "$level" "$module" "$msg" >> "$VIBE_LOG_FILE"
}

log_info() { _log "INFO"  "$1" "${@:2}"; printf "${C_DIM}▶ [%s] %s${C_RESET}\n" "$1" "${*:2}"; }
log_ok()   { _log "OK"    "$1" "${@:2}"; printf "${C_GREEN}  ✓ %s${C_RESET}\n" "${*:2}"; }
log_warn() { _log "WARN"  "$1" "${@:2}"; printf "${C_YELLOW}  ⚠ %s${C_RESET}\n" "${*:2}"; }
log_fail() {
  _log "FAIL"  "$1" "${@:2}"
  printf "${C_RED}  ✗ %s${C_RESET}\n" "${*:2}" >&2
  return 1
}

# -- Idempotency helpers -------------------------------------------------------

check_installed() {
  command -v "$1" >/dev/null 2>&1
}

brew_install() {
  local formula="$1"
  local module="${2:-core}"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    log_info "$module" "$formula: already installed"
    return 0
  fi
  if [[ "${VIBE_DRY_RUN:-0}" == "1" ]]; then
    log_info "$module" "$formula: would install (dry-run)"
    return 0
  fi
  log_info "$module" "$formula: installing…"
  if brew install "$formula" >>"$VIBE_LOG_FILE" 2>&1; then
    log_ok "$module" "$formula: installed"
  else
    log_fail "$module" "$formula: install failed (see log)"
    return 1
  fi
}

brew_cask_install() {
  local cask="$1"
  local module="${2:-core}"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_info "$module" "$cask (cask): already installed"
    return 0
  fi
  if [[ "${VIBE_DRY_RUN:-0}" == "1" ]]; then
    log_info "$module" "$cask (cask): would install (dry-run)"
    return 0
  fi
  log_info "$module" "$cask (cask): installing…"
  if brew install --cask "$cask" >>"$VIBE_LOG_FILE" 2>&1; then
    log_ok "$module" "$cask (cask): installed"
  else
    log_fail "$module" "$cask (cask): install failed (see log)"
    return 1
  fi
}

# -- Template rendering --------------------------------------------------------

render_template() {
  local in_file="$1"
  local out_file="$2"
  shift 2
  local content
  content="$(cat "$in_file")"
  local pair key val
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    # Use bash string replacement instead of sed to avoid escaping regex chars
    content="${content//\{\{${key}\}\}/$val}"
  done
  printf '%s' "$content" > "$out_file"
}

# -- Run header ----------------------------------------------------------------

log_run_header() {
  {
    echo "==============================================================="
    printf ' Vibe Install run — %s — user: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$USER"
    echo "==============================================================="
  } >> "$VIBE_LOG_FILE"
}
