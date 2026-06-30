-- CC Switch Codex MiniMax provider fix
-- Changes meta.apiFormat from openai_chat → openai_responses
-- This stops the lossy /responses → /chat/completions translation.
--
-- IMPORTANT: backup ~/.cc-switch/cc-switch.db before running this.
-- IMPORTANT: restart CC Switch after running this (osascript quit + open).
--
-- The provider ID below is from farion1231/cc-switch v3.16.x.
-- If yours differs, run:  sqlite3 ~/.cc-switch/cc-switch.db \
--   "SELECT id, app_type, name FROM providers WHERE app_type='codex'"

UPDATE providers
SET meta = json_set(meta, '$.apiFormat', 'openai_responses')
WHERE id = 'b838cc0d-0d4e-4ad1-a671-7d1be8ba78f4'
  AND app_type = 'codex';

-- Verify
SELECT id, app_type, json_extract(meta, '$.apiFormat') AS apiFormat
FROM providers
WHERE app_type = 'codex';