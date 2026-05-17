import Foundation

enum STTClientFactory {
    static func make(config: Config) -> STTClient {
        switch config.sttProvider {
        case "deepgram":
            return DeepgramClient(
                apiKey: config.deepgramApiKey,
                model: config.deepgramModel.isEmpty ? Config.defaultDeepgramModel : config.deepgramModel,
                languageHints: config.languageHints
            )
        case "openai":
            return OpenAIRealtimeClient(
                apiKey: config.openaiApiKey,
                model: config.openaiModel.isEmpty ? Config.defaultOpenAIModel : config.openaiModel,
                languageHints: config.languageHints
            )
        case "custom":
            return CustomSTTClient(
                baseURL: config.customBaseUrl,
                apiKey: config.customApiKey,
                model: config.customModel.isEmpty ? Config.defaultCustomModel : config.customModel,
                languageHints: config.languageHints
            )
        case "soniox":
            fallthrough
        default:
            return SonioxClient(
                apiKey: config.sonioxApiKey,
                model: config.sonioxModel.isEmpty ? Config.defaultSonioxModel : config.sonioxModel,
                languageHints: config.languageHints,
                speakerLock: config.speakerLock
            )
        }
    }
}
