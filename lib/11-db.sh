#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# 11-db.sh — psql, mysql-client, redis-cli, sqlite.
if ! declare -F log_info >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# shellcheck disable=SC2034
MOD="11-db"

run_db() {
  [[ " $VIBE_SELECTED " == *" db_clients "* ]] || return 0
  brew_install postgresql@17 "$MOD"
  brew_install mysql-client  "$MOD"
  brew_install redis         "$MOD"   # ships redis-cli
  brew_install sqlite        "$MOD"
  return 0
}
