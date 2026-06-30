#!/bin/bash
# codex-img-prep installer
# Copies scripts + LaunchAgent + Quick Action into $HOME, loads the agent,
# patches CC Switch SQLite. Idempotent: safe to re-run.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CODEX_PROVIDER_ID="b838cc0d-0d4e-4ad1-a671-7d1be8ba78f4"

echo "▶ 安装 codex-img-prep / installing codex-img-prep from $HERE"
echo

# 1. dependencies
if ! command -v pngpaste >/dev/null 2>&1 || ! command -v fswatch >/dev/null 2>&1; then
    echo "▶ 安装 brew 依赖 / installing brew deps: pngpaste fswatch"
    brew install pngpaste fswatch
fi

# 2. scripts
mkdir -p "$HOME/bin"
cp "$HERE/bin/codex-img-prep"      "$HOME/bin/codex-img-prep"
cp "$HERE/bin/codex-clip-watch.sh" "$HOME/bin/codex-clip-watch.sh"
chmod +x "$HOME/bin/codex-img-prep" "$HOME/bin/codex-clip-watch.sh"
echo "✓ 脚本已拷贝 / scripts copied to ~/bin/"

# 3. LaunchAgent — substitute $HOME into the plist
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|/Users/macstudiodisplay|$HOME|g" \
    "$HERE/launchd/com.user.codex-clipprep.plist" \
    > "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist"
launchctl unload "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist" 2>/dev/null || true
launchctl load -w "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist"
echo "✓ LaunchAgent 已加载 / loaded"

# 4. Quick Action
mkdir -p "$HOME/Library/Services"
rm -rf "$HOME/Library/Services/Compress for Codex.workflow"
cp -R "$HERE/workflow/Compress for Codex.workflow" "$HOME/Library/Services/"
# Substitute home in the workflow
find "$HOME/Library/Services/Compress for Codex.workflow" \
    \( -name '*.plist' -o -name '*.wflow' \) -print0 \
  | xargs -0 sed -i '' "s|/Users/macstudiodisplay|$HOME|g"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "✓ Quick Action 已装好 / installed (Finder → 右键图片 → Quick Actions → Compress for Codex)"

# 5. shell aliases
ALIASES=(
    "alias prep-clip='$HOME/bin/codex-img-prep --clip'"
    "alias prep-img='$HOME/bin/codex-img-prep'"
    "alias prep-watch='$HOME/bin/codex-img-prep --watch \$HOME/Desktop'"
)
for a in "${ALIASES[@]}"; do
    if ! grep -qF "$a" "$HOME/.zshrc" 2>/dev/null; then
        printf '\n# Codex image helpers\n%s\n' "$a" >> "$HOME/.zshrc"
    fi
done
echo "✓ aliases 已加到 ~/.zshrc (跑 'source ~/.zshrc' 激活 / run 'source ~/.zshrc' to activate)"

# 6. CC Switch SQLite patch (with backup)
DB="$HOME/.cc-switch/cc-switch.db"
if [[ -f "$DB" ]]; then
    mkdir -p "$HOME/.cc-switch/backups/manual"
    TS=$(date +%Y%m%d-%H%M%S)
    cp "$DB" "$HOME/.cc-switch/backups/manual/cc-switch.db.pre-apifix-$TS"

    current=$(sqlite3 "$DB" \
        "SELECT json_extract(meta, '\$.apiFormat')
         FROM providers
         WHERE id='$CODEX_PROVIDER_ID' AND app_type='codex'" 2>/dev/null || echo "")

    if [[ "$current" == "openai_chat" || -z "$current" ]]; then
        sqlite3 "$DB" \
          "UPDATE providers
           SET meta = json_set(meta, '\$.apiFormat', 'openai_responses')
           WHERE id='$CODEX_PROVIDER_ID' AND app_type='codex'"
        echo "✓ CC Switch apiFormat 已改 / patched: $current → openai_responses"
        echo "  备份 / backup: ~/.cc-switch/backups/manual/cc-switch.db.pre-apifix-$TS"
        echo "  ⚠ 重启 CC Switch 生效 / restart CC Switch to apply"
    else
        echo "✓ CC Switch apiFormat 已经是 '$current', 跳过 / skipping"
    fi
else
    echo "⚠ 没找到 CC Switch db ($DB), 跳过 SQLite 改动 / skipping SQLite patch"
fi

echo
echo "✅ 安装完成 / install complete"
echo
echo "试试 / Try it:"
echo "  prep-clip              # 压缩剪贴板图片 / resize clipboard image"
echo "  prep-img big.png       # 压缩单个文件 / resize a file"
echo "  prep-watch ~/Desktop   # 监视目录 / watch a folder"
echo "  Finder 右键图片 → Quick Actions → Compress for Codex"