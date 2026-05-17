# Murmur

> [English version](./README.md)

**Murmur 是一个极简的 macOS 语音输入 app。** 按一下 **Right ⌘** 开始说话，再按一下，转写出的文字就粘到你光标所在的位置 —— 还可以选择让本机的 `claude` 或 `codex` CLI 先帮你润色一下。底部悬浮窗显示实时识别，自动适应字数。

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ 为什么选 Murmur

1. **没有月费。** 别人动辄每月 $10–20，Murmur 完全按需付费 —— 你用自己的 Soniox key，按说话时间计费（典型约 $0.05/小时）。
2. **开源 + 零数据存储。** MIT 协议，不存储任何用户信息，也不经过任何中间服务器，绝对安全。
3. **AI 润色不产生任何额外费用。** 直接调用本机已登录的 `claude` 或 `codex` CLI，复用你已有的订阅，Murmur 不在中间再加钱。
4. **支持暂停录音。** 录音中按空格暂停，再按空格继续；可以暂停多次，socket 超时也会自动 reconnect。
5. **实时语音识别。** 说话的同时，悬浮窗里实时显示识别结果。

---

## 🎯 核心特性

1. **实时语音识别**（Soniox WebSocket，约 500ms 首字延迟）
2. **AI 润色** —— 按 Alt 触发本机 `claude` / `codex` CLI 去除赘词，prompt 可自定义
3. **多语言识别** —— 设置页可多选 18 种语言
4. **声纹开关** —— 开启后以第一位说话者的声纹为锁定基准，其他人的声音不会被录入，有效避免旁人干扰
5. **断点续录** —— 随时暂停、随时继续，多次暂停也支持，已识别文字不丢

---

## ⌨️ 快捷键

| 按键 | 行为 |
|---|---|
| **Right ⌘** | 开始录音 → 停止 + 粘贴 → 在 reviewing 状态下提交当前文本 |
| **Alt** | 录音中 → 停止 + 用 LLM 润色；review 中 → 切换原文 ↔ 润色版 |
| **Space** | 录音中 → 暂停；暂停中 → 继续录音（socket 超时会自动重连续录） |
| **Esc** | 任意状态下取消，不插入任何内容 |

---

## ⚡ 快速安装

**前置依赖**

- macOS 13+，Apple Silicon
- Xcode CommandLine Tools（`xcode-select --install`）
- [Soniox](https://soniox.com) 账号 + API key（小额免费额度，之后按用量付费）
- *可选* —— [`claude`](https://claude.com/claude-code) 或 `codex` CLI 已安装并登录（仅润色功能需要；基础录音不需要）

**1 · 构建**

```bash
git clone https://github.com/xwEric/murmur
cd murmur
./build.sh                  # swiftc + ad-hoc codesign + bundle（约 3 秒）
open build/Murmur.app
```

**2 · 首次运行设置**（一次性）

启动后菜单栏会出现 🍌 小香蕉。第一次运行时：

1. **麦克风权限** —— 系统弹窗，点 **允许**
2. **辅助功能权限** —— 菜单栏 🍌 → *"打开辅助功能设置"* → 把 `Murmur.app` 加入列表并打开开关
3. **退出并重新启动 Murmur**（macOS 会重新校验签名，权限需要重启才生效）
4. 打开设置（菜单栏 🍌 → *"设置…"*）粘贴你的 Soniox API key

**3 · 开始使用**

把光标放进系统中任意输入框（备忘录、Slack、浏览器、终端 —— 哪里都行），然后：

- 按 **Right ⌘** → 说话 → 再按 **Right ⌘** → 文字粘到光标位置
- 按 **Right ⌘** → 说话 → 按 **Alt** → AI 润色 → 按 **Right ⌘** 插入润色版
- 录音中按 **Space** 暂停；再按 **Space** 继续
- 任意状态按 **Esc** 取消，不插入任何内容

**注意事项**

- 如果你重新编译过源码，ad-hoc 签名的 binary hash 会变，**macOS 会撤销权限** —— 需要重新到辅助功能里把 Murmur 加上、麦克风再授权一次。停止改代码后就不再有这个问题。
- 第一次录音的 WebSocket 启动会多几百毫秒，之后都是即时的。
- AI 润色需要 `claude` 或 `codex` CLI 提前登录好，Murmur 自己不管 CLI 的登录流程。

---

## 💡 核心理念

**只为我说过的每一句话付钱。** 没有月费，音频从你的电脑直接送到 Soniox（用你自己的 key），AI 润色经过你已登录的本机 CLI —— Murmur 只是把这些服务串起来的最薄一层。

---

## ⚙️ 配置

配置文件位于 `~/.claude-profile/dictate/config.json`：

```json
{
  "soniox_api_key": "YOUR_KEY_FROM_console.soniox.com",
  "model": "stt-rt-preview",
  "language_hints": ["zh", "en"],
  "polish_backend": "claude",
  "polish_model": "sonnet",
  "polish_prompt": "",
  "speaker_lock": false
}
```

| 字段 | 默认 | 说明 |
|---|---|---|
| `soniox_api_key` | — | 从 [console.soniox.com](https://console.soniox.com) 拿 |
| `model` | `stt-rt-preview` | Soniox 实时模型名 |
| `language_hints` | `["zh","en"]` | 识别语言列表（影响识别质量） |
| `polish_backend` | `claude` | `claude` 或 `codex` |
| `polish_model` | `sonnet` | claude: `sonnet`/`haiku`/`opus`；codex: `gpt-5-codex` 等 |
| `polish_prompt` | `""` | 空字符串 = 使用内置 prompt；非空 = 你自定义的 prompt |
| `speaker_lock` | `false` | 实验功能 — 锁定第一个识别到的说话人，过滤其他人 |

---

## 🧱 项目结构

```
~/code/dictate/
├── Sources/                       # 13 个 Swift 文件
│   ├── main.swift                 # @main 入口
│   ├── AppDelegate.swift          # 主控制器 + 状态机
│   ├── AppState.swift             # idle / recording / paused / finalizing / polishing / reviewing
│   ├── HotkeyMonitor.swift        # CGEventTap — Right ⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift        # AVAudioEngine → 16 kHz mono PCM16
│   ├── SonioxClient.swift         # WebSocket 客户端 + 声纹过滤 + 断点续录
│   ├── Polisher.swift             # 派生 claude / codex CLI 做润色
│   ├── TextInjector.swift         # 剪贴板 + 模拟 ⌘V + 焦点恢复
│   ├── SoundPlayer.swift          # 提示音
│   ├── LiveTextWindow.swift       # 底部悬浮窗（自适应高度 + 字体）
│   ├── SettingsWindow.swift       # 设置面板
│   ├── PlaceholderTextView.swift  # 带 placeholder 的 NSTextView
│   ├── Config.swift               # JSON 配置读写
│   └── Strings.swift              # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png              # app icon 源图
│   ├── menubar_banana.png         # 菜单栏 template 图标
│   └── start.mp3 / end.mp3
└── build.sh                       # swiftc + codesign + bundle
```

---

## 🛠️ 设计取舍

- **`swiftc` 直接编译**而非 Xcode 工程 — 单文件无依赖，CI 友好
- **临时剪贴板粘贴**而非逐字符模拟键盘 — 速度快、中文/Emoji 兼容、350 ms 后自动恢复原剪贴板
- **`CGEventTap` 监听全局 hotkey** — 唯一能区分左/右 Command 的 API（用 device-dependent flag bit `0x10`）
- **Esc 选择性消费** — phase ≠ idle 时拦截，其他时候透传，不破坏其他 app 的快捷键
- **NSVisualEffectView 用 9-slice `maskImage`** — 圆角和窗口阴影完美对齐，不露出矩形外框

---

## 🤝 欢迎贡献

Murmur 故意写得很小。最适合扩展的几个点：

- **`SonioxClient.swift`** — 把 Soniox 换成其他实时 STT（AssemblyAI、Deepgram、OpenAI Realtime 等）
- **`Polisher.swift`** — 加新 LLM 后端。现在有 `claude`（Anthropic）和 `codex`（OpenAI）两个，加 Gemini 或本地 Ollama 大概 30 行代码
- **`Strings.swift`** — 加更多 UI 语言

大改动先开 issue，小改直接 PR。

---

## ❓ 已知限制

- ad-hoc codesign 每次 rebuild CDHash 都变，TCC 权限会被撤销 — 开发中正常，发布前用稳定签名身份解决
- Soniox 实时 API 需要付费账号（有免费额度）
- 仅支持 Apple Silicon（如需 Intel，改 `build.sh` 加 `-target x86_64-apple-macos13.0`）

---

## 📜 许可

MIT
