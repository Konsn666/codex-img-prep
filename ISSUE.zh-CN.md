# CC Switch 上游 issue 文本(中文版)

这个文件是对 [farion1231/cc-switch](https://github.com/farion1231/cc-switch) 提的 bug 报告中文版。英文版见 [ISSUE.md](ISSUE.md)。

英文版已用 `gh issue create` 提交到 upstream (#4820);本文件作为中文参考保留。

---

## Issue 正文(中文版)

### Bug 描述

通过 CC Switch 用 Codex CLI 跑 MiniMax-M3 时, attach 任意 **> 10MB** 的图片会失败:

```
CC Switch local proxy failed while handling Codex endpoint /responses.
Provider: MiniMax; model: MiniMax-M3;
upstream_status: HTTP 400;
cause: invalid params, context window exceeds limit (2013)
```

**这条消息是误导的**。MiniMax API 的 `2013` 是个复用错误码, 至少用在两种情况上:

1. **真的** context window 溢出(200K tokens 超了)
2. **`media exceeds size limit: max 10485760 bytes (2013)`** —— 单张图片 > 10MB

CC Switch 的错误包装把 `2013` 一律翻译成 "context window exceeds limit", 让用户去清历史 / 换模型, 实际只需要缩小图片。

### 复现步骤

1. Codex 配 `wire_api = "responses"`, CC Switch 转发到 MiniMax-M3
2. 截一张 > 10MB 的图(视网膜屏 + 内容复杂的网页, 或长 PDF 页面)
3. 拖进 Codex 对话框
4. 错误信息说"context window", 但实际对话不到 1K tokens

直接 `curl` 打 MiniMax API 确认原始错误:

```json
{"error":{"message":"media exceeds size limit: max 10485760 bytes (2013)",
          "code":"invalid_prompt"}}
```

### 期望行为

二选一:
- 把 MiniMax 的原始 `error.message` 字段直接透传到 Codex UI, 用户看到 "media exceeds size limit" 而不是 "context window exceeds limit"
- 根据错误码上下文(有没有附图? 请求多大?)生成更准确的人话消息

### 临时方案(用户侧)

打包了 5 件套客户端 workaround 在 https://github.com/Konsn666/codex-img-prep:

1. CC Switch `meta.apiFormat = "openai_responses"`(顺便也避免 lossy 翻译)
2. `sips` 缩图脚本(`codex-img-prep`)目标 1920px / JPEG q85 / ≤ 8MB
3. `launchd` 每 2 秒检测剪贴板, > 2MB 自动压缩
4. Finder 右键 Quick Action "Compress for Codex"
5. Shell aliases(`prep-clip` / `prep-img` / `prep-watch`)

端到端验证: 38.64MB 截图 → pipeline 后 1.04MB → CC Switch → MiniMax → 200 OK, 视觉识别正确

### 环境

- CC Switch v3.16.4(Jun 27 2026)
- Codex CLI 最新, `wire_api = "responses"`
- MiniMax-M3 通过 api.minimaxi.com
- macOS 15.4(Apple Silicon)

---

## 怎么从命令行开 Issue(中文版)

```bash
# 1. 装 gh CLI
brew install gh

# 2. 登录(交互)
gh auth login

# 3. 开 issue (用英文版 ISSUE.md 内容效果更好, 因为 maintainer 大概率英文)
gh issue create \
  --repo farion1231/cc-switch \
  --title "[Bug] Misleading \"context window exceeds limit (2013)\" when attaching images > 10MB to Codex" \
  --body-file ISSUE.md
```

中文版 `ISSUE.zh-CN.md` 给团队内部 / 国内用户参考;正式提 upstream 用英文版。