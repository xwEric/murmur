# Murmur

> [English version](./README.md)

**Murmur 是一个极简的 macOS 语音输入 app。** 按一下 **Right ⌘** 开始说话，再按一下，转写出的文字就粘到你光标所在的位置 —— 还可以选择让本机的 `claude` 或 `codex` CLI 先帮你润色一下。底部悬浮窗显示实时识别，自动适应字数。

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## 💡 核心理念

**只为我说过的每一句话付钱。**

没有月费，没有订阅。Murmur 用你自己的 API key 直接连 [Soniox](https://soniox.com)，**典型成本是每小时语音约 $0.05**。不说话不花钱。

AI 润色（可选）直接调用本机已登录的 `claude` 或 `codex` CLI —— 你本来给这两个工具付的费用就是全部，**Murmur 不在中间再加一份**。

整个产品的定位就这一句：在你已经选择的服务上加一层很薄的原生外壳，按用量计费。

---

## 🌟 你能拿到什么

- ⚡ **实时流式转写**（Soniox WebSocket）—— 首字延迟约 500 ms
- ✨ **AI 润色不另收费** —— 按 Alt 让本机 `claude` / `codex` CLI 去除赘词修语病；润色 prompt 可在设置页完全自定义
- ⏸️ **暂停 / 继续** —— 录音中按空格暂停，socket 即便超时断开，再按空格会自动 reconnect，**已识别的文字不会丢**，新文字接在后面
- 🪶 **极致轻量 + 快** —— 单个 200 KB 的 binary，零 Swift 依赖，13 个源文件，半小时能读完
- 🌐 **18 种识别语言** —— 多选 checkbox，默认中 + 英
- 🎯 **焦点恢复** —— 录音中切到别的窗口也没关系，按 Right ⌘ 文字仍然粘到**原本**那个输入框
- 🌓 **主题自适应** —— 悬浮窗 + 菜单栏图标会跟随系统深/浅模式（NSVisualEffectView + template image）

> 想加入其他 STT API 或 LLM 后端？`SonioxClient.swift` 和 `Polisher.swift` 是有意写得很薄的 adapter —— **欢迎提 issue 或者直接 PR**。

---

## ⌨️ 快捷键

| 按键 | 行为 |
|---|---|
| **Right ⌘** | 开始录音 → 停止 + 粘贴 → 在 reviewing 状态下提交当前文本 |
| **Alt** | 录音中 → 停止 + 用 LLM 润色；review 中 → 切换原文 ↔ 润色版 |
| **Space** | 录音中 → 暂停；暂停中 → 继续录音（socket 超时会自动重连续录） |
| **Esc** | 任意状态下取消，不插入任何内容 |

---

## 📦 构建

```bash
git clone <your-fork-url>
cd murmur
./build.sh         # swiftc + ad-hoc codesign + bundle
open build/Murmur.app
```

要求：macOS 13+，Xcode CommandLine Tools (`xcode-select --install`)。无任何外部 Swift 依赖。

---

## ⚙️ 配置

App 第一次启动会自动弹出设置页。配置文件位于 `~/.claude-profile/dictate/config.json`：

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

**润色后端依赖**：`claude` CLI（[Claude Code](https://claude.com/claude-code)）或 `codex` CLI，需登录。

---

## 🚀 首次运行

1. 启动 Murmur.app
2. **麦克风**权限弹窗 → 允许
3. **辅助功能**：菜单 → "打开辅助功能设置" → 把 Murmur 加入并打开开关
4. 退出并重新打开 Murmur（让 macOS 重新校验 CDHash）
5. 打开任意文本输入框，按右⌘ 开始说话

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
- **润色 prompt 走 `--system-prompt`**，CLI 配合 `--output-format text` 拿纯净结果
- **Esc 选择性消费** — phase ≠ idle 时拦截，其他时候透传，不破坏其他 app 的快捷键
- **NSVisualEffectView 用 9-slice `maskImage`** — 让圆角和窗口阴影完美对齐，不再露出矩形外框

---

## 🤝 欢迎贡献

Murmur 故意写得很小。最适合扩展的几个点：

- **`SonioxClient.swift`** — 把 Soniox 换成其他实时 STT（AssemblyAI、Deepgram、OpenAI Realtime 等等）。结构很简单：发配置 → 流 PCM → 拿 token。
- **`Polisher.swift`** — 加新 LLM 后端。现在有 `claude`（Anthropic）和 `codex`（OpenAI）两个，加个 `gemini` 或本地 `ollama` 大概 30 行代码。
- **`Strings.swift`** — 加更多 UI 语言。

大改动先开 issue，小改直接 PR。

---

## ❓ 已知限制

- ad-hoc codesign 每次 rebuild CDHash 都变，TCC 权限会被撤销 — 开发中很烦，发布前用稳定签名身份解决
- Soniox 实时 API 需要付费账号（有免费额度）
- 仅支持 Apple Silicon（如需 Intel，改 `build.sh` 加 `-target x86_64-apple-macos13.0`）
- 单人录音场景；多人同时说话依赖 Soniox 服务端 diarization 准确度（设置页可开启实验）

---

## 📜 许可

MIT
