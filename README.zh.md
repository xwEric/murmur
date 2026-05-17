# Murmur

> 极简、原生、可润色的 macOS 语音输入工具。
>
> Read this in [English](./README.en.md).

按一下右 ⌘ 录音，再按一下把转写文本插入到当前光标位置。可选用 Claude/Codex AI 一键润色。底部悬浮窗实时显示识别结果，支持中英文混合 + 16 种其他语言。

整个 app 只有 12 个 Swift 文件 + 1 个 build 脚本，单 binary 无依赖。

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ 为什么选 Murmur

**对比 Spokenly / Wispr Flow / SuperWhisper 等订阅制工具**：

| 维度 | 订阅制工具 | **Murmur** |
|---|---|---|
| 💸 **费用** | $7–15 / 月起 | **$0 月费**，按需付费给 Soniox（约 $0.05–0.10/小时）|
| 🤖 **AI 润色** | 内置模型，含在订阅里（受限） | 调用你**本机已登录的** `claude` / `codex` CLI —— **不消耗额外 token / 不另外计费**，完全复用你现有的 Claude Code / OpenAI Plus 订阅 |
| ⏸️ **暂停录音** | 一般不支持，断流就丢词 | **支持暂停 / 恢复**，socket 超时自动 reconnect，**已录文字不丢**，新识别接在后面 |
| 🎨 **润色 prompt** | 黑盒 | **完全自定义** prompt（设置页有 placeholder 默认值，留空走默认） |
| 🔓 **数据流向** | 经过厂商服务器 | 音频直接送 Soniox；润色经你本机 CLI；**没有中间代理** |
| 💻 **代码** | 闭源 | **开源 MIT**，单文件 swiftc 编译，看完所有源码 30 分钟 |
| 📦 **体积** | 30–80 MB 安装包 | **单 binary ~200 KB**，零运行时依赖 |

> 💡 **核心理念**：你已经为 Claude Code 或 OpenAI 付了月费，没必要再为一个"语音输入 wrapper"多交一份钱。Murmur 把这些工具串起来，自己只做最薄的一层。

---

## 🎯 核心特性

| 快捷键 | 行为 |
|---|---|
| **Right ⌘** | 开始录音 / 停止 + 直接粘贴 / 在 reviewing 状态下插入当前文本 |
| **Alt** | 录音中 → 停止 + 用 LLM 润色；reviewing 中 → 切换原文/润色版 |
| **Space** | 录音中 → 暂停；暂停中 → 继续录音（socket 超时会自动重连续录） |
| **Esc** | 任意状态下取消，不插入任何内容 |

- 🎙️ **Soniox 实时 WebSocket STT**，PCM 16k mono，低延迟
- ✨ **Claude / Codex 润色**：默认 Sonnet 4.6，可在设置页改后端和模型
- 🌐 **18 种语言识别**，多选 checkbox，默认中英
- 🪟 **底部悬浮窗**：从 1 行到 4 行自适应，字体 18→10 pt 自动缩放，超长头部省略
- 🔒 **声纹锁定开关**（实验，默认关）：基于 Soniox 在线说话人聚类，过滤其他人说话
- 🎯 **焦点恢复**：录音中切窗口、再按右⌘，文字仍会粘到**原本**的输入框
- 🔁 **断点续录**：暂停时 socket 超时不再丢文字；继续录音时 reconnect，新识别接在已有文本后
- ⚡ **非阻塞权限检测**：录音立刻开始，麦克风权限在背景并发检测，没权限才弹窗
- 🍌 **菜单栏 template 图标**，深/浅模式自动适配

---

## 📦 构建

```bash
git clone <your-fork-url>
cd dictate
./build.sh         # swiftc + ad-hoc codesign + bundle
open build/Murmur.app
```

要求：macOS 13+，Xcode CommandLine Tools (`xcode-select --install`)。

无外部 Swift 依赖。

---

## ⚙️ 配置

App 启动后从 `~/.claude-profile/dictate/config.json` 读配置。第一次启动会自动弹设置页。

也可手动写入：

```bash
mkdir -p ~/.claude-profile/dictate
cat > ~/.claude-profile/dictate/config.json <<'EOF'
{
  "soniox_api_key": "YOUR_KEY_FROM_console.soniox.com",
  "model": "stt-rt-preview",
  "language_hints": ["zh", "en"],
  "polish_backend": "claude",
  "polish_model": "sonnet",
  "polish_prompt": "",
  "speaker_lock": false
}
EOF
chmod 600 ~/.claude-profile/dictate/config.json
```

字段说明：

| 字段 | 默认 | 说明 |
|---|---|---|
| `soniox_api_key` | — | 从 [console.soniox.com](https://console.soniox.com) 拿 |
| `model` | `stt-rt-preview` | Soniox 实时模型名 |
| `language_hints` | `["zh","en"]` | 识别语言列表（影响识别质量） |
| `polish_backend` | `claude` | `claude` 或 `codex` |
| `polish_model` | `sonnet` | claude: `sonnet`/`haiku`/`opus`；codex: `gpt-5-codex` 等 |
| `polish_prompt` | `""` | 空字符串 = 使用内置 prompt；非空 = 自定义 |
| `speaker_lock` | `false` | 开启 = 锁定第一个出现的 speaker token，过滤其他人 |

**润色后端需要预装**：
- `claude` CLI（[Claude Code](https://claude.com/claude-code)）— 需登录
- 或 `codex` CLI — 需登录

---

## 🚀 首次运行

1. 启动 Murmur.app
2. 麦克风权限弹窗 → **允许**
3. 辅助功能权限：菜单 → "打开辅助功能设置" → 把 Murmur 加入列表并打开开关
4. 关闭并重新打开 Murmur（CDHash 校验生效）
5. 打开任意文本输入框，按右⌘ 开始

---

## 🧱 项目结构

```
~/code/dictate/
├── Sources/
│   ├── main.swift              # @main 入口
│   ├── AppDelegate.swift       # 主控制器 + 状态机
│   ├── AppState.swift          # idle/recording/paused/finalizing/polishing/reviewing
│   ├── HotkeyMonitor.swift     # CGEventTap，监听右⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift     # AVAudioEngine → 16kHz mono PCM16
│   ├── SonioxClient.swift      # WebSocket 客户端 + 声纹过滤 + 断点续录
│   ├── Polisher.swift          # 派生 claude / codex CLI 做润色
│   ├── TextInjector.swift      # 剪贴板 + 模拟 Cmd+V + 焦点恢复
│   ├── SoundPlayer.swift       # Spokenly 同款 start.mp3 / end.mp3
│   ├── LiveTextWindow.swift    # 底部悬浮窗（自适应高度 + 字体）
│   ├── SettingsWindow.swift    # 设置面板
│   ├── PlaceholderTextView.swift  # 带 placeholder 的 NSTextView
│   ├── Config.swift            # JSON 配置读写
│   └── Strings.swift           # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png           # app icon 源图
│   ├── menubar_banana.png      # 菜单栏 template 图标
│   ├── start.mp3 / end.mp3
└── build.sh                    # swiftc + codesign + bundle
```

---

## 🛠️ 设计取舍

- **`swiftc` 直接编译**而非 Xcode 工程 — 单文件无依赖，CI 友好
- **临时剪贴板粘贴**而非逐字符模拟键盘 — 速度快、中文/Emoji 兼容、自动恢复原剪贴板
- **`CGEventTap` 监听全局 hotkey** — 唯一能区分左/右 Command 的 API（用 device-dependent flag bit `0x10`）
- **润色 prompt 走 system prompt**，CLI 配合 `--output-format text` 拿纯净结果
- **Esc 选择性消费**：phase ≠ idle 时拦截，其他时候透传，不破坏其他 app 的快捷键

---

## ❓ 已知限制

- ad-hoc codesign 每次 rebuild CDHash 都变，TCC 权限会被撤销 — 开发中正常，发布前用稳定签名身份解决
- Soniox 实时 API 需要付费账号（有免费额度）
- 仅支持 Apple Silicon（如需 Intel，改 `build.sh` 加 `-target x86_64-apple-macos13.0`）
- 单人录音场景；多人同时说话依赖 Soniox 服务端 diarization 准确度（可在设置开启实验）

---

## 📜 许可

MIT
