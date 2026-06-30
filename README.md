# codex-img-prep

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)

**Auto-resize images for Codex CLI when routed through CC Switch → MiniMax (or any provider with a similar ~10 MB media cap).**

End users see:

> CC Switch local proxy failed while handling Codex endpoint /responses.
> cause: invalid params, context window exceeds limit (2013)

The error message is misleading — the real cause is **MiniMax rejects single images > 10 MB**, and MiniMax reuses error code `2013` for both context overflow and media overflow. CC Switch's error wrapper translates every `2013` into "context window exceeds limit", so users spend hours clearing history and switching models when the actual fix is "shrink the image".

This package ships a 5-piece workaround that makes the issue invisible in daily use.

## What's inside

| File | Purpose |
|---|---|
| `bin/codex-img-prep` | `sips`-based image resizer (max 1920 px, JPEG q85, ≤ 8 MB hard cap) |
| `bin/codex-clip-watch.sh` | Clipboard auto-resize loop (run via LaunchAgent) |
| `launchd/com.user.codex-clipprep.plist` | LaunchAgent config: runs every 2 s, auto-loads at login |
| `workflow/Compress for Codex.workflow/` | Finder right-click Quick Action |
| `install.sh` | One-shot installer (copies files + loads LaunchAgent) |
| `cc-switch-fix.sql` | SQLite patch to set `meta.apiFormat = "openai_responses"` on Codex provider |

## Why this exists

I tried sending a 38.64 MB Retina screenshot through Codex and got:

```
upstream_status: HTTP 400
cause: invalid params, context window exceeds limit (2013)
```

After hitting this in real work, I dug in:

- Direct `curl` to `https://api.minimaxi.com/v1/responses` with the same image returns `{"error":{"message":"media exceeds size limit: max 10485760 bytes (2013)"}}` — the upstream **message** says "media", CC Switch rewrites it to "context window".
- `MiniMax-M3` actually supports 200K+ tokens of context (I tested 210K Chinese chars + image = 200 OK).
- The 10 MB cap is on the base64-decoded image data; MiniMax internally caps image tokens at ~5370 regardless of dimensions.

Conclusion: the fix has to be client-side image preprocessing. CC Switch can't bypass the upstream limit.

## Verified end-to-end

```
created 38.64 MB screenshot
✓ final-test.png  40515664B → 1088990B  (-97%)
CC Switch → MiniMax status=200
answer: 橙色
tokens: {'input_tokens': 3349, 'output_tokens': 1, 'total_tokens': 3350}
```

The MiniMax model correctly identified "orange" in a heavily-noised 4500×3000 image.

## Install

Requires macOS 13+ and `brew`. Tested on macOS 15.4 (Apple Silicon).

```bash
# 1. Install dependencies
brew install pngpaste fswatch

# 2. Run installer
git clone https://github.com/Konsn666/codex-img-prep.git
cd codex-img-prep
./install.sh
```

The installer:
1. Copies `bin/` scripts to `~/bin/`
2. Copies `launchd/com.user.codex-clipprep.plist` to `~/Library/LaunchAgents/`
3. Copies `workflow/Compress for Codex.workflow/` to `~/Library/Services/`
4. Loads the LaunchAgent with `launchctl load -w`
5. Patches CC Switch SQLite (`meta.apiFormat = "openai_responses"`) with an automatic backup
6. Adds shell aliases to `~/.zshrc`

Restart CC Switch after install for the SQLite change to take effect.

## Usage

Once installed, the system works invisibly:

- **Screenshot → paste in Codex**: The LaunchAgent detects the new clipboard image every 2 seconds. If it's > 2 MB, it's resized to fit, and the smaller version is written back to the clipboard. Paste as usual.
- **Finder right-click**: Right-click any image file → **Quick Actions → Compress for Codex**. Replaces in place.
- **Manual CLI**:
  ```bash
  prep-clip        # resize the image currently on the clipboard
  prep-img ~/Desktop/big.png   # resize a single file in place
  prep-watch ~/Desktop          # watch a folder for new screenshots
  ```

## CC Switch upstream issue

The root cause (2013 being mapped to "context window exceeds limit" regardless of whether it's actually media or context) is a bug in CC Switch's error wrapper. I opened an issue against `farion1231/cc-switch` documenting the diagnosis + suggesting a fix:  
**[Bug] Misleading "context window exceeds limit (2013)" when attaching images > 10MB to Codex** — see [ISSUE.md](ISSUE.md) for the full text.

This package exists independently because:
- The 10 MB cap is on MiniMax's side and can't be bypassed by CC Switch
- Users need a workaround today, not after upstream ships a fix

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.user.codex-clipprep.plist
rm -f ~/bin/codex-img-prep ~/bin/codex-clip-watch.sh
rm -f ~/Library/LaunchAgents/com.user.codex-clipprep.plist
rm -rf ~/Library/Services/Compress\ for\ Codex.workflow

# Restore CC Switch apiFormat to openai_chat:
sqlite3 ~/.cc-switch/cc-switch.db \
  "UPDATE providers
   SET meta = json_set(meta, '\$.apiFormat', 'openai_chat')
   WHERE app_type='codex'"
osascript -e 'tell application "CC Switch" to quit' && open -a "CC Switch"

# Remove aliases from ~/.zshrc (manual edit)
```

The CC Switch DB backup from `install.sh` is preserved at `~/.cc-switch/backups/manual/` for full rollback.

## Files

- [bin/codex-img-prep](bin/codex-img-prep) — the resizer (bash + `sips`)
- [bin/codex-clip-watch.sh](bin/codex-clip-watch.sh) — the clipboard watcher (bash + `pngpaste`)
- [launchd/com.user.codex-clipprep.plist](launchd/com.user.codex-clipprep.plist) — LaunchAgent config
- [workflow/Compress for Codex.workflow/](workflow/Compress%20for%20Codex.workflow/) — Finder Quick Action
- [install.sh](install.sh) — one-shot installer
- [cc-switch-fix.sql](cc-switch-fix.sql) — SQLite patch (run separately)
- [ISSUE.md](ISSUE.md) — text of the CC Switch upstream bug report

## License

MIT — see [LICENSE](LICENSE).

## Author

[Konsn666](https://github.com/Konsn666) — built while debugging my own Codex → CC Switch → MiniMax image upload failures.