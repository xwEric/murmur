import Foundation

/// WebSocket client for OpenAI Realtime transcription
/// (https://platform.openai.com/docs/guides/realtime-transcription).
///
/// Protocol overview:
///   1. Connect to wss://api.openai.com/v1/realtime?intent=transcription
///      with headers:
///        Authorization: Bearer <api_key>
///        OpenAI-Beta: realtime=v1
///   2. Send transcription_session.update with input_audio_format=pcm16
///      and the desired model + language.
///   3. For each PCM s16le 16 kHz chunk, base64-encode it and wrap in
///      {"type":"input_audio_buffer.append","audio":"<base64>"}.
///   4. To finish, send {"type":"input_audio_buffer.commit"} then wait for
///      conversation.item.input_audio_transcription.completed.
///
/// Streaming events of interest:
///   - conversation.item.input_audio_transcription.delta → incremental delta text
///   - conversation.item.input_audio_transcription.completed → segment final transcript
class OpenAIRealtimeClient: STTClient {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let languageHints: [String]

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var didFinish = false
    private var didEmitFinal = false
    private var finishFallbackTimer: Timer?

    var onLiveUpdate: ((String) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var finals: String = ""
    private var tentatives: String = ""

    private var audioChunks = 0
    private var msgCount = 0

    private(set) var isAlive: Bool = false

    /// `endpoint` overrides the base URL (used by CustomSTTClient via subclass).
    /// `model` is sent in transcription_session.update.
    init(apiKey: String,
         model: String = "gpt-4o-mini-transcribe",
         languageHints: [String],
         endpoint: URL? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.languageHints = languageHints
        self.baseURL = endpoint
            ?? URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    func connect() {
        var req = URLRequest(url: baseURL)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let t = session.webSocketTask(with: req)
        self.task = t
        isAlive = true
        t.resume()
        NSLog("Murmur: OpenAI-Realtime connect → \(baseURL.absoluteString)")

        // Send transcription session update
        var sessionDict: [String: Any] = [
            "input_audio_format": "pcm16",
            "input_audio_transcription": [
                "model": model,
            ] as [String: Any],
        ]
        if let lang = languageHints.first, languageHints.count == 1, !lang.isEmpty {
            var tx = sessionDict["input_audio_transcription"] as! [String: Any]
            tx["language"] = lang
            sessionDict["input_audio_transcription"] = tx
        }
        let updateMsg: [String: Any] = [
            "type": "transcription_session.update",
            "session": sessionDict,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: updateMsg),
           let str = String(data: data, encoding: .utf8) {
            NSLog("Murmur: OpenAI-Realtime sending session.update (\(str.count) bytes)")
            t.send(.string(str)) { [weak self] err in
                if let err = err {
                    NSLog("Murmur: OpenAI-Realtime session.update send error: \(err)")
                    self?.onError?(err)
                }
            }
        }
        listen()
    }

    func sendAudio(_ data: Data) {
        guard !didFinish, let t = task else { return }
        audioChunks += 1
        if audioChunks % 20 == 0 {
            NSLog("Murmur: OpenAI-Realtime sent \(audioChunks) audio chunks (~\(audioChunks * 32)ms)")
        }
        let b64 = data.base64EncodedString()
        let payload: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": b64,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: json, encoding: .utf8) else { return }
        t.send(.string(str)) { [weak self] err in
            if let err = err {
                NSLog("Murmur: OpenAI-Realtime audio send error: \(err)")
                self?.onError?(err)
            }
        }
    }

    func finish() {
        guard !didFinish else { return }
        didFinish = true
        NSLog("Murmur: OpenAI-Realtime finish() — sending input_audio_buffer.commit")
        let commit = "{\"type\":\"input_audio_buffer.commit\"}"
        task?.send(.string(commit)) { err in
            if let err = err { NSLog("Murmur: OpenAI-Realtime commit error: \(err)") }
        }
        DispatchQueue.main.async { [weak self] in
            self?.finishFallbackTimer?.invalidate()
            // Slightly longer fallback than Soniox — OpenAI .completed can take a beat.
            self?.finishFallbackTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                guard let self = self, !self.didEmitFinal else { return }
                NSLog("Murmur: OpenAI-Realtime finish-timeout fired — forcing emit (\(self.finals.count) chars)")
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
        let combined = (finals + tentatives).trimmingCharacters(in: .whitespaces)
        NSLog("Murmur: OpenAI-Realtime emitting final (finals=\(finals.count), tentatives=\(tentatives.count))")
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
                NSLog("Murmur: OpenAI-Realtime ws receive failure: \(err.localizedDescription); didFinish=\(self.didFinish) didEmit=\(self.didEmitFinal)")
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
        msgCount += 1
        NSLog("Murmur: OpenAI-Realtime <-ws #\(msgCount): \(str.prefix(400))")
        guard let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return
        }

        switch type {
        case "error":
            // OpenAI envelope: { type: "error", error: { message, type, code, ... } }
            let errObj = obj["error"] as? [String: Any]
            let msg = errObj?["message"] as? String
                ?? obj["message"] as? String
                ?? "(no message)"
            NSLog("Murmur: OpenAI-Realtime error: \(msg)")
            onError?(NSError(domain: "OpenAIRealtime", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: msg]))
        case "conversation.item.input_audio_transcription.delta":
            if let delta = obj["delta"] as? String, !delta.isEmpty {
                tentatives += delta
                onLiveUpdate?(finals + tentatives)
            }
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = obj["transcript"] as? String {
                // Move completed segment from tentatives into finals
                if !finals.isEmpty && !finals.hasSuffix(" ") { finals += " " }
                finals += transcript
                tentatives = ""
                onLiveUpdate?(finals)
                if didFinish {
                    emitFinalIfNeeded()
                    task?.cancel(with: .normalClosure, reason: nil)
                    task = nil
                }
            }
        case "input_audio_buffer.committed":
            // server acknowledged our commit — nothing to do, wait for .completed
            break
        case "transcription_session.created",
             "transcription_session.updated",
             "session.created",
             "session.updated":
            break
        default:
            // Ignore other event types
            break
        }
    }
}
