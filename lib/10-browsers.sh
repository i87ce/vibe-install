#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 10-browsers.sh — Chrome + Postman.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="10-browsers"

run_browsers() {
  local MOD="10-browsers"
  local s="$VIBE_SELECTED"
  [[ " $s " == *" chrome "*  ]] && brew_cask_install google-chrome "$MOD"
  [[ " $s " == *" postman "* ]] && brew_cask_install postman "$MOD"
  return 0
}
