#Requires -Version 5.1
<#
.SYNOPSIS
    DonTouch SA - Claude Code Windows Installer
    Sets up Claude Code + Vertex AI + plugins + statusline + agent teams on a fresh Windows machine.

.DESCRIPTION
    Self-contained PowerShell installer. No repo clone needed.
    Usage (one-liner):
        irm https://raw.githubusercontent.com/i87ce/vibe-install/main/windows/install.ps1 | iex

.NOTES
    Author : DonTouch SA
    Version: 1.0.0
    Date   : 2026-04-20
#>

# ── Strict mode ──────────────────────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Colors helper ────────────────────────────────────────────────────────────

function Write-Step  { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "  [ERR] $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "  $Msg" -ForegroundColor Gray }

# ── Deep-merge utility ───────────────────────────────────────────────────────

function Merge-JsonDeep {
    <#
    .SYNOPSIS
        Recursively merges two PSCustomObjects (parsed JSON).
        - For scalar values: $Override wins.
        - For objects/hashtables: recurse and union keys.
        - For arrays: union (deduplicate).
        User's existing keys are preserved; template adds new ones.
    #>
    param(
        [Parameter(Mandatory)] $Base,
        [Parameter(Mandatory)] $Override
    )

    # If either side is null, the other wins
    if ($null -eq $Base)     { return $Override }
    if ($null -eq $Override) { return $Base }

    # Both are objects (PSCustomObject) -> recurse per property
    if ($Base -is [System.Management.Automation.PSCustomObject] -and
        $Override -is [System.Management.Automation.PSCustomObject]) {

        $merged = $Base.PSObject.Copy()

        foreach ($prop in $Override.PSObject.Properties) {
            $existing = $merged.PSObject.Properties[$prop.Name]
            if ($null -ne $existing) {
                # Key exists in both -> recurse
                $existing.Value = Merge-JsonDeep -Base $existing.Value -Override $prop.Value
            } else {
                # New key from override
                $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
            }
        }
        return $merged
    }

    # Both are arrays -> union (deduplicate)
    if ($Base -is [System.Array] -and $Override -is [System.Array]) {
        $union = [System.Collections.ArrayList]::new()
        foreach ($item in $Base)     { if ($item -notin $union) { [void]$union.Add($item) } }
        foreach ($item in $Override) { if ($item -notin $union) { [void]$union.Add($item) } }
        return @($union)
    }

    # Scalars or mismatched types -> override wins
    return $Override
}

# ══════════════════════════════════════════════════════════════════════════════
# 1. PRE-FLIGHT CHECKS
# ══════════════════════════════════════════════════════════════════════════════

function Test-Preflight {
    Write-Step "Pre-flight checks"

    # Must be Windows
    if ($env:OS -ne "Windows_NT") {
        Write-Err "This script is designed for Windows. Detected OS: $($env:OS ?? 'unknown')"
        Write-Err "For macOS/Linux, use the bash installer instead."
        exit 1
    }
    Write-Ok "Running on Windows"

    # Execution policy
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq 'Restricted') {
        Write-Warn "Execution policy is 'Restricted'. You may need to run:"
        Write-Warn "  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
        Write-Warn "Continuing anyway (piped scripts bypass this)..."
    } else {
        Write-Ok "Execution policy: $policy"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 2. INSTALL NODE.JS
# ══════════════════════════════════════════════════════════════════════════════

function Install-NodeIfMissing {
    Write-Step "Checking Node.js"

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = & node --version 2>&1
        Write-Ok "Node.js already installed: $nodeVer"
    } else {
        Write-Info "Node.js not found. Attempting install via winget..."

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            try {
                Write-Info "Running: winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements"
                & winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
                # Refresh PATH so node is visible in this session
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                            [System.Environment]::GetEnvironmentVariable("Path", "User")
                $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
                if ($nodeCmd) {
                    $nodeVer = & node --version 2>&1
                    Write-Ok "Node.js installed via winget: $nodeVer"
                } else {
                    Write-Warn "winget install succeeded but 'node' not yet in PATH."
                    Write-Warn "Close and reopen your terminal, then re-run this script."
                    exit 1
                }
            } catch {
                Write-Err "winget install failed: $_"
                Write-Err "Please install Node.js LTS manually from: https://nodejs.org/en/download/"
                exit 1
            }
        } else {
            Write-Err "winget not available and Node.js not found."
            Write-Err "Please install Node.js LTS manually from: https://nodejs.org/en/download/"
            Write-Err "Then re-run this script."
            exit 1
        }
    }

    # Verify npm
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $npmVer = & npm --version 2>&1
        Write-Ok "npm available: v$npmVer"
    } else {
        Write-Err "npm not found even though Node.js is installed. Please reinstall Node.js."
        exit 1
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 3. INSTALL CLAUDE CODE CLI
# ══════════════════════════════════════════════════════════════════════════════

function Install-ClaudeCode {
    Write-Step "Checking Claude Code CLI"

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $claudeVer = & claude --version 2>&1
        Write-Ok "Claude Code already installed: $claudeVer"
    } else {
        Write-Info "Installing Claude Code CLI via npm..."
        try {
            & npm install -g @anthropic-ai/claude-code 2>&1 | ForEach-Object { Write-Info $_ }
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
            $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
            if ($claudeCmd) {
                $claudeVer = & claude --version 2>&1
                Write-Ok "Claude Code installed: $claudeVer"
            } else {
                Write-Warn "npm install succeeded but 'claude' not in PATH. You may need to reopen your terminal."
            }
        } catch {
            Write-Err "Failed to install Claude Code: $_"
            exit 1
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 4. CONFIGURE VERTEX AI
# ══════════════════════════════════════════════════════════════════════════════

function Set-VertexConfig {
    Write-Step "Configuring Vertex AI"

    # Prompt for project ID
    $script:VertexProject = Read-Host "  Vertex AI Project ID [ea-claw]"
    if ([string]::IsNullOrWhiteSpace($script:VertexProject)) {
        $script:VertexProject = "ea-claw"
    }
    Write-Ok "Project: $($script:VertexProject)"

    # Prompt for region
    $script:VertexRegion = Read-Host "  Vertex AI Region [europe-west1]"
    if ([string]::IsNullOrWhiteSpace($script:VertexRegion)) {
        $script:VertexRegion = "europe-west1"
    }
    Write-Ok "Region: $($script:VertexRegion)"

    # gcloud auth if available
    $gcloudCmd = Get-Command gcloud -ErrorAction SilentlyContinue
    if ($gcloudCmd) {
        Write-Info "gcloud found. Running application-default login (opens browser)..."
        try {
            & gcloud auth application-default login 2>&1 | ForEach-Object { Write-Info $_ }
            Write-Ok "gcloud auth completed"
        } catch {
            Write-Warn "gcloud auth failed: $_"
            Write-Warn "You can run it manually later: gcloud auth application-default login"
        }
    } else {
        Write-Warn "gcloud CLI not found. Skipping authentication."
        Write-Warn "Install Google Cloud SDK from: https://cloud.google.com/sdk/docs/install"
        Write-Warn "Then run: gcloud auth application-default login"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 5. WRITE / MERGE ~/.claude/settings.json
# ══════════════════════════════════════════════════════════════════════════════

function Set-ClaudeSettings {
    Write-Step "Configuring Claude Code settings"

    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Info "Created $claudeDir"
    }

    $settingsPath = Join-Path $claudeDir "settings.json"

    # Use forward slashes for the home path (bash compatibility)
    $homePath = $env:USERPROFILE -replace '\\', '/'

    # Build the template as a JSON string with placeholders replaced
    $templateJson = @"
{
  "env": {
    "CLAUDE_CODE_USE_VERTEX": "1",
    "ANTHROPIC_VERTEX_PROJECT_ID": "$($script:VertexProject)",
    "CLOUD_ML_REGION": "$($script:VertexRegion)",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": [
      "*",
      "Read", "Grep", "Glob", "LS",
      "Bash", "WebFetch", "WebSearch",
      "Edit", "Write", "NotebookEdit",
      "TodoWrite", "Task",
      "mcp__*"
    ]
  },
  "model": "opus[1m]",
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "figma@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "ralph-loop@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "claude-code-setup@claude-plugins-official": true,
    "chrome-devtools-mcp@claude-plugins-official": true,
    "sentry@claude-plugins-official": true,
    "cloudflare@claude-plugins-official": true,
    "mempalace@mempalace": true,
    "fullstack-dev-skills@fullstack-dev-skills": true
  },
  "extraKnownMarketplaces": {
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } },
    "mempalace": { "source": { "source": "github", "repo": "milla-jovovich/mempalace" } },
    "fullstack-dev-skills": { "source": { "source": "github", "repo": "jeffallan/claude-skills" } }
  },
  "skipDangerousModePermissionPrompt": true,
  "statusLine": {
    "type": "command",
    "command": "bash $homePath/.claude/statusline.sh"
  }
}
"@

    $template = $templateJson | ConvertFrom-Json

    if (Test-Path $settingsPath) {
        Write-Info "Existing settings.json found. Deep-merging with template..."
        try {
            $existing = Get-Content -Raw $settingsPath | ConvertFrom-Json
            $merged = Merge-JsonDeep -Base $existing -Override $template
            $merged | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
            Write-Ok "settings.json merged at $settingsPath"
        } catch {
            Write-Warn "Failed to parse existing settings.json: $_"
            Write-Info "Backing up and overwriting..."
            Copy-Item $settingsPath "$settingsPath.bak" -Force
            $template | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
            Write-Ok "settings.json written (backup at $settingsPath.bak)"
        }
    } else {
        $template | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Ok "settings.json created at $settingsPath"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 6. INSTALL STATUSLINE
# ══════════════════════════════════════════════════════════════════════════════

function Install-Statusline {
    Write-Step "Installing statusline"

    $statuslinePath = Join-Path $env:USERPROFILE ".claude" "statusline.sh"

    # Embedded statusline script (from templates/claude-statusline.sh)
    $statuslineContent = @'
#!/usr/bin/env bash
# Claude Code statusline
set -u

input="$(cat)"

jqr() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

model="$(jqr '.model.display_name // "Claude"')"
ctx_pct="$(jqr '.context_window.used_percentage // 0')"
h5_pct="$(jqr '.rate_limits.five_hour.used_percentage // 0')"
d7_pct="$(jqr '.rate_limits.seven_day.used_percentage // 0')"
cwd="$(jqr '.workspace.current_dir // .cwd // ""')"
transcript="$(jqr '.transcript_path // ""')"

for var in ctx_pct h5_pct d7_pct; do
  val="${!var}"
  if [[ -z "$val" || "$val" == "null" ]]; then
    printf -v "$var" '%s' 0
  fi
done

to_int() {
  local v="$1"
  v="${v%.*}"
  [[ -z "$v" || "$v" == "-" ]] && v=0
  printf '%d' "$v" 2>/dev/null || printf '0'
}

ctx_i=$(to_int "$ctx_pct")
h5_i=$(to_int "$h5_pct")
d7_i=$(to_int "$d7_pct")

ESC=$'\033'
RESET="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"
MAGENTA="${ESC}[35m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
CYAN="${ESC}[36m"

color_for_pct() {
  local p="$1"
  if (( p < 50 )); then
    printf '%s' "$GREEN"
  elif (( p < 80 )); then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$RED"
  fi
}

build_bar() {
  local p="$1"
  (( p < 0 )) && p=0
  (( p > 100 )) && p=100
  local filled=$(( (p + 5) / 10 ))
  (( filled > 10 )) && filled=10
  local empty=$(( 10 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf '%s' "$bar"
}

ctx_color="$(color_for_pct "$ctx_i")"
h5_color="$(color_for_pct "$h5_i")"
d7_color="$(color_for_pct "$d7_i")"
ctx_bar="$(build_bar "$ctx_i")"

git_part=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
  if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)"
    if [[ -z "$branch" ]]; then
      branch="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)"
    fi
    if [[ -n "$branch" ]]; then
      git_part="${GREEN} ${branch}${RESET}"
    fi
  fi
fi

session_part=""
if [[ -n "$transcript" && -e "$transcript" ]]; then
  birth="$(stat -f %B "$transcript" 2>/dev/null)"
  if [[ -z "$birth" || "$birth" == "0" ]]; then
    birth="$(stat -f %c "$transcript" 2>/dev/null)"
  fi
  if [[ -n "$birth" && "$birth" != "0" ]]; then
    now=$(date +%s)
    delta=$(( now - birth ))
    (( delta < 0 )) && delta=0
    hours=$(( delta / 3600 ))
    mins=$(( (delta % 3600) / 60 ))
    if (( hours > 0 )); then
      session_str="$(printf '%dh %02dm' "$hours" "$mins")"
    else
      session_str="$(printf '%dm' "$mins")"
    fi
    session_part="${DIM}${session_str}${RESET}"
  fi
fi

folder_part=""
if [[ -n "$cwd" ]]; then
  base="$(basename "$cwd")"
  folder_part="${BOLD}${CYAN}${base}${RESET}"
fi

SEP="${DIM} │ ${RESET}"

parts=()
parts+=("${MAGENTA}${model}${RESET}")
parts+=("${ctx_color}${ctx_bar} ${ctx_i}%${RESET}")
[[ -n "$git_part" ]] && parts+=("$git_part")
parts+=("${h5_color}5h:${h5_i}%${RESET}")
parts+=("${d7_color}7d:${d7_i}%${RESET}")
[[ -n "$session_part" ]] && parts+=("$session_part")
[[ -n "$folder_part" ]] && parts+=("$folder_part")

line=""
for p in "${parts[@]}"; do
  if [[ -z "$line" ]]; then
    line="$p"
  else
    line="${line}${SEP}${p}"
  fi
done

printf "%b\n" "$line"
'@

    Set-Content -Path $statuslinePath -Value $statuslineContent -Encoding UTF8 -NoNewline
    # Ensure LF line endings (bash requires it)
    $raw = [System.IO.File]::ReadAllText($statuslinePath)
    $raw = $raw -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($statuslinePath, $raw, [System.Text.UTF8Encoding]::new($false))
    Write-Ok "statusline.sh written to $statuslinePath"

    # Check if bash is available (Git Bash / WSL)
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) {
        Write-Ok "bash found at $($bashCmd.Source) - statusline will work"
    } else {
        Write-Warn "bash not found. The statusline requires bash (Git Bash or WSL)."
        Write-Warn "Install Git for Windows from: https://git-scm.com/download/win"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 7. CONFIGURE AGENT TEAMS
# ══════════════════════════════════════════════════════════════════════════════

function Set-AgentTeams {
    Write-Step "Configuring Agent Teams"

    $configPath = Join-Path $env:USERPROFILE ".claude.json"

    if (Test-Path $configPath) {
        Write-Info "Existing .claude.json found. Setting teammateMode..."
        try {
            $config = Get-Content -Raw $configPath | ConvertFrom-Json
            # Add or overwrite teammateMode
            if ($config.PSObject.Properties['teammateMode']) {
                $config.teammateMode = "tmux"
            } else {
                $config | Add-Member -NotePropertyName 'teammateMode' -NotePropertyValue 'tmux'
            }
            $config | ConvertTo-Json -Depth 20 | Set-Content -Path $configPath -Encoding UTF8
            Write-Ok "teammateMode set to 'tmux' in $configPath"
        } catch {
            Write-Warn "Failed to parse .claude.json: $_"
            Write-Info "Backing up and overwriting..."
            Copy-Item $configPath "$configPath.bak" -Force
            @{ teammateMode = "tmux" } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
            Write-Ok ".claude.json written (backup at $configPath.bak)"
        }
    } else {
        @{ teammateMode = "tmux" } | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
        Write-Ok ".claude.json created at $configPath"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 8. SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

function Show-Summary {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  DonTouch SA - Claude Code Setup Complete" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Claude version
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $claudeVer = & claude --version 2>&1
        Write-Ok "Claude Code: $claudeVer"
    } else {
        Write-Warn "Claude Code: not yet in PATH (reopen terminal)"
    }

    # Node version
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = & node --version 2>&1
        Write-Ok "Node.js: $nodeVer"
    }

    Write-Ok "Vertex AI Project: $($script:VertexProject)"
    Write-Ok "Vertex AI Region:  $($script:VertexRegion)"
    Write-Ok "Settings:          $env:USERPROFILE\.claude\settings.json"
    Write-Ok "Statusline:        $env:USERPROFILE\.claude\statusline.sh"
    Write-Ok "Agent Teams:       $env:USERPROFILE\.claude.json (teammateMode=tmux)"

    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Yellow
    Write-Host "    1. Open a NEW terminal window" -ForegroundColor White
    Write-Host "    2. Run: claude" -ForegroundColor White
    Write-Host "    3. If gcloud auth was skipped, run:" -ForegroundColor White
    Write-Host "       gcloud auth application-default login" -ForegroundColor Gray
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  DonTouch SA - Claude Code Installer for Windows" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

try {
    Test-Preflight
    Install-NodeIfMissing
    Install-ClaudeCode
    Set-VertexConfig
    Set-ClaudeSettings
    Install-Statusline
    Set-AgentTeams
    Show-Summary
} catch {
    Write-Err "Installation failed: $_"
    Write-Err $_.ScriptStackTrace
    exit 1
}
