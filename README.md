# Murmur

> [中文版本](./README.zh.md)

**Murmur is a minimalist macOS voice-dictation app.** Press **Right ⌘** to speak, press it again, and your transcription is pasted at the cursor — optionally polished by your local Claude or Codex CLI first. A bottom-center overlay shows the live transcript with adaptive sizing.

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## 💡 The core idea

**Pay only for the words you actually speak.**

No monthly subscription. Murmur talks to [Soniox](https://soniox.com) directly with your own API key — typical cost is around **$0.05/hour of speech**. If you don't dictate, you don't pay.

AI polish (optional) is done by spawning your local `claude` or `codex` CLI. Whatever you're already paying those for, that's it — Murmur adds nothing on top.

That's the whole pitch: a thin native layer over services you choose, billed by use.

---

## 🌟 What you actually get

- ⚡ **Real-time streaming transcription** via Soniox WebSocket — first words appear within ~500 ms
- ✨ **Optional AI polish at no extra cost** — your local `claude` / `codex` CLI cleans up filler words and stutters when you press Alt; the polish prompt is fully customizable in Settings
- ⏸️ **Pause & resume** — press Space mid-recording; if the WebSocket times out while you're paused, Murmur auto-reconnects and the new transcript is appended to what you already have, **nothing is lost**
- 🪶 **Lightweight & fast** — single 200 KB binary, zero Swift dependencies, twelve source files. Reads in 30 minutes.
- 🌐 **18 recognition languages** — multi-select; default zh + en
- 🎯 **Focus restoration** — switch windows mid-recording; pressing Right ⌘ still pastes into the *original* text field
- 🌓 **Auto-themed** — overlay and menu bar icon adapt to system light/dark mode (NSVisualEffectView + template image)

> Want another STT API or LLM backend? `SonioxClient.swift` and `Polisher.swift` are intentionally short adapters — **open an issue or send a PR**, contributions welcome.

---

## ⌨️ Hotkeys

| Key | Action |
|---|---|
| **Right ⌘** | Start recording → stop & paste → commit text in review state |
| **Alt** | During recording → stop & polish; in review → toggle original ↔ polished |
| **Space** | Recording → pause; paused → resume (auto-reconnects on socket timeout) |
| **Esc** | Cancel anywhere — discard without inserting |

---

## 📦 Build

```bash
git clone <your-fork-url>
cd murmur
./build.sh         # swiftc + ad-hoc codesign + bundle
open build/Murmur.app
```

Requirements: macOS 13+, Xcode CommandLine Tools (`xcode-select --install`). No external Swift dependencies.

---

## ⚙️ Configuration

Settings opens automatically on first launch. The config lives at `~/.claude-profile/dictate/config.json`:

```json
{
  "soniox_api_key": "YOUR_KEY_FROM_console.soniox.com",
  "model": "stt-rt-preview",
  "language_hints": ["en", "zh"],
  "polish_backend": "claude",
  "polish_model": "sonnet",
  "polish_prompt": "",
  "speaker_lock": false
}
```

| Field | Default | Notes |
|---|---|---|
| `soniox_api_key` | — | From [console.soniox.com](https://console.soniox.com) |
| `model` | `stt-rt-preview` | Soniox real-time model name |
| `language_hints` | `["zh","en"]` | Languages to expect (improves accuracy) |
| `polish_backend` | `claude` | `claude` or `codex` |
| `polish_model` | `sonnet` | claude: `sonnet`/`haiku`/`opus`; codex: `gpt-5-codex` etc. |
| `polish_prompt` | `""` | Empty = built-in default; non-empty = your custom prompt |
| `speaker_lock` | `false` | Experimental — locks to first-detected speaker via Soniox diarization |

**Polish prerequisites**: either `claude` ([Claude Code](https://claude.com/claude-code)) or `codex` CLI installed and logged in.

---

## 🚀 First run

1. Launch Murmur.app
2. Approve the **Microphone** prompt
3. **Accessibility**: menu → "Open Accessibility Settings" → add Murmur and toggle on
4. Quit and relaunch (so macOS re-validates the CDHash)
5. Click any text field, press Right ⌘, speak

---

## 🧱 Project layout

```
~/code/dictate/
├── Sources/                       # 13 Swift files
│   ├── main.swift                 # @main entry
│   ├── AppDelegate.swift          # controller + state machine
│   ├── AppState.swift             # idle / recording / paused / finalizing / polishing / reviewing
│   ├── HotkeyMonitor.swift        # CGEventTap — Right ⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift        # AVAudioEngine → 16 kHz mono PCM16
│   ├── SonioxClient.swift         # WebSocket client + speaker filter + reconnect
│   ├── Polisher.swift             # spawns claude / codex CLI for polish
│   ├── TextInjector.swift         # clipboard + simulated ⌘V + focus restore
│   ├── SoundPlayer.swift          # start.mp3 / end.mp3 chimes
│   ├── LiveTextWindow.swift       # bottom-center overlay (adaptive height/font)
│   ├── SettingsWindow.swift       # settings panel
│   ├── PlaceholderTextView.swift  # NSTextView with placeholder
│   ├── Config.swift               # JSON config I/O
│   └── Strings.swift              # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png              # app icon source
│   ├── menubar_banana.png         # menu bar template
│   └── start.mp3 / end.mp3
└── build.sh                       # swiftc + codesign + bundle
```

---

## 🛠️ Design choices

- **`swiftc` direct compile** instead of an Xcode project — single-source, no dependencies, CI-friendly
- **Clipboard paste** instead of synthesized typing — fast, CJK/emoji-safe, restores the original clipboard after 350 ms
- **`CGEventTap` for global hotkeys** — only API that can distinguish left vs right Command (via device-dependent flag bit `0x10`)
- **Polish via `--system-prompt`** + `--output-format text` for clean output
- **Selective Esc consumption** — intercepted only while the overlay is up, passes through otherwise
- **9-slice `maskImage` on NSVisualEffectView** so rounded corners + window shadow stay aligned

---

## 🤝 Contributing

Murmur is intentionally small. The places worth extending:

- **`SonioxClient.swift`** — swap Soniox for another real-time STT (AssemblyAI, Deepgram, OpenAI Realtime, etc.). The shape is straightforward: send config → stream PCM → consume tokens.
- **`Polisher.swift`** — add a new LLM backend. Right now there are two: `claude` (Anthropic) and `codex` (OpenAI). Adding e.g. `gemini` or a local Ollama would be a ~30-line patch.
- **`Strings.swift`** — add more language UIs.

Open an issue first if it's a bigger change, otherwise send a PR.

---

## ❓ Known limitations

- Ad-hoc codesign changes the CDHash on every rebuild, which revokes TCC permissions — annoying during development; use a stable signing identity for release
- Soniox real-time API requires a paid account (small free tier available)
- Apple Silicon only (add `-target x86_64-apple-macos13.0` in `build.sh` for Intel)
- Single-speaker use case by default; multi-speaker filtering relies on Soniox server-side diarization (toggle in Settings — accuracy varies)

---

## 📜 License

MIT
