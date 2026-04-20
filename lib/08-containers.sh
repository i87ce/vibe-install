#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 08-containers.sh — Docker Desktop + Terraform + Ansible.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="08-containers"

run_containers() {
  local s="$VIBE_SELECTED"
  [[ " $s " == *" docker "*    ]] && brew_cask_install docker "$MOD"
  if [[ " $s " == *" terraform "* ]]; then
    brew tap hashicorp/tap >>"$VIBE_LOG_FILE" 2>&1 || true
    brew_install hashicorp/tap/terraform "$MOD"
  fi
  [[ " $s " == *" ansible "*   ]] && brew_install ansible "$MOD"
  return 0
}
