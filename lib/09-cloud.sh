#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 09-cloud.sh — gcloud, az, wrangler, m365, pwsh + Microsoft.Graph module.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="09-cloud"

install_gcloud() {
  brew_cask_install google-cloud-sdk "$MOD"
  if check_installed gcloud; then
    # shellcheck disable=SC2015
    gcloud components install -q beta gke-gcloud-auth-plugin >>"$VIBE_LOG_FILE" 2>&1 \
      && log_ok "$MOD" "gcloud components: beta, gke-gcloud-auth-plugin installed"
  fi
}

install_azure_cli() { brew_install azure-cli "$MOD"; }

install_wrangler() {
  if ! check_installed npm; then
    log_warn "$MOD" "npm not available yet — skipping wrangler"
    return 0
  fi
  if check_installed wrangler; then
    log_info "$MOD" "wrangler: already installed"
    return 0
  fi
  # shellcheck disable=SC2015
  npm install -g wrangler >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "wrangler: installed"
}

install_m365() {
  if ! check_installed npm; then
    log_warn "$MOD" "npm not available — skipping m365"
    return 0
  fi
  if check_installed m365; then
    log_info "$MOD" "m365: already installed"
    return 0
  fi
  # shellcheck disable=SC2015
  npm install -g @pnp/cli-microsoft365 >>"$VIBE_LOG_FILE" 2>&1 \
    && log_ok "$MOD" "m365: installed"
}

install_pwsh() {
  brew_cask_install powershell "$MOD"
  if check_installed pwsh; then
    # shellcheck disable=SC2015
    pwsh -NoProfile -Command \
      "Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber" \
      >>"$VIBE_LOG_FILE" 2>&1 \
      && log_ok "$MOD" "Microsoft.Graph module: installed"
  fi
}

run_cloud() {
  local MOD="09-cloud"
  local s="$VIBE_SELECTED"
  [[ " $s " == *" gcloud "*   ]] && install_gcloud
  [[ " $s " == *" azure "*    ]] && install_azure_cli
  [[ " $s " == *" wrangler "* ]] && install_wrangler
  [[ " $s " == *" m365 "*     ]] && install_m365
  [[ " $s " == *" pwsh "*     ]] && install_pwsh
  return 0
}
