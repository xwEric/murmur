import Foundation

/// WebSocket client for Deepgram Nova-3 real-time streaming STT.
///
/// Protocol overview (https://developers.deepgram.com/docs/live-streaming-audio):
///   1. Connect to wss://api.deepgram.com/v1/listen?<params>
///      with `Authorization: Token <api_key>` header.
///   2. Stream raw PCM 16 kHz mono s16le binary frames.
///   3. Receive JSON messages with `channel.alternatives[0].transcript`
///      plus `is_final` / `speech_final` flags.
///   4. To finish, send {"type":"CloseStream"} as a text frame.
final class DeepgramClient: STTClient {
    private let apiKey: String
    private let model: String
    private let languageHints: [String]

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var didFinish = false
    private var didEmitFinal = false
    private var finishFallbackTimer: Timer?
    private var lastMessageAt: Date = Date()
    private var idleEmitTimer: Timer?

    var onLiveUpdate: ((String) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var finals: String = ""
    private var tentatives: String = ""

    private var audioChunks = 0
    private var msgCount = 0

    private(set) var isAlive: Bool = false

    init(apiKey: String, model: String = "nova-3", languageHints: [String]) {
        self.apiKey = apiKey
        self.model = model
        self.languageHints = languageHints
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    func connect() {
        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "utterance_end_ms", value: "1000"),
            URLQueryItem(name: "endpointing", value: "300"),
            URLQueryItem(name: "smart_format", value: "true"),
        ]
        if languageHints.count > 1 {
            items.append(URLQueryItem(name: "language", value: "multi"))
        } else if let only = languageHints.first {
            items.append(URLQueryItem(name: "language", value: only))
        }
        comps.queryItems = items

        guard let url = comps.url else {
            onError?(NSError(domain: "Deepgram", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "bad URL"]))
            return
        }

        var req = URLRequest(url: url)
        req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let t = session.webSocketTask(with: req)
        self.task = t
        isAlive = true
        t.resume()
        NSLog("Murmur: Deepgram connect → \(url.absoluteString)")
        listen()
    }

    func sendAudio(_ data: Data) {
        guard !didFinish, let t = task else { return }
        audioChunks += 1
        if audioChunks % 20 == 0 {
            NSLog("Murmur: Deepgram sent \(audioChunks) audio chunks (~\(audioChunks * 32)ms)")
        }
        t.send(.data(data)) { [weak self] err in
            if let err = err {
                NSLog("Murmur: Deepgram audio send error: \(err)")
                self?.onError?(err)
            }
        }
    }

    func finish() {
        guard !didFinish else { return }
        didFinish = true
        NSLog("Murmur: Deepgram finish() — sending CloseStream after \(audioChunks) chunks")
        let close = "{\"type\":\"CloseStream\"}"
        task?.send(.string(close)) { err in
            if let err = err { NSLog("Murmur: Deepgram CloseStream send error: \(err)") }
        }

        // Fallback identical to Soniox: emit whatever we have within 1.5s if no UtteranceEnd arrives.
        DispatchQueue.main.async { [weak self] in
            self?.finishFallbackTimer?.invalidate()
            self?.finishFallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                guard let self = self, !self.didEmitFinal else { return }
                NSLog("Murmur: Deepgram finish-timeout fired — forcing final emit (\(self.finals.count) chars)")
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
        idleEmitTimer?.invalidate()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func emitFinalIfNeeded() {
        guard !didEmitFinal else { return }
        didEmitFinal = true
        finishFallbackTimer?.invalidate()
        idleEmitTimer?.invalidate()
        let combined = (finals + tentatives).trimmingCharacters(in: .whitespaces)
        NSLog("Murmur: Deepgram emitting final (finals=\(finals.count), tentatives=\(tentatives.count))")
        onFinalText?(combined)
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                self.lastMessageAt = Date()
                switch msg {
                case .string(let str): self.handleMessage(str)
                case .data(let d):
                    if let str = String(data: d, encoding: .utf8) { self.handleMessage(str) }
                @unknown default: break
                }
                self.listen()
            case .failure(let err):
                NSLog("Murmur: Deepgram ws receive failure: \(err.localizedDescription); didFinish=\(self.didFinish) didEmit=\(self.didEmitFinal)")
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
        NSLog("Murmur: Deepgram <-ws #\(msgCount): \(str.prefix(400))")
        guard let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("Murmur: Deepgram unparseable msg: \(str.prefix(200))")
            return
        }

        // Error envelope
        if let type = obj["type"] as? String {
            switch type {
            case "Error", "error":
                let msg = obj["description"] as? String ?? obj["message"] as? String ?? "(no message)"
                onError?(NSError(domain: "Deepgram", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: msg]))
                return
            case "UtteranceEnd":
                if didFinish {
                    NSLog("Murmur: Deepgram UtteranceEnd after finish → emit")
                    emitFinalIfNeeded()
                    task?.cancel(with: .normalClosure, reason: nil)
                    task = nil
                }
                return
            case "Metadata":
                return
            default:
                break
            }
        }

        guard let channel = obj["channel"] as? [String: Any],
              let alts = channel["alternatives"] as? [[String: Any]],
              let first = alts.first,
              let transcript = first["transcript"] as? String else {
            return
        }
        let isFinal = (obj["is_final"] as? Bool) ?? false

        if transcript.isEmpty { return }

        if isFinal {
            if !finals.isEmpty && !finals.hasSuffix(" ") { finals += " " }
            finals += transcript
            tentatives = ""
        } else {
            tentatives = transcript
        }
        onLiveUpdate?(finals + (tentatives.isEmpty ? "" : (finals.isEmpty || finals.hasSuffix(" ") ? "" : " ") + tentatives))
    }
}
