typeset -U path  # dedupe
path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $HOME/.local/bin
  $HOME/.cargo/bin
  ${KREW_ROOT:-$HOME/.krew}/bin
  $path
)
export PATH
