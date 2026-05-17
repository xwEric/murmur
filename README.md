# Murmur

> [中文版本](./README.zh.md)

**Murmur is a minimalist macOS voice-dictation app.** Press **Right ⌘** to speak, press it again, and your transcription is pasted at the cursor — optionally polished by your local Claude or Codex CLI first. A bottom-center overlay shows the live transcript with adaptive sizing.

<p align="center">
  <img src="Resources/icon_1024.png" alt="Murmur logo" width="160">
</p>

---

## ✨ Why Murmur

1. **No subscription.** Others charge $10–20/month flat. Murmur is pay-as-you-go with your own API key.
2. **Open source, zero data retention.** MIT-licensed; nothing about you is stored or proxied through anyone else's servers.
3. **AI polish at no extra cost.** Calls your locally-installed `claude` / `codex` CLI — uses whatever subscription you already have for those, Murmur adds nothing.
4. **Pause as many times as you want.** Press Space to pause mid-recording, press again to resume. Works repeatedly, auto-reconnects on socket timeout.
5. **Real-time transcription.** Words show up in the overlay as you speak.

---

## 🎯 Core features

1. **Real-time speech recognition** — multiple providers: **Soniox**, **Deepgram Nova-3**, **OpenAI Realtime (gpt-4o-mini-transcribe)**, or any **OpenAI-compatible** custom endpoint
2. **AI polish** — press Alt to clean up filler words via local `claude` / `codex` CLI; custom prompts supported
3. **Multi-language recognition** — 18 languages selectable in Settings
4. **Speaker lock** (Soniox only) — locks onto the first speaker; other voices in the background are dropped
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

## 🔑 Get an API key (pick any one provider)

You only need ONE provider's key to use Murmur. Switch between them anytime in Settings.

### Soniox (default, best multilingual)

1. Go to [console.soniox.com](https://console.soniox.com) and sign up (Google login works)
2. Free trial includes some credit; after that ~$0.04 / min of audio
3. **Settings → API Keys → Create new key** → copy
4. In Murmur Settings → STT Provider → Soniox → paste

### Deepgram Nova-3 (fast, English-optimized)

1. Go to [console.deepgram.com](https://console.deepgram.com) and sign up
2. New accounts get $200 free credit (lots of hours)
3. **API Keys → Create a New API Key** → role: *Member* → copy
4. In Murmur Settings → STT Provider → Deepgram → paste

### OpenAI Realtime (gpt-4o-mini-transcribe)

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys) and create a key
2. Make sure your account has Realtime API access enabled (most paid accounts do)
3. In Murmur Settings → STT Provider → OpenAI Realtime → paste
4. Default model is `gpt-4o-mini-transcribe`; `gpt-4o-transcribe` available for higher quality

### Custom (OpenAI-compatible)

For Azure OpenAI, self-hosted vLLM, or any service that implements OpenAI's Realtime API:

1. In Murmur Settings → STT Provider → Custom
2. **Base URL**: `wss://your-host/v1/realtime?intent=transcription` (provider-specific)
3. **API Key**: whatever your endpoint expects in the `Authorization: Bearer` header
4. **Model name**: passed through in `transcription_session.update`

---

## ⚡ Quick install

**Prerequisites**

- macOS 13+ on Apple Silicon
- Xcode CommandLine Tools (`xcode-select --install`)
- An API key from one of the providers above
- *Optional* — [`claude`](https://claude.com/claude-code) or `codex` CLI installed and logged in (only needed for AI polish; basic dictation works without it)

**1 · Build**

```bash
git clone https://github.com/xwEric/murmur
cd murmur
./build.sh                  # swiftc + ad-hoc codesign + bundle (~3 seconds)
open build/Murmur.app
```

**2 · First-run setup** (one-time)

A small hexagon icon appears in your menu bar. On first launch:

1. **Microphone permission** — a system dialog pops up; click **Allow**
2. **Accessibility permission** — menu bar icon → *"Open Accessibility Settings"* → add `Murmur.app` and toggle the switch on
3. **Quit and relaunch Murmur** (macOS re-validates the signature; permissions only apply after a fresh launch)
4. Open Settings (menu bar icon → *"Settings…"*) → STT Provider → paste your API key

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

**Pay only for the words you actually speak.** No monthly subscription. Audio goes straight from your machine to the STT provider you choose, using your key. AI polish runs through your already-logged-in CLI — Murmur stitches these together with the thinnest possible native layer.

---

## ⚙️ Configuration

Config file at `~/.claude-profile/dictate/config.json`. Most of this is managed by Settings, but you can edit it directly:

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

| Field | Notes |
|---|---|
| `stt_provider` | `soniox` \| `deepgram` \| `openai` \| `custom` |
| `*_api_key` / `*_model` | Per-provider auth + model; only the active provider's fields are used |
| `custom_base_url` | OpenAI-Realtime-compatible WSS endpoint (used when `stt_provider=custom`) |
| `language_hints` | Languages to expect (improves accuracy); Deepgram switches to multilingual when >1 hint |
| `polish_backend` | `claude` or `codex` |
| `polish_prompt` | Empty = built-in default; non-empty = your custom system prompt |
| `speaker_lock` | Experimental, Soniox only — locks to first-detected speaker |

---

## 🧱 Project layout

```
~/code/dictate/
├── Sources/                       # 18 Swift files
│   ├── main.swift                 # @main entry
│   ├── AppDelegate.swift          # controller + state machine
│   ├── AppState.swift             # idle / recording / paused / finalizing / polishing / reviewing
│   ├── HotkeyMonitor.swift        # CGEventTap — Right ⌘ / Alt / Space / Esc
│   ├── AudioRecorder.swift        # AVAudioEngine → 16 kHz mono PCM16
│   ├── STTClient.swift            # protocol for streaming STT backends
│   ├── STTClientFactory.swift     # picks the right client by config
│   ├── SonioxClient.swift         # Soniox real-time WebSocket
│   ├── DeepgramClient.swift       # Deepgram Nova-3 WebSocket
│   ├── OpenAIRealtimeClient.swift # OpenAI Realtime (gpt-4o-mini-transcribe)
│   ├── CustomSTTClient.swift      # OpenAI-compatible custom endpoint
│   ├── Polisher.swift             # spawns claude / codex CLI for polish
│   ├── TextInjector.swift         # clipboard + simulated ⌘V + focus restore
│   ├── SoundPlayer.swift          # start.mp3 / end.mp3 chimes
│   ├── LiveTextWindow.swift       # bottom-center overlay (adaptive height/font + scroll)
│   ├── SettingsWindow.swift       # sidebar Settings (General / Provider / Polish)
│   ├── PlaceholderTextView.swift  # NSTextView with placeholder
│   ├── Config.swift               # JSON config I/O
│   └── Strings.swift              # zh/en i18n
├── Resources/
│   ├── Info.plist
│   ├── Murmur.entitlements
│   ├── icon_1024.png              # honeycomb app icon
│   ├── menubar_banana.png         # menu bar template (legacy filename)
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
- **STT provider behind a `STTClient` protocol** — each backend is a self-contained file; adding a new one is a single file + a factory entry

---

## 🤝 Contributing

Murmur is intentionally small. The places worth extending:

- **New STT provider** — implement `STTClient` in a new file, add a case to `STTClientFactory`. Look at `DeepgramClient.swift` for the simplest template.
- **New polish LLM** — add a backend in `Polisher.swift`. Currently there are two: `claude` (Anthropic) and `codex` (OpenAI). Adding Gemini or local Ollama would be ~30 lines.
- **More UI languages** — add strings in `Strings.swift`.

Open an issue first if it's a bigger change, otherwise send a PR.

---

## ❓ Known limitations

- Ad-hoc codesign changes the CDHash on every rebuild, which revokes TCC permissions — fine during development, use a stable signing identity for release
- Each STT provider requires its own API key; **you only need one** to use Murmur
- Apple Silicon only (add `-target x86_64-apple-macos13.0` in `build.sh` for Intel)

---

## 📜 License

MIT
