#!/usr/bin/env bash
# vibe-install main orchestrator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# -- Defaults ------------------------------------------------------------------

MODE="interactive"           # interactive | config | only | doctor | dry-run
CONFIG_FILE=""
ONLY_MODULES=""
LOG_LEVEL="info"             # info | debug

# -- Usage ---------------------------------------------------------------------

usage() {
  cat <<'EOF'
vibe-install — macOS "vibe coding" environment bootstrapper

Usage:
  ./install.sh                       Run interactive TUI (default)
  ./install.sh --config FILE         Non-interactive with saved config
  ./install.sh --only MOD[,MOD...]   Run only listed modules (e.g. --only claude,cloud)
  ./install.sh --doctor              Run post-install verification only
  ./install.sh --dry-run             Print planned actions without executing
  ./install.sh --log-level debug     Verbose logging
  ./install.sh --help                Show this message

Modules: foundation, iterm2, shell, cli, claude, obsidian, runtimes,
         containers, cloud, browsers, db
EOF
}

# -- Arg parse -----------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)     MODE="config"; CONFIG_FILE="$2"; shift 2 ;;
    --only)       MODE="only"; ONLY_MODULES="$2"; shift 2 ;;
    --doctor)     MODE="doctor"; shift ;;
    --dry-run)    MODE="dry-run"; shift ;;
    --log-level)  LOG_LEVEL="$2"; shift 2 ;;
    --help|-h)    usage; exit 0 ;;
    *)            echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# Mark vars as read so shellcheck sees them used (real consumers land in Phases 4 and 9).
: "$CONFIG_FILE" "$ONLY_MODULES" "$LOG_LEVEL"

log_run_header
log_info "main" "mode=$MODE"

# -- Dispatch placeholder (filled in later tasks) ------------------------------

case "$MODE" in
  doctor)      echo "(doctor not yet implemented)"; exit 0 ;;
  dry-run)     echo "(dry-run not yet implemented)"; exit 0 ;;
  interactive|config|only) echo "(main flow not yet implemented)"; exit 0 ;;
esac
