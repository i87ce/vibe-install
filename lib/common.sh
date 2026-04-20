#!/usr/bin/env bash
# vibe-install common library — logging, helpers, idempotency primitives.
# Sourced by install.sh and all lib/*.sh modules. Never executed directly.

set -u

# shellcheck disable=SC2034
VIBE_LOG_FILE="${VIBE_LOG_FILE:-$HOME/vibe-install.log}"

# ANSI colors for screen output
readonly C_RESET='\033[0m'
readonly C_DIM='\033[2m'
readonly C_GREEN='\033[32m'
readonly C_YELLOW='\033[33m'
readonly C_RED='\033[31m'
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
