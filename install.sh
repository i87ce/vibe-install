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

# Foundation runs unconditionally in every mode except --doctor
if [[ "$MODE" != "doctor" ]]; then
  # shellcheck source=lib/01-foundation.sh
  source "$SCRIPT_DIR/lib/01-foundation.sh"
  run_foundation || { log_fail "main" "Foundation failed — cannot continue"; exit 1; }

  # Ensure `dialog` is available for the TUI (needs brew, just installed)
  brew_install "dialog" "main"

  # iTerm2 is installed unconditionally alongside Foundation
  # shellcheck source=lib/02-iterm2.sh
  source "$SCRIPT_DIR/lib/02-iterm2.sh"
  run_iterm2 || log_warn "main" "iTerm2 setup had failures — continuing"
fi

# -- Dispatch ------------------------------------------------------------------

# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"

case "$MODE" in
  doctor)
    echo "(doctor runs after module block — call doctor_run)"; exit 0
    ;;
  config)
    VIBE_SELECTED="$(tui_load_config "$CONFIG_FILE")"
    # Non-interactive: use defaults for sub-prompts unless env vars already set
    : "${VIBE_PROMPT:=p10k}"
    : "${VIBE_VERTEX_PROJECT:=ea-claw}"
    : "${VIBE_VERTEX_REGION:=europe-west1}"
    : "${VIBE_OBSIDIAN_VAULT:=}"
    export VIBE_SELECTED VIBE_PROMPT VIBE_VERTEX_PROJECT VIBE_VERTEX_REGION VIBE_OBSIDIAN_VAULT
    ;;
  only)
    VIBE_SELECTED="$(echo "$ONLY_MODULES" | tr ',' ' ')"
    : "${VIBE_PROMPT:=p10k}"
    : "${VIBE_VERTEX_PROJECT:=ea-claw}"
    : "${VIBE_VERTEX_REGION:=europe-west1}"
    : "${VIBE_OBSIDIAN_VAULT:=}"
    export VIBE_SELECTED VIBE_PROMPT VIBE_VERTEX_PROJECT VIBE_VERTEX_REGION VIBE_OBSIDIAN_VAULT
    ;;
  dry-run|interactive)
    tui_run || { log_fail "main" "TUI cancelled"; exit 1; }
    ;;
esac

log_info "main" "Selected: $VIBE_SELECTED"
log_info "main" "Prompt=$VIBE_PROMPT vertex=$VIBE_VERTEX_PROJECT/$VIBE_VERTEX_REGION vault=${VIBE_OBSIDIAN_VAULT:-none}"

# Source and dispatch modules in order
# shellcheck source=lib/03-shell.sh
source "$SCRIPT_DIR/lib/03-shell.sh"
# shellcheck source=lib/04-cli.sh
source "$SCRIPT_DIR/lib/04-cli.sh"
# shellcheck source=lib/05-claude.sh
source "$SCRIPT_DIR/lib/05-claude.sh"
# shellcheck source=lib/06-obsidian.sh
source "$SCRIPT_DIR/lib/06-obsidian.sh"
# shellcheck source=lib/07-runtimes.sh
source "$SCRIPT_DIR/lib/07-runtimes.sh"
# shellcheck source=lib/08-containers.sh
source "$SCRIPT_DIR/lib/08-containers.sh"
# shellcheck source=lib/09-cloud.sh
source "$SCRIPT_DIR/lib/09-cloud.sh"
# shellcheck source=lib/10-browsers.sh
source "$SCRIPT_DIR/lib/10-browsers.sh"
# shellcheck source=lib/11-db.sh
source "$SCRIPT_DIR/lib/11-db.sh"

# Order matters: runtimes before claude (claude CLI needs node),
# cloud before claude vertex login (needs gcloud).
run_shell      || log_warn "main" "shell module had failures"
run_cli        || log_warn "main" "cli module had failures"
run_runtimes   || log_warn "main" "runtimes module had failures"
run_cloud      || log_warn "main" "cloud module had failures"
run_claude     || log_warn "main" "claude module had failures"
run_obsidian   || log_warn "main" "obsidian module had failures"
run_containers || log_warn "main" "containers module had failures"
run_browsers   || log_warn "main" "browsers module had failures"
run_db         || log_warn "main" "db module had failures"
