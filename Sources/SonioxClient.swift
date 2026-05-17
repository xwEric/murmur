import Foundation

/// WebSocket client for Soniox real-time STT.
///
/// Protocol:
///   1. Connect to wss://stt-rt.soniox.com/transcribe-websocket
///   2. Send initial JSON config
///   3. Send binary PCM frames continuously
///   4. Send empty string to mark end-of-audio
///   5. Receive token messages with is_final flag; finalize when `finished: true`
final class SonioxClient: STTClient {
    private let apiKey: String
    private let model: String
    private let languageHints: [String]
    private let speakerLock: Bool

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var didFinish = false
    private var didEmitFinal = false
    private var finishFallbackTimer: Timer?

    /// Called continuously as new tokens arrive; receives final + tentative concatenated.
    var onLiveUpdate: ((String) -> Void)?
    /// Called once when server signals `finished: true` (or fallback timeout).
    var onFinalText: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var finals = ""        // confirmed text (is_final = true)
    private var tentatives = ""    // current pending tokens (is_final = false)

    private var audioChunks = 0
    private var tokenMessages = 0

    /// True while the WebSocket task is connected and we haven't seen a fatal error / close.
    private(set) var isAlive: Bool = false

    // Speaker-diarization lock: the first token with a `speaker` field wins;
    // subsequent tokens carrying a *different* speaker are dropped. Tokens
    // without a speaker tag (diarization warm-up) are kept unconditionally.
    private var primarySpeaker: String?
    private var droppedTokens = 0

    init(apiKey: String, model: String, languageHints: [String], speakerLock: Bool = false) {
        self.apiKey = apiKey
        self.model = model
        self.languageHints = languageHints
        self.speakerLock = speakerLock
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    func connect() {
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        let t = session.webSocketTask(with: url)
        self.task = t
        isAlive = true
        t.resume()

        var config: [String: Any] = [
            "api_key": apiKey,
            "model": model,
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "language_hints": languageHints,
        ]
        if speakerLock {
            // Server-side speaker diarization: tag each token with a speaker id so we
            // can keep only the primary (first-detected) speaker's audio.
            config["enable_speaker_diarization"] = true
        }
        guard let data = try? JSONSerialization.data(withJSONObject: config),
              let str = String(data: data, encoding: .utf8) else {
            onError?(NSError(domain: "Soniox", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "config encode failed"]))
            return
        }
        NSLog("Dictate: Soniox connect, sending config (\(str.count) bytes)")
        t.send(.string(str)) { [weak self] err in
            if let err = err {
                NSLog("Dictate: Soniox config send error: \(err)")
                self?.onError?(err)
            }
        }
        listen()
    }

    func sendAudio(_ data: Data) {
        guard !didFinish, let t = task else { return }
        audioChunks += 1
        if audioChunks % 20 == 0 {
            NSLog("Dictate: sent \(audioChunks) audio chunks (~\(audioChunks * 32)ms)")
        }
        t.send(.data(data)) { [weak self] err in
            if let err = err {
                NSLog("Dictate: audio send error: \(err)")
                self?.onError?(err)
            }
        }
    }

    func finish() {
        guard !didFinish else { return }
        didFinish = true
        NSLog("Dictate: finish() — sent \(audioChunks) chunks; sending empty-string EOF marker")
        task?.send(.string("")) { err in
            if let err = err { NSLog("Dictate: EOF send error: \(err)") }
        }

        // Fallback: if no `finished:true` arrives within 1.5s, force-emit whatever we have.
        // (Was 5s; tightened to make commit feel snappier — Soniox usually returns in ~300ms.)
        DispatchQueue.main.async { [weak self] in
            self?.finishFallbackTimer?.invalidate()
            self?.finishFallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                guard let self = self, !self.didEmitFinal else { return }
                NSLog("Dictate: finish-timeout fired — forcing final emit with \(self.finals.count) chars")
                self.emitFinalIfNeeded()
                self.task?.cancel(with: .normalClosure, reason: nil)
            }
        }
    }

    func cancel() {
        didFinish = true
        didEmitFinal = true
        isAlive = false
        finishFallbackTimer?.invalidate()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func emitFinalIfNeeded() {
        guard !didEmitFinal else { return }
        didEmitFinal = true
        finishFallbackTimer?.invalidate()
        let combined = finals + tentatives  // include pending if we never got finals
        NSLog("Dictate: emitting final text (finals=\(finals.count), tentatives=\(tentatives.count))")
        onFinalText?(combined)
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let str): self.handleMessage(str)
                case .data(let d):
                    if let str = String(data: d, encoding: .utf8) { self.handleMessage(str) }
                @unknown default: break
                }
                self.listen()
            case .failure(let err):
                NSLog("Dictate: ws receive failure: \(err.localizedDescription); didFinish=\(self.didFinish) didEmit=\(self.didEmitFinal)")
                self.isAlive = false
                if !self.didEmitFinal {
                    if self.didFinish && !self.finals.isEmpty {
                        self.emitFinalIfNeeded()
                    } else {
                        self.onError?(err)
                    }
                }
            }
        }
    }

    private func handleMessage(_ str: String) {
        tokenMessages += 1
        NSLog("Dictate: <-ws msg #\(tokenMessages): \(str.prefix(500))")
        guard let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("Dictate: unparseable ws message: \(str.prefix(200))")
            return
        }

        if let code = obj["error_code"] {
            let msg = obj["error_message"] as? String ?? "(no message)"
            NSLog("Dictate: Soniox error \(code): \(msg)")
            onError?(NSError(domain: "Soniox", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "[\(code)] \(msg)"]))
            return
        }

        if let tokens = obj["tokens"] as? [[String: Any]] {
            var pendingThisMsg = ""
            for t in tokens {
                let isFinal = (t["is_final"] as? Bool) ?? false
                guard let text = t["text"] as? String else { continue }

                // Speaker filter: drop tokens belonging to non-primary speakers.
                // `speaker` may arrive as String ("1") or Int (1) — normalize to String.
                let speakerStr: String?
                if let s = t["speaker"] as? String, !s.isEmpty {
                    speakerStr = s
                } else if let n = t["speaker"] as? Int {
                    speakerStr = String(n)
                } else if let n = t["speaker"] as? NSNumber {
                    speakerStr = n.stringValue
                } else {
                    speakerStr = nil
                }

                if let sp = speakerStr {
                    if primarySpeaker == nil {
                        primarySpeaker = sp
                        NSLog("Dictate: locked primary speaker = \(sp)")
                    } else if sp != primarySpeaker {
                        droppedTokens += 1
                        if droppedTokens % 10 == 1 {
                            NSLog("Dictate: dropped token from speaker \(sp) (primary=\(primarySpeaker ?? "?"), total dropped=\(droppedTokens))")
                        }
                        continue
                    }
                }
                // Tokens with no speaker tag (warm-up) are kept as-is.

                if isFinal { finals += text } else { pendingThisMsg += text }
            }
            tentatives = pendingThisMsg
            onLiveUpdate?(finals + tentatives)
        }

        if (obj["finished"] as? Bool) == true {
            NSLog("Dictate: Soniox finished=true received (msgs=\(tokenMessages))")
            isAlive = false
            emitFinalIfNeeded()
            task?.cancel(with: .normalClosure, reason: nil)
            task = nil
        }
    }
}
