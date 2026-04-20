# Modern replacements (if installed)
command -v eza >/dev/null && {
  alias ls='eza'
  alias ll='eza -lh --git'
  alias la='eza -lah --git'
  alias tree='eza --tree'
}
command -v bat >/dev/null && alias cat='bat --paging=never'
command -v fd  >/dev/null && alias find='fd'

# Safer defaults
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias rm='rm -i'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='clear'
alias ~='cd ~'

# Utility
alias ip='dig +short myip.opendns.com @resolver1.opendns.com'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias cleanupDS="find . -type f -name '.DS_Store' -delete"
alias path='echo $PATH | tr ":" "\n"'
alias reloadzsh='source ~/.zshrc'

# Kubernetes
alias k='kubectl'
command -v kubectl >/dev/null && complete -F __start_kubectl k

# Claude Code
alias cl='claude --dangerously-skip-permissions'
alias ccl='claude'

# Git
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'

# Functions
mcd()   { mkdir -p "$1" && cd "$1"; }
trash() { mv "$@" ~/.Trash/; }
extract() {
  [ -f "$1" ] || { echo "$1 not a file"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.7z)             7z x    "$1" ;;
    *.rar)            unrar e "$1" ;;
    *) echo "cannot extract $1" ;;
  esac
}
