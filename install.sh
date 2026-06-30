#!/bin/bash
# codex-img-prep installer
# Copies scripts + LaunchAgent + Quick Action into $HOME, loads the agent,
# patches CC Switch SQLite. Idempotent: safe to re-run.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CODEX_PROVIDER_ID="b838cc0d-0d4e-4ad1-a671-7d1be8ba78f4"

echo "▶ installing codex-img-prep from $HERE"
echo

# 1. dependencies
if ! command -v pngpaste >/dev/null 2>&1 || ! command -v fswatch >/dev/null 2>&1; then
    echo "▶ installing brew deps: pngpaste fswatch"
    brew install pngpaste fswatch
fi

# 2. scripts
mkdir -p "$HOME/bin"
cp "$HERE/bin/codex-img-prep"      "$HOME/bin/codex-img-prep"
cp "$HERE/bin/codex-clip-watch.sh" "$HOME/bin/codex-clip-watch.sh"
chmod +x "$HOME/bin/codex-img-prep" "$HOME/bin/codex-clip-watch.sh"
echo "✓ scripts copied to ~/bin/"

# 3. LaunchAgent — substitute $HOME into the plist
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|/Users/macstudiodisplay|$HOME|g" \
    "$HERE/launchd/com.user.codex-clipprep.plist" \
    > "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist"
launchctl unload "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist" 2>/dev/null || true
launchctl load -w "$HOME/Library/LaunchAgents/com.user.codex-clipprep.plist"
echo "✓ LaunchAgent loaded"

# 4. Quick Action
mkdir -p "$HOME/Library/Services"
rm -rf "$HOME/Library/Services/Compress for Codex.workflow"
cp -R "$HERE/workflow/Compress for Codex.workflow" "$HOME/Library/Services/"
# Substitute home in the workflow
find "$HOME/Library/Services/Compress for Codex.workflow" \
    \( -name '*.plist' -o -name '*.wflow' \) -print0 \
  | xargs -0 sed -i '' "s|/Users/macstudiodisplay|$HOME|g"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "✓ Quick Action installed (Finder → right-click → Compress for Codex)"

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
echo "✓ aliases added to ~/.zshrc (run 'source ~/.zshrc' to activate)"

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
        echo "✓ CC Switch apiFormat patched: $current → openai_responses"
        echo "  backup: ~/.cc-switch/backups/manual/cc-switch.db.pre-apifix-$TS"
        echo "  ⚠ restart CC Switch to apply"
    else
        echo "✓ CC Switch apiFormat already set to '$current', skipping"
    fi
else
    echo "⚠ no CC Switch db found at $DB, skipping SQLite patch"
fi

echo
echo "✅ install complete"
echo
echo "Try it:"
echo "  prep-clip          # resize clipboard image"
echo "  prep-img big.png   # resize a file"
echo "  Right-click an image in Finder → Quick Actions → Compress for Codex"