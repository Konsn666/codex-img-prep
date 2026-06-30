#!/bin/bash
# install-remote.sh - one-shot installer for codex-img-prep
# Usage:  curl -fsSL https://raw.githubusercontent.com/Konsn666/codex-img-prep/main/install-remote.sh | bash
#
# What it does:
#   1. Clones the repo into a tmp dir
#   2. Runs ./install.sh (which handles brew deps, file copies, LaunchAgent, SQLite patch)
#   3. Cleans up the tmp dir
#   4. Prints success + next-step hints
#
# Idempotent: re-running is safe (install.sh is idempotent too).
# Re-install location: the repo clone is ephemeral, files are in ~/bin/ and ~/Library/.

set -euo pipefail

REPO_URL="https://github.com/Konsn666/codex-img-prep.git"
BRANCH="${CODEX_IMG_PREP_BRANCH:-main}"

echo "▶ codex-img-prep one-shot installer"
echo

# Sanity: macOS only (we need sips, which is built-in on macOS)
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "✗ this installer is macOS-only (uses sips)" >&2
    exit 1
fi

# Sanity: git
if ! command -v git >/dev/null 2>&1; then
    echo "✗ git not found; install Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
fi

# Clone into a tmp dir
WORK=$(mktemp -d -t codex-img-prep-install.XXXXXX)
echo "▶ cloning $REPO_URL @ $BRANCH → $WORK"
if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK" 2>/dev/null; then
    # Fallback: clone without branch specifier (in case default branch changes)
    echo "  branch '$BRANCH' clone failed, retrying with default"
    git clone --depth 1 "$REPO_URL" "$WORK"
fi

# Hand off to install.sh
echo "▶ running install.sh"
echo
bash "$WORK/install.sh"
RC=$?

# Cleanup
rm -rf "$WORK"

echo
if (( RC == 0 )); then
    cat <<'NEXT'

✅ done. Next steps:
  • restart CC Switch for the SQLite patch to take effect
  • try:  prep-clip            (resize current clipboard image)
  • try:  prep-img big.png     (resize a single file)
  • try:  right-click any image in Finder → Quick Actions → Compress for Codex
  • uninstall:  see https://github.com/Konsn666/codex-img-prep#uninstall

NEXT
else
    echo "✗ install.sh exited $RC; repo dir $WORK was cleaned up regardless" >&2
fi
exit $RC