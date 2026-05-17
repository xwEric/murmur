# Murmur

> Minimalist native macOS voice-to-text with optional AI polish.
>
> [中文版本](./README.md)

Press Right ⌘ to start recording. Press it again to paste the transcription at the cursor. Optionally use Claude/Codex to polish the text first. A bottom-center floating overlay shows live transcription with adaptive sizing.

Twelve Swift files, one build script, a single binary, zero dependencies.

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ Why Murmur

**Compared to Spokenly / Wispr Flow / SuperWhisper and other subscription tools:**

| Aspect | Subscription tools | **Murmur** |
|---|---|---|
| 💸 **Cost** | $7–15 / month | **$0/month**, pay-as-you-go to Soniox (≈ $0.05–0.10/hr) |
| 🤖 **AI polish** | Built-in model, capped by your subscription tier | Calls your **locally-installed** `claude` / `codex` CLI — **no extra tokens, no extra billing**, fully reuses your existing Claude Code / OpenAI Plus subscription |
| ⏸️ **Pause recording** | Usually unsupported — drops words on disconnect | **Pause & resume**, auto-reconnects on socket timeout, **previously transcribed text is preserved** and new recognition appends |
| 🎨 **Polish prompt** | Black box | **Fully customizable** prompt (default shown as placeholder; leave empty to fall back) |
| 🔓 **Data flow** | Through vendor servers | Audio goes straight to Soniox; polish runs through your local CLI; **no middleware in between** |
| 💻 **Code** | Closed source | **MIT open source**, single-file swiftc compile, read all the sources in 30 minutes |
| 📦 **Binary size** | 30–80 MB installer | **Single binary ~200 KB**, zero runtime deps |

> 💡 **Philosophy**: You already pay for Claude Code or OpenAI. No reason to pay another monthly fee to a wrapper. Murmur stitches these tools together and keeps the layer paper-thin.

---

## 🎯 Core features

| Key | Action |
|---|---|
| **Right ⌘** | Start recording / stop & paste / commit text in review state |
| **Alt** | During recording → stop & polish; in review → toggle original/polished |
| **Space** | Recording → pause; paused → resume (auto-reconnect if socket timed out) |
| **Esc** | Cancel anywhere — discard without inserting |

- 🎙️ **Soniox real-time WebSocket STT** — PCM 16 kHz mono, low latency
- ✨ **Claude / Codex polish** — defaults to Sonnet 4.6; backend + model configurable
- 🌐 **18 recognition languages**, multi-select checkboxes
- 🪟 **Bottom-center overlay** — adapts from 1 to 4 lines, font shrinks 18 → 10 pt as text grows, head-truncates beyond capacity
- 🔒 **Speaker lock toggle** (experimental, off by default) — Soniox-side diarization to ignore other voices
- 🎯 **Focus restoration** — switch windows mid-recording, press Right ⌘, text still lands in the *original* text field
- 🔁 **Resume after socket timeout** — when paused, if the WebSocket drops, the next press of Space reconnects and the new transcript is appended to what was already there
- ⚡ **Non-blocking permission checks** — recording starts immediately; mic perm is verified in parallel and aborts only if denied
- 🍌 **Menu bar template icon** — auto-tinted for light/dark menu bars

---

## 📦 Build

```bash
git clone <your-fork-url>
cd dictate
./build.sh         # swiftc + ad-hoc codesign + bundle
open build/Murmur.app
```

Requirements: macOS 13+, Xcode CommandLine Tools (`xcode-select --install`).

No external Swift dependencies.

---

## ⚙️ Configuration

The app reads `~/.claude-profile/dictate/config.json` on launch. On first run, the Settings window opens automatically.

Or write the config manually:

```bash
mkdir -p ~/.claude-profile/dictate
cat > ~/.claude-profile/dictate/config.json <<'EOF'
{
  "soniox_api_key": "YOUR_KEY_FROM_console.soniox.com",
  "model": "stt-rt-preview",
  "language_hints": ["en", "zh"],
  "polish_backend": "claude",
  "polish_model": "sonnet",
  "polish_prompt": "",
  "speaker_lock": false
}
EOF
chmod 600 ~/.claude-profile/dictate/config.json
```

| Field | Default | Notes |
|---|---|---|
| `soniox_api_key` | — | From [console.soniox.com](https://console.soniox.com) |
| `model` | `stt-rt-preview` | Soniox real-time model name |
| `language_hints` | `["zh","en"]` | Languages to expect (improves accuracy) |
| `polish_backend` | `claude` | `claude` or `codex` |
| `polish_model` | `sonnet` | claude: `sonnet`/`haiku`/`opus`; codex: `gpt-5-codex` etc. |
| `polish_prompt` | `""` | Empty = use built-in default; non-empty = custom |
| `speaker_lock` | `false` | When on, locks to first-detected speaker, drops others |

**Polish backend prerequisites**:
- `claude` CLI ([Claude Code](https://claude.com/claude-code)) — must be logged in
- or `codex` CLI — must be logged in

---

## 🚀 First run

1. Launch Murmur.app
2. Approve the **Microphone** prompt
3. **Accessibility**: menu → "Open Accessibility Settings" → add Murmur and toggle on
4. Quit and relaunch Murmur (so the CDHash check picks it up)
5. Click any text field, press Right ⌘, speak

---

## 🧱 Project layout

```
~/code/dictate/
├── Sources/
│   ├── main.swift              # @main entry
│   ├── AppDelegate.swift       # controller + state machine
│   ├── AppState.swift          # idle/recording/paused/finalizing/polishing/reviewing
│   ├── HotkeyMonitor.swift     # CGEventTap — Right ⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift     # AVAudioEngine → 16kHz mono PCM16
│   ├── SonioxClient.swift      # WebSocket client + speaker filter + reconnect
│   ├── Polisher.swift          # spawns claude / codex CLI for polish
│   ├── TextInjector.swift      # clipboard + simulated Cmd+V + focus restore
│   ├── SoundPlayer.swift       # Spokenly-style start.mp3 / end.mp3
│   ├── LiveTextWindow.swift    # bottom-center overlay (adaptive height/font)
│   ├── SettingsWindow.swift    # settings panel
│   ├── PlaceholderTextView.swift  # NSTextView with placeholder
│   ├── Config.swift            # JSON config I/O
│   └── Strings.swift           # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png           # app icon source
│   ├── menubar_banana.png      # menu bar template
│   ├── start.mp3 / end.mp3
└── build.sh                    # swiftc + codesign + bundle
```

---

## 🛠️ Design choices

- **`swiftc` direct compile** instead of an Xcode project — single-source, no dependencies, CI-friendly
- **Clipboard paste** instead of synthesized typing — fast, CJK/emoji-safe, restores the original clipboard after 350 ms
- **`CGEventTap` for global hotkeys** — only API that can distinguish left vs right Command (via device-dependent flag bit `0x10`)
- **Polish prompt via `--system-prompt`**, `--output-format text` for clean output
- **Selective Esc consumption** — intercepted only while overlay is up, passes through otherwise

---

## ❓ Known limitations

- Ad-hoc codesign changes the CDHash on every rebuild, which revokes TCC permissions — fine during development, use a stable signing identity for release
- Soniox real-time API requires a paid account (free tier available)
- Apple Silicon only (add `-target x86_64-apple-macos13.0` in `build.sh` for Intel)
- Single-speaker use case; for multi-speaker, rely on Soniox server-side diarization (toggle in Settings — accuracy varies)

---

## 📜 License

MIT
