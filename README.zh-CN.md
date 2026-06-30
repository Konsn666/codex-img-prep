# codex-img-prep

[English](README.md) | **简体中文**

[![许可证: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![CI](https://github.com/Konsn666/codex-img-prep/actions/workflows/ci.yml/badge.svg)](https://github.com/Konsn666/codex-img-prep/actions/workflows/ci.yml)

**当 Codex CLI 通过 CC Switch → MiniMax(或任何带 ~10MB 媒体上限的 provider) 路由时, 自动压缩图片。**

## 这是什么

如果你是 Codex CLI 用户,通过 CC Switch 走 MiniMax-M3(或类似 provider),attach 图片时大概率见过这个错:

```
CC Switch local proxy failed while handling Codex endpoint /responses.
cause: invalid params, context window exceeds limit (2013)
```

**这条消息是误导的**。真因是 **MiniMax 拒绝单张 > 10MB 的图片**,而 MiniMax 把"context overflow"和"media overflow"两个完全不同的失败场景都用了同一个错误码 `2013`。CC Switch 的错误包装器把所有 `2013` 一律翻译成"context window exceeds limit",所以你会花几小时清历史、换模型,实际只需要"把图缩小"。

这个工具包用 5 件套 workaround 让这个问题在日常使用里"无感"。

---

## 5 件套组成

| 文件 | 作用 |
|---|---|
| `bin/codex-img-prep` | 基于 `sips` 的图片缩放脚本 (最长边 1920px, JPEG q85, ≤ 8MB 硬上限) |
| `bin/codex-clip-watch.sh` | 剪贴板自动 resize 守护进程 (由 LaunchAgent 拉起) |
| `launchd/com.user.codex-clipprep.plist` | LaunchAgent 配置: 每 2 秒跑一次, 登录即自动加载 |
| `workflow/Compress for Codex.workflow/` | Finder 右键 Quick Action |
| `install.sh` / `install-remote.sh` | 一键安装脚本 (本地 / curl\|bash 两种) |

## 为什么存在

我用 Codex 传 38.64MB 的 Retina 截图时撞到这个错。挖了一下:

- 直接 `curl` 打 `https://api.minimaxi.com/v1/responses` 同样 payload,返回 `{"error":{"message":"media exceeds size limit: max 10485760 bytes (2013)"}}` —— 上游 **message** 说的是 "media",CC Switch 改写成了 "context window"
- `MiniMax-M3` 实际 context window 是 200K+ (我用 210K 中文 + 图片测过 200 OK)
- 10MB 上限是 base64 解码后的大小;MiniMax 内部把图片 token cap 在 ~5370

结论: fix 必须在客户端做,CC Switch 没法绕过上游限制。

## 端到端验证

```
created 38.64 MB screenshot
✓ final-test.png  40515664B → 1088990B  (-97%)
CC Switch → MiniMax status=200
answer: 橙色
tokens: {'input_tokens': 3349, 'output_tokens': 1, 'total_tokens': 3350}
```

MiniMax 模型在 4500×3000 高噪点图里正确识别出"橙色"。

## 安装

### 一行命令 (推荐)

```bash
curl -fsSL https://raw.githubusercontent.com/Konsn666/codex-img-prep/main/install-remote.sh | bash
```

搞定。脚本会:
1. 把仓库 clone 到临时目录
2. 跑 `install.sh` (装 brew 依赖、拷文件、加载 LaunchAgent、修 CC Switch SQLite)
3. 清理临时目录
4. 打印后续步骤

装完重启 CC Switch 让 SQLite 改动生效。

### 手动安装 (想先看仓库)

```bash
git clone https://github.com/Konsn666/codex-img-prep.git
cd codex-img-prep
./install.sh
```

installer 做的事:
1. 用 Homebrew 装 `pngpaste` 和 `fswatch` (没装的话)
2. 拷贝 `bin/` 脚本到 `~/bin/`
3. 拷贝 `launchd/com.user.codex-clipprep.plist` 到 `~/Library/LaunchAgents/` (替换 `$HOME`)
4. 拷贝 `workflow/Compress for Codex.workflow/` 到 `~/Library/Services/` (替换 `$HOME`)
5. `launchctl load -w` 加载 LaunchAgent
6. 改 CC Switch SQLite (`meta.apiFormat = "openai_responses"`) 并自动备份
7. 给 `~/.zshrc` 加 shell aliases

幂等 —— 重复跑安全。

## 使用

装好后全程无感:

- **截图 → 粘到 Codex**: LaunchAgent 每 2 秒检测剪贴板, > 2MB 就自动压缩写回, 你 ⌘V 就行
- **Finder 右键**: 右键任意图片 → **Quick Actions → Compress for Codex**,原地覆盖
- **命令行手动**:
  ```bash
  prep-clip             # 压缩当前剪贴板的图
  prep-img ~/Desktop/big.png  # 压缩单个文件
  prep-watch ~/Desktop        # 监视目录,新截图自动压缩
  ```

## CC Switch 上游 issue

根因 (2013 被一律映射成"context window exceeds limit"不管实际是 context 还是 media) 是 CC Switch 错误包装器的 bug。我已经给 `farion1231/cc-switch` 提了 issue:  
**[Bug] Misleading "context window exceeds limit (2013)" when attaching images > 10MB to Codex** —— 完整文本见 [ISSUE.md](ISSUE.md) / [ISSUE.zh-CN.md](ISSUE.zh-CN.md)

这个 repo 独立存在是因为:
- 10MB 上限在 MiniMax 侧,CC Switch 绕不过
- 用户今天就需要 workaround,等不了上游发版

## 卸载

```bash
launchctl unload ~/Library/LaunchAgents/com.user.codex-clipprep.plist
rm -f ~/bin/codex-img-prep ~/bin/codex-clip-watch.sh
rm -f ~/Library/LaunchAgents/com.user.codex-clipprep.plist
rm -rf ~/Library/Services/Compress\ for\ Codex.workflow

# 还原 CC Switch apiFormat 到 openai_chat:
sqlite3 ~/.cc-switch/cc-switch.db \
  "UPDATE providers
   SET meta = json_set(meta, '\$.apiFormat', 'openai_chat')
   WHERE app_type='codex'"
osascript -e 'tell application "CC Switch" to quit' && open -a "CC Switch"

# 从 ~/.zshrc 删除 aliases (手动编辑)
```

`install.sh` 在 `~/.cc-switch/backups/manual/` 留的 db 备份保留,可以完整回滚。

## 文件清单

- [bin/codex-img-prep](bin/codex-img-prep) —— 缩图脚本 (bash + `sips`)
- [bin/codex-clip-watch.sh](bin/codex-clip-watch.sh) —— 剪贴板守护 (bash + `pngpaste`)
- [launchd/com.user.codex-clipprep.plist](launchd/com.user.codex-clipprep.plist) —— LaunchAgent 配置
- [workflow/Compress for Codex.workflow/](workflow/Compress%20for%20Codex.workflow/) —— Finder Quick Action
- [install.sh](install.sh) —— 本地一键安装
- [install-remote.sh](install-remote.sh) —— curl|bash 一行安装
- [cc-switch-fix.sql](cc-switch-fix.sql) —— SQLite 补丁 (独立运行)
- [ISSUE.md](ISSUE.md) / [ISSUE.zh-CN.md](ISSUE.zh-CN.md) —— CC Switch 上游 issue 正文 (英 / 中)

## 许可证

MIT —— 见 [LICENSE](LICENSE)。

## 作者

[Konsn666](https://github.com/Konsn666) —— 自己排查 Codex → CC Switch → MiniMax 发图失败时写的。