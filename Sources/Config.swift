import Foundation

struct Config {
    var apiKey: String
    var model: String              // soniox model
    var languageHints: [String]
    var polishBackend: String      // "claude" | "codex"
    var polishModel: String        // e.g. "sonnet" | "gpt-5-codex"
    var speakerLock: Bool          // server-side speaker diarization; off by default (accuracy issues)
    var polishPrompt: String       // custom polish system prompt; empty = use Polisher.defaultSystemPrompt

    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-profile/dictate/config.json")

    static let defaultSonioxModel = "stt-rt-preview"
    static let defaultLanguageHints = ["zh", "en"]
    static let defaultPolishBackend = "claude"
    static let defaultPolishModelClaude = "sonnet"
    static let defaultPolishModelCodex = "gpt-5-codex"

    static func load() throws -> Config {
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            throw NSError(domain: "Config", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取 \(configURL.path)：\(error.localizedDescription)"
            ])
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard let apiKey = json["soniox_api_key"] as? String, !apiKey.isEmpty else {
            throw NSError(domain: "Config", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "config.json 缺少 soniox_api_key 字段"
            ])
        }
        return Config(
            apiKey: apiKey,
            model: (json["model"] as? String) ?? defaultSonioxModel,
            languageHints: (json["language_hints"] as? [String]) ?? defaultLanguageHints,
            polishBackend: (json["polish_backend"] as? String) ?? defaultPolishBackend,
            polishModel: (json["polish_model"] as? String) ?? defaultPolishModelClaude,
            speakerLock: (json["speaker_lock"] as? Bool) ?? false,
            polishPrompt: (json["polish_prompt"] as? String) ?? ""
        )
    }

    func save() throws {
        let dict: [String: Any] = [
            "soniox_api_key": apiKey,
            "model": model,
            "language_hints": languageHints,
            "polish_backend": polishBackend,
            "polish_model": polishModel,
            "speaker_lock": speakerLock,
            "polish_prompt": polishPrompt,
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
}
