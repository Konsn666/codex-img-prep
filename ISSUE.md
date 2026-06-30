# CC Switch upstream issue

This file contains the verbatim text submitted as a bug report against
[farion1231/cc-switch](https://github.com/farion1231/cc-switch).

To re-submit (after `gh auth login`):

```bash
gh issue create \
  --repo farion1231/cc-switch \
  --title "[Bug] Misleading \"context window exceeds limit (2013)\" when attaching images > 10MB to Codex" \
  --body-file ISSUE.md
```

---

## Issue body

### Bug description

When using Codex CLI through CC Switch with the MiniMax provider (`MiniMax-M3`), attaching any image larger than **10 MB** to a Codex conversation fails with:

```
CC Switch local proxy failed while handling Codex endpoint /responses.
Provider: MiniMax; model: MiniMax-M3;
upstream_status: HTTP 400;
cause: invalid params, context window exceeds limit (2013)
```

This message is **misleading**. The 2013 error code from the MiniMax API is reused for multiple distinct failure modes:

1. Real context window overflow (200K tokens exceeded)
2. **`media exceeds size limit: max 10485760 bytes (2013)`** — single image attachment > 10 MB

CC Switch's upstream-error wrapper translates every 2013 into "context window exceeds limit", which sends users down the wrong debugging path (clearing history, switching models) when the actual fix is "shrink the image".

### Reproduction

1. Configure Codex with `wire_api = "responses"` and any provider that forwards to MiniMax-M3 (or any MiniMax-family model with a similar media cap).
2. Take a screenshot larger than 10 MB (a Retina screenshot of a detail-rich page, a long-scrolled PDF page, etc.).
3. Drag/drop or paste the image into a Codex conversation.
4. Observe: error message mentions "context window" even though the conversation has fewer than 1K tokens.

Direct curl to the MiniMax API confirms:

```
$ curl ... /v1/responses -d '{ "model": "MiniMax-M3", "input": [...large image...] }'
{"error":{"message":"media exceeds size limit: max 10485760 bytes (2013)",
          "code":"invalid_prompt"}}
```

### Expected

Either:
- Forward MiniMax's original `message` field to the Codex UI so the user sees "media exceeds size limit" instead of "context window exceeds limit", OR
- Map the error code's context (was an image attached? what's the request size?) into a more accurate human-readable message.

### Workaround (for end users, in the meantime)

I packaged a 5-piece client-side workaround at https://github.com/Konsn666/codex-img-prep:

1. CC Switch provider `meta.apiFormat = "openai_responses"` (also avoids lossy `/responses → /chat/completions` translation).
2. `sips`-based resize script (`codex-img-prep`) targeting 1920px / JPEG q85 / ≤ 8 MB.
3. `launchd` agent that auto-resizes clipboard images > 2 MB every 2 seconds.
4. Finder Quick Action "Compress for Codex".
5. Shell aliases (`prep-clip`, `prep-img`, `prep-watch`).

End-to-end verified: a 38.64 MB screenshot → 1.04 MB after the pipeline → CC Switch → MiniMax → 200 OK with correct vision answer.

### Environment

- CC Switch: v3.16.4 (Jun 27 2026)
- Codex CLI: latest, `wire_api = "responses"`
- MiniMax-M3 via api.minimaxi.com
- macOS 15.4 (Apple Silicon)