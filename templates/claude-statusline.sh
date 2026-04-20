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
