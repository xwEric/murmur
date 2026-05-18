import Foundation

struct Config {
    // STT provider selector: "soniox" | "deepgram" | "openai" | "custom"
    var sttProvider: String

    // Soniox
    var sonioxApiKey: String
    var sonioxModel: String

    // Deepgram
    var deepgramApiKey: String
    var deepgramModel: String

    // OpenAI Realtime
    var openaiApiKey: String
    var openaiModel: String

    // Custom OpenAI-compatible
    var customBaseUrl: String
    var customApiKey: String
    var customModel: String

    // Shared
    var languageHints: [String]
    var polishBackend: String      // "claude" | "codex" | "openai_api"
    var polishModel: String
    var polishPrompt: String
    var speakerLock: Bool          // only meaningful for Soniox

    // Polish via OpenAI-compatible HTTP API (only when polishBackend == "openai_api")
    var polishApiBaseUrl: String   // e.g. "https://api.openai.com/v1"
    var polishApiKey: String

    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-profile/dictate/config.json")

    // Defaults
    static let defaultSttProvider = "soniox"
    static let defaultSonioxModel = "stt-rt-preview"
    static let defaultDeepgramModel = "nova-3"
    static let defaultOpenAIModel = "gpt-4o-mini-transcribe"
    static let defaultCustomModel = "gpt-4o-mini-transcribe"
    static let defaultLanguageHints = ["zh", "en"]
    static let defaultPolishBackend = "claude"
    static let defaultPolishModelClaude = "sonnet"
    static let defaultPolishModelCodex = "gpt-5-codex"
    static let defaultPolishApiBaseUrl = "https://api.openai.com/v1"
    static let defaultPolishApiModel = "gpt-4o-mini"

    static func load() throws -> Config {
        // If the config file doesn't exist yet, return an empty default config.
        // (The previous behavior threw, which made first-launch awkward — Settings
        // window can't open if load() throws. We still validate at use-time elsewhere.)
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            // Treat missing file as empty config; the Settings UI will show empty fields.
            return Config(
                sttProvider: defaultSttProvider,
                sonioxApiKey: "",
                sonioxModel: defaultSonioxModel,
                deepgramApiKey: "",
                deepgramModel: defaultDeepgramModel,
                openaiApiKey: "",
                openaiModel: defaultOpenAIModel,
                customBaseUrl: "",
                customApiKey: "",
                customModel: defaultCustomModel,
                languageHints: defaultLanguageHints,
                polishBackend: defaultPolishBackend,
                polishModel: defaultPolishModelClaude,
                polishPrompt: "",
                speakerLock: false,
                polishApiBaseUrl: defaultPolishApiBaseUrl,
                polishApiKey: ""
            )
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        // Backward-compatible field reads:
        //   - legacy `soniox_api_key` + `model` were the only fields before multi-provider.
        //   - new explicit keys: soniox_api_key (same), soniox_model, deepgram_api_key, etc.
        let sonioxKey = (json["soniox_api_key"] as? String) ?? ""
        let sonioxModel = (json["soniox_model"] as? String)
            ?? (json["model"] as? String)   // legacy
            ?? defaultSonioxModel

        let cfg = Config(
            sttProvider: (json["stt_provider"] as? String) ?? defaultSttProvider,
            sonioxApiKey: sonioxKey,
            sonioxModel: sonioxModel,
            deepgramApiKey: (json["deepgram_api_key"] as? String) ?? "",
            deepgramModel: (json["deepgram_model"] as? String) ?? defaultDeepgramModel,
            openaiApiKey: (json["openai_api_key"] as? String) ?? "",
            openaiModel: (json["openai_model"] as? String) ?? defaultOpenAIModel,
            customBaseUrl: (json["custom_base_url"] as? String) ?? "",
            customApiKey: (json["custom_api_key"] as? String) ?? "",
            customModel: (json["custom_model"] as? String) ?? defaultCustomModel,
            languageHints: (json["language_hints"] as? [String]) ?? defaultLanguageHints,
            polishBackend: (json["polish_backend"] as? String) ?? defaultPolishBackend,
            polishModel: (json["polish_model"] as? String) ?? defaultPolishModelClaude,
            polishPrompt: (json["polish_prompt"] as? String) ?? "",
            speakerLock: (json["speaker_lock"] as? Bool) ?? false,
            polishApiBaseUrl: (json["polish_api_base_url"] as? String) ?? defaultPolishApiBaseUrl,
            polishApiKey: (json["polish_api_key"] as? String) ?? ""
        )
        return cfg
    }

    func save() throws {
        let dict: [String: Any] = [
            "stt_provider": sttProvider,
            "soniox_api_key": sonioxApiKey,
            "soniox_model": sonioxModel,
            // Keep legacy `model` field in sync so older binaries still work.
            "model": sonioxModel,
            "deepgram_api_key": deepgramApiKey,
            "deepgram_model": deepgramModel,
            "openai_api_key": openaiApiKey,
            "openai_model": openaiModel,
            "custom_base_url": customBaseUrl,
            "custom_api_key": customApiKey,
            "custom_model": customModel,
            "language_hints": languageHints,
            "polish_backend": polishBackend,
            "polish_model": polishModel,
            "polish_prompt": polishPrompt,
            "speaker_lock": speakerLock,
            "polish_api_base_url": polishApiBaseUrl,
            "polish_api_key": polishApiKey,
        ]
        let data = try JSONSerialization.data(withJSONObject: dict,
                                              options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: Config.configURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: Config.configURL, options: .atomic)
        // chmod 600
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: Config.configURL.path)
    }

    /// Validation called at use-time (e.g. when starting recording).
    /// Returns nil if config is usable; otherwise a human-readable error string.
    func validate() -> String? {
        switch sttProvider {
        case "soniox":
            return sonioxApiKey.isEmpty ? "Soniox API key is empty (open Settings)" : nil
        case "deepgram":
            return deepgramApiKey.isEmpty ? "Deepgram API key is empty (open Settings)" : nil
        case "openai":
            return openaiApiKey.isEmpty ? "OpenAI API key is empty (open Settings)" : nil
        case "custom":
            if customBaseUrl.isEmpty { return "Custom STT base URL is empty (open Settings)" }
            if customApiKey.isEmpty { return "Custom STT API key is empty (open Settings)" }
            return nil
        default:
            return "Unknown STT provider: \(sttProvider)"
        }
    }
}
