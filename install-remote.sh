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

echo "▶ codex-img-prep 一键安装 / one-shot installer"
echo

# Sanity: macOS only (we need sips, which is built-in on macOS)
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "✗ 这个安装器仅支持 macOS (用了 sips) / this installer is macOS-only (uses sips)" >&2
    exit 1
fi

# Sanity: git
if ! command -v git >/dev/null 2>&1; then
    echo "✗ 没找到 git; 先装 Xcode 命令行工具: xcode-select --install / git not found; install Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
fi

# Clone into a tmp dir
WORK=$(mktemp -d -t codex-img-prep-install.XXXXXX)
echo "▶ 正在克隆 / cloning $REPO_URL @ $BRANCH → $WORK"
if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK" 2>/dev/null; then
    # Fallback: clone without branch specifier (in case default branch changes)
    echo "  branch '$BRANCH' 克隆失败, 重试默认分支 / clone failed, retrying with default"
    git clone --depth 1 "$REPO_URL" "$WORK"
fi

# Hand off to install.sh
echo "▶ 运行 / running install.sh"
echo
bash "$WORK/install.sh"
RC=$?

# Cleanup
rm -rf "$WORK"

echo
if (( RC == 0 )); then
    cat <<'NEXT'

✅ 装好了 / done. Next steps:
  • 重启 CC Switch 让 SQLite 改动生效 / restart CC Switch for the SQLite patch to take effect
  • 试试 / try:  prep-clip            (压缩剪贴板图片 / resize current clipboard image)
  • 试试 / try:  prep-img big.png     (压缩单个文件 / resize a single file)
  • 试试 / try:  Finder 右键任意图片 → Quick Actions → Compress for Codex
  • 卸载 / uninstall:  https://github.com/Konsn666/codex-img-prep#uninstall
  • 中文文档 / Chinese docs: https://github.com/Konsn666/codex-img-prep/blob/main/README.zh-CN.md

NEXT
else
    echo "✗ install.sh 退出 $RC; 仓库目录 $WORK 已清理 / repo dir cleaned up regardless" >&2
fi
exit $RC