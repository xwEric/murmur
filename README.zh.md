# Murmur

> [English version](./README.md)

**Murmur 是一个极简的 macOS 语音输入 app。** 按一下 **Right ⌘** 开始说话，再按一下，转写出的文字就粘到你光标所在的位置 —— 还可以选择让本机的 `claude` 或 `codex` CLI 先帮你润色一下。底部悬浮窗显示实时识别，自动适应字数。

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ 为什么选 Murmur

1. **没有月费。** 别人动辄每月 $10–20，Murmur 完全按需付费 —— 你用自己的 API key，按用量计费。
2. **开源 + 零数据存储。** MIT 协议，不存储任何用户信息，也不经过任何中间服务器，绝对安全。
3. **AI 润色不产生任何额外费用。** 直接调用本机已登录的 `claude` 或 `codex` CLI，复用你已有的订阅，Murmur 不在中间再加钱。
4. **支持暂停录音。** 录音中按空格暂停，再按空格继续；可以暂停多次，socket 超时也会自动 reconnect。
5. **实时语音识别。** 说话的同时，悬浮窗里实时显示识别结果。

---

## 🎯 核心特性

1. **实时语音识别** — 多个 provider 可选：**Soniox**、**Deepgram Nova-3**、**OpenAI Realtime (gpt-4o-mini-transcribe)**，或任何 **OpenAI 兼容**自定义端点
2. **AI 润色** — 按 Alt 触发本机 `claude` / `codex` CLI 去除赘词，prompt 可自定义
3. **多语言识别** — 设置页可多选 18 种语言
4. **声纹开关**（仅 Soniox）— 开启后以第一位说话者的声纹为锁定基准，其他人的声音不会被录入，有效避免旁人干扰
5. **断点续录** — 随时暂停、随时继续，多次暂停也支持，已识别文字不丢

---

## ⌨️ 快捷键

| 按键 | 行为 |
|---|---|
| **Right ⌘** | 开始录音 → 停止 + 粘贴 → 在 reviewing 状态下提交当前文本 |
| **Alt** | 录音中 → 停止 + 用 LLM 润色；review 中 → 切换原文 ↔ 润色版 |
| **Space** | 录音中 → 暂停；暂停中 → 继续录音（socket 超时会自动重连续录） |
| **Esc** | 任意状态下取消，不插入任何内容 |

---

## 🔑 获取 API key（任选一家）

只需要 **任意一家** provider 的 key 就能用，可以在 Settings 里随时切换。

### Soniox（默认，多语言最好）

1. 去 [console.soniox.com](https://console.soniox.com) 注册（Google 登录可用）
2. 注册有免费额度，之后 ~$0.04 / 分钟音频
3. **Settings → API Keys → Create new key** → 复制
4. Murmur 设置 → 识别引擎 → Soniox → 粘贴

### Deepgram Nova-3（快、英文优化）

1. 去 [console.deepgram.com](https://console.deepgram.com) 注册
2. 新账号送 $200 免费额度（够用很久）
3. **API Keys → Create a New API Key** → 角色选 *Member* → 复制
4. Murmur 设置 → 识别引擎 → Deepgram → 粘贴

### OpenAI Realtime (gpt-4o-mini-transcribe)

1. 去 [platform.openai.com/api-keys](https://platform.openai.com/api-keys) 创建 key
2. 确认账户开通了 Realtime API 访问（大多付费账户都有）
3. Murmur 设置 → 识别引擎 → OpenAI Realtime → 粘贴
4. 默认模型是 `gpt-4o-mini-transcribe`；可选 `gpt-4o-transcribe` 质量更高

### 自定义（OpenAI 兼容）

适合 Azure OpenAI、自建 vLLM、或任何实现了 OpenAI Realtime API 的服务：

1. Murmur 设置 → 识别引擎 → 自定义
2. **Base URL**：`wss://your-host/v1/realtime?intent=transcription`（按你的服务商）
3. **API Key**：服务商在 `Authorization: Bearer` header 里期望的值
4. **模型名称**：会作为 `transcription_session.update` 的 model 字段发出去

---

## ⚡ 快速安装

**前置依赖**

- macOS 13+，Apple Silicon
- Xcode CommandLine Tools（`xcode-select --install`）
- 以上任一 provider 的 API key
- *可选* —— [`claude`](https://claude.com/claude-code) 或 `codex` CLI 已安装并登录（仅润色功能需要；基础录音不需要）

**1 · 构建**

```bash
git clone https://github.com/xwEric/murmur
cd murmur
./build.sh                  # swiftc + ad-hoc codesign + bundle（约 3 秒）
open build/Murmur.app
```

**2 · 首次运行设置**（一次性）

启动后菜单栏会出现六边形小图标。第一次运行时：

1. **麦克风权限** —— 系统弹窗，点 **允许**
2. **辅助功能权限** —— 菜单栏图标 → *"打开辅助功能设置"* → 把 `Murmur.app` 加入列表并打开开关
3. **退出并重新启动 Murmur**（macOS 会重新校验签名，权限需要重启才生效）
4. 打开设置（菜单栏图标 → *"设置…"*）→ 识别引擎 → 粘贴你的 API key

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

**只为我说过的每一句话付钱。** 没有月费，音频从你的电脑直接送到你选的 STT provider（用你自己的 key），AI 润色经过你已登录的本机 CLI —— Murmur 只是把这些服务串起来的最薄一层。

---

## ⚙️ 配置

配置文件位于 `~/.claude-profile/dictate/config.json`。基本上都能在设置页面里改，但也可以直接编辑：

```json
{
  "stt_provider": "soniox",

  "soniox_api_key": "...",
  "soniox_model": "stt-rt-preview",

  "deepgram_api_key": "...",
  "deepgram_model": "nova-3",

  "openai_api_key": "...",
  "openai_model": "gpt-4o-mini-transcribe",

  "custom_base_url": "",
  "custom_api_key": "",
  "custom_model": "",

  "language_hints": ["zh", "en"],
  "polish_backend": "claude",
  "polish_model": "sonnet",
  "polish_prompt": "",
  "speaker_lock": false
}
```

| 字段 | 说明 |
|---|---|
| `stt_provider` | `soniox` \| `deepgram` \| `openai` \| `custom` |
| `*_api_key` / `*_model` | 每个 provider 自己的 key + model；只有当前激活的那组生效 |
| `custom_base_url` | OpenAI-Realtime 兼容的 WSS 端点（仅当 `stt_provider=custom` 时使用）|
| `language_hints` | 识别语言列表；Deepgram 选多于一种会自动切到 multi 模式 |
| `polish_backend` | `claude` 或 `codex` |
| `polish_prompt` | 空字符串 = 使用内置默认；非空 = 你自定义的 system prompt |
| `speaker_lock` | 实验功能，仅 Soniox —— 锁定第一个识别到的说话人 |

---

## 🧱 项目结构

```
~/code/dictate/
├── Sources/                       # 18 个 Swift 文件
│   ├── main.swift                 # @main 入口
│   ├── AppDelegate.swift          # 主控制器 + 状态机
│   ├── AppState.swift             # idle / recording / paused / finalizing / polishing / reviewing
│   ├── HotkeyMonitor.swift        # CGEventTap — Right ⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift        # AVAudioEngine → 16 kHz mono PCM16
│   ├── STTClient.swift            # 流式 STT 后端的协议
│   ├── STTClientFactory.swift     # 按 config 选择对应的 client
│   ├── SonioxClient.swift         # Soniox 实时 WebSocket
│   ├── DeepgramClient.swift       # Deepgram Nova-3 WebSocket
│   ├── OpenAIRealtimeClient.swift # OpenAI Realtime (gpt-4o-mini-transcribe)
│   ├── CustomSTTClient.swift      # OpenAI 兼容自定义端点
│   ├── Polisher.swift             # 派生 claude / codex CLI 做润色
│   ├── TextInjector.swift         # 剪贴板 + 模拟 ⌘V + 焦点恢复
│   ├── SoundPlayer.swift          # 提示音
│   ├── LiveTextWindow.swift       # 底部悬浮窗（自适应高度 + 字体 + 滚动）
│   ├── SettingsWindow.swift       # Sidebar 设置（通用 / 识别引擎 / 润色）
│   ├── PlaceholderTextView.swift  # 带 placeholder 的 NSTextView
│   ├── Config.swift               # JSON 配置读写
│   └── Strings.swift              # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png              # 蜂窝六边形 app icon
│   ├── menubar_banana.png         # 菜单栏 template（历史文件名）
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
- **STT 后端走 `STTClient` 协议** — 每家 provider 是一个独立文件，加新 provider 只需一个文件 + factory 一行

---

## 🤝 欢迎贡献

Murmur 故意写得很小。最适合扩展的几个点：

- **新 STT provider** — 新建一个文件实现 `STTClient`，在 `STTClientFactory` 加一个 case。`DeepgramClient.swift` 是最简单的模板。
- **新润色 LLM** — 在 `Polisher.swift` 里加一个 backend。现在有 `claude`（Anthropic）和 `codex`（OpenAI）两个，加 Gemini 或本地 Ollama 大概 30 行代码。
- **更多 UI 语言** — 在 `Strings.swift` 里加翻译。

大改动先开 issue，小改直接 PR。

---

## ❓ 已知限制

- ad-hoc codesign 每次 rebuild CDHash 都变，TCC 权限会被撤销 — 开发中正常，发布前用稳定签名身份解决
- 每个 STT provider 需要自己的 API key；**任选一家**即可
- 仅支持 Apple Silicon（如需 Intel，改 `build.sh` 加 `-target x86_64-apple-macos13.0`）

---

## 📜 许可

MIT
