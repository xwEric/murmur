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
3. **AI polish — your choice of route.** Use your locally-installed `claude` / `codex` CLI (free, reuses your existing subscription, ~5s latency) **or** plug in any OpenAI-compatible API endpoint (1–2s latency, pay per call).
4. **Pause as many times as you want.** Press Space to pause mid-recording, press again to resume. Works repeatedly, auto-reconnects on socket timeout.
5. **Real-time transcription.** Words show up in the overlay as you speak.

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
- An API key from one of the providers above
- *Optional* — [`claude`](https://claude.com/claude-code) or `codex` CLI installed and logged in (only needed for AI polish; basic dictation works without it)

**Option A · Homebrew (recommended)**

```bash
brew tap xwEric/tap
brew install --cask murmur

# Murmur ships ad-hoc signed, so bypass Gatekeeper once:
xattr -dr com.apple.quarantine "/Applications/Murmur.app"
open /Applications/Murmur.app
```

**Option B · Direct download**

Grab `Murmur-v0.1.0.dmg` from [Releases](https://github.com/xwEric/murmur/releases/latest), drag Murmur.app into /Applications, then bypass Gatekeeper:

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

**2 · First-run setup** (one-time)

A small hexagonal icon appears in your menu bar. On first launch:

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

## 📜 License

MIT
