# Murmur

> [中文版本](./README.zh.md)

**Murmur is a minimalist macOS voice-dictation app.** Press **Right ⌘** to speak, press it again, and your transcription is pasted at the cursor — optionally polished by your local Claude or Codex CLI first. A bottom-center overlay shows the live transcript with adaptive sizing.

https://github.com/user-attachments/assets/dc1de0a4-6d30-435e-afd0-97f6e198f065

---

## ⚡ Quick install

**Prerequisites**

- macOS 13+ on Apple Silicon
- An API key from one of the STT providers below (Soniox / Deepgram / OpenAI / OpenAI-compatible)
- *Optional* — [`claude`](https://claude.com/claude-code) or `codex` CLI installed and logged in (only needed for the CLI-based polish path; HTTP-based polish and basic dictation work without it)

**Option A · Homebrew (recommended)**

```bash
brew tap xwEric/tap
brew install --cask murmur

# Murmur ships ad-hoc signed, so bypass Gatekeeper once:
xattr -dr com.apple.quarantine "/Applications/Murmur.app"
open /Applications/Murmur.app
```

**Option B · Direct download**

Grab `Murmur-v0.1.1.dmg` from [Releases](https://github.com/xwEric/murmur/releases/latest), drag Murmur.app into /Applications, then bypass Gatekeeper:

```bash
xattr -dr com.apple.quarantine "/Applications/Murmur.app"
open /Applications/Murmur.app
```

**Option C · Build from source**

Needs Xcode CommandLine Tools (`xcode-select --install`).

```bash
git clone https://github.com/xwEric/murmur
cd murmur
./build.sh                  # swiftc + ad-hoc codesign + bundle (~3 seconds)
open build/Murmur.app
```

**First-run setup** (one-time)

A small hexagonal icon appears in your menu bar. On first launch:

1. **Microphone permission** — a system dialog pops up; click **Allow**
2. **Accessibility permission** — menu bar icon → *"Open Accessibility Settings"* → add `Murmur.app` and toggle the switch on
3. **Quit and relaunch Murmur** (macOS re-validates the signature; permissions only apply after a fresh launch)
4. Open Settings (menu bar icon → *"Settings…"*) → STT Provider → paste your API key

**Use it**

Click any text field anywhere on your system (Notes, Slack, browser, terminal — anywhere), then:

- Press **Right ⌘** → speak → press **Right ⌘** again → text appears at cursor
- Press **Right ⌘** → speak → press **Alt** → AI polishes → press **Right ⌘** to insert polished
- Press **Space** mid-recording to pause; press **Space** again to resume
- Press **Esc** anytime to cancel without inserting

**Heads-up**

- If you rebuild from source, ad-hoc codesign changes the binary hash and **macOS will revoke permissions** — you'll need to re-add Murmur to Accessibility & re-grant Microphone after each rebuild. Not a problem once you stop touching the code.
- The very first recording may take an extra ~500 ms to spin up the WebSocket; subsequent ones are instant.
- CLI polish requires your `claude` or `codex` CLI to already be logged in — Murmur doesn't handle that login flow. (Not needed if you use the HTTP polish backend.)

---

## ✨ Why Murmur

1. **No subscription.** Others charge $10–20/month flat. Murmur is pay-as-you-go with your own API key.
- **Real-time transcription**, same Soniox engine — words appear in the overlay as you speak.
- **Pause and resume any time** — press Space, take a sip of coffee, press Space again. Repeat as many times as you want. Most paid apps can't do this.
- **Smarter, effectively-free AI polish** — reuse your already-paid `claude` or `codex` CLI subscription, or plug in any OpenAI-compatible endpoint.
- **Multi-provider, not Soniox-only** — Deepgram Nova-3, OpenAI Realtime, or any OpenAI-compatible endpoint all work.
- **18 languages, speaker lock, zero data retention.** Audio goes straight from your Mac to the STT provider — Murmur has no server.
- **Open source (MIT).** Fork it, audit it, customize the hotkey, change the polish prompt.


---

## 🎯 Core features

1. **Real-time speech recognition** — multiple providers: **Soniox**, **Deepgram Nova-3**, **OpenAI Realtime (gpt-4o-mini-transcribe)**, or any **OpenAI-compatible** custom endpoint
2. **AI polish** — press Alt to clean up filler words. Three backends: local `claude` CLI, local `codex` CLI, or **OpenAI-compatible HTTP API** (with automatic model discovery — paste base URL + key, click "Refresh", pick a model). Custom prompts supported.
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
2. Pricing: **~$0.002 / min ($0.12 / hour)** for real-time streaming, billed by tokens
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

## 💡 The core idea

**Pay only for the words you actually speak.** No monthly subscription. Audio goes straight from your machine to the STT provider you choose, using your key. AI polish runs through your already-logged-in CLI — Murmur stitches these together with the thinnest possible native layer.

---

## 📜 License

MIT
