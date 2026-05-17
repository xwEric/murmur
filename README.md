# Murmur

> [中文版本](./README.zh.md)

**Murmur is a minimalist macOS voice-dictation app.** Press **Right ⌘** to speak, press it again, and your transcription is pasted at the cursor — optionally polished by your local Claude or Codex CLI first. A bottom-center overlay shows the live transcript with adaptive sizing.

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ Why Murmur

1. **No subscription.** Others charge $10–20/month flat. Murmur is pay-as-you-go to Soniox with your own key (typically ~$0.05/hour of speech).
2. **Open source, zero data retention.** MIT-licensed; nothing about you is stored or proxied through anyone else's servers.
3. **AI polish at no extra cost.** Calls your locally-installed `claude` / `codex` CLI — uses whatever subscription you already have for those, Murmur adds nothing.
4. **Pause as many times as you want.** Press Space to pause mid-recording, press again to resume. Works repeatedly, auto-reconnects on socket timeout.
5. **Real-time transcription.** Words show up in the overlay as you speak.

---

## 🎯 Core features

1. **Real-time speech recognition** (Soniox WebSocket, ~500 ms first-token latency)
2. **AI polish** — press Alt to clean up filler words via local `claude` / `codex` CLI; custom prompts supported
3. **Multi-language recognition** — 18 languages selectable in Settings
4. **Speaker lock** — when enabled, locks onto the first speaker; other voices in the background are dropped
5. **Pause & resume** — pause anytime, resume anytime; previously transcribed text is preserved across socket reconnects

---

## ⌨️ Hotkeys

| Key | Action |
|---|---|
| **Right ⌘** | Start recording → stop & paste → commit text in review state |
| **Alt** | During recording → stop & polish; in review → toggle original ↔ polished |
| **Space** | Recording → pause; paused → resume |
| **Esc** | Cancel anywhere — discard without inserting |

---

## ⚡ Quick install

**Prerequisites**

- macOS 13+ on Apple Silicon
- Xcode CommandLine Tools (`xcode-select --install`)
- A [Soniox](https://soniox.com) account + API key (small free tier; very cheap pay-as-you-go after)
- *Optional* — [`claude`](https://claude.com/claude-code) or `codex` CLI installed and logged in (only needed for AI polish; basic dictation works without it)

**1 · Build**

```bash
git clone https://github.com/xwEric/murmur
cd murmur
./build.sh                  # swiftc + ad-hoc codesign + bundle (~3 seconds)
open build/Murmur.app
```

**2 · First-run setup** (one-time)

A small 🍌 banana icon appears in your menu bar. On first launch:

1. **Microphone permission** — a system dialog pops up; click **Allow**
2. **Accessibility permission** — menu bar 🍌 → *"Open Accessibility Settings"* → add `Murmur.app` and toggle the switch on
3. **Quit and relaunch Murmur** (macOS re-validates the signature; permissions only apply after a fresh launch)
4. Open Settings (menu bar 🍌 → *"Settings…"*) and paste your Soniox API key

**3 · Use it**

Click any text field anywhere on your system (Notes, Slack, browser, terminal — anywhere), then:

- Press **Right ⌘** → speak → press **Right ⌘** again → text appears at cursor
- Press **Right ⌘** → speak → press **Alt** → AI polishes → press **Right ⌘** to insert polished
- Press **Space** mid-recording to pause; press **Space** again to resume
- Press **Esc** anytime to cancel without inserting

**Heads-up**

- If you rebuild from source, ad-hoc codesign changes the binary hash and **macOS will revoke permissions** — you'll need to re-add Murmur to Accessibility & re-grant Microphone after each rebuild. Not a problem once you stop touching the code.
- The very first recording may take an extra ~500 ms to spin up the WebSocket; subsequent ones are instant.
- AI polish requires your `claude` or `codex` CLI to already be logged in — Murmur doesn't handle that login flow.

---

## 💡 The core idea

**Pay only for the words you actually speak.** No monthly subscription. Audio goes straight from your machine to Soniox using your key. AI polish runs through your already-logged-in CLI — Murmur stitches these together with the thinnest possible native layer.

---

## ⚙️ Configuration

Config file at `~/.claude-profile/dictate/config.json`:

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
- **Selective Esc consumption** — intercepted only while the overlay is up, passes through otherwise
- **9-slice `maskImage` on NSVisualEffectView** so rounded corners + window shadow stay aligned

---

## 🤝 Contributing

Murmur is intentionally small. The places worth extending:

- **`SonioxClient.swift`** — swap Soniox for another real-time STT (AssemblyAI, Deepgram, OpenAI Realtime, etc.)
- **`Polisher.swift`** — add a new LLM backend. Right now there are two: `claude` (Anthropic) and `codex` (OpenAI). Adding Gemini or local Ollama would be a ~30-line patch.
- **`Strings.swift`** — add more UI languages

Open an issue first if it's a bigger change, otherwise send a PR.

---

## ❓ Known limitations

- Ad-hoc codesign changes the CDHash on every rebuild, which revokes TCC permissions — fine during development, use a stable signing identity for release
- Soniox real-time API requires a paid account (small free tier available)
- Apple Silicon only (add `-target x86_64-apple-macos13.0` in `build.sh` for Intel)

---

## 📜 License

MIT
