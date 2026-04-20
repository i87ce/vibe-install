# Editor
export EDITOR="vim"
export VISUAL="$EDITOR"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# rbenv
command -v rbenv >/dev/null && eval "$(rbenv init - zsh)"

# Google Cloud SDK
if [ -f "$(brew --prefix 2>/dev/null)/share/google-cloud-sdk/path.zsh.inc" ]; then
  source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
  source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
fi

# kubectl / helm / flux completion
command -v kubectl >/dev/null && source <(kubectl completion zsh)
command -v helm    >/dev/null && source <(helm completion zsh)
command -v flux    >/dev/null && source <(flux completion zsh)

# iTerm2 shell integration
[ -e "${HOME}/.iterm2_shell_integration.zsh" ] && source "${HOME}/.iterm2_shell_integration.zsh"

# Zoxide (smart cd)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Claude Code Vertex AI
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="{{VERTEX_PROJECT}}"
export CLOUD_ML_REGION="{{VERTEX_REGION}}"
