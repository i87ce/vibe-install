#!/usr/bin/env bash
# vibe-install bootstrap — downloaded via curl-pipe-bash on a fresh Mac.
# Verifies OS, clones the repo to a temp dir, hands off to install.sh.
set -euo pipefail

REPO="i87ce/vibe-install"
BRANCH="${VIBE_BRANCH:-main}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: vibe-install targets macOS. Detected: $(uname -s)" >&2
  exit 1
fi

echo "▶ vibe-install bootstrap — cloning $REPO@$BRANCH"

TMPDIR="$(mktemp -d -t vibe-install-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Prefer git if available; fall back to tarball download (fresh Mac may lack git until Xcode CLT is installed)
if command -v git >/dev/null 2>&1; then
  git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$TMPDIR/vibe-install"
else
  echo "  git not found — downloading tarball"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
    | tar -xz -C "$TMPDIR"
  mv "$TMPDIR/vibe-install-$BRANCH" "$TMPDIR/vibe-install"
fi

cd "$TMPDIR/vibe-install"
chmod +x install.sh lib/*.sh
exec ./install.sh "$@"
