import Foundation

/// OpenAI-compatible realtime STT endpoint with a user-supplied base URL.
///
/// Lets users plug in Azure OpenAI, vLLM, or any service that exposes the
/// same `transcription_session.update` / `input_audio_buffer.append` /
/// `conversation.item.input_audio_transcription.delta` / `.completed` events
/// as OpenAI's official realtime API.
final class CustomSTTClient: OpenAIRealtimeClient {
    init(baseURL: String, apiKey: String, model: String, languageHints: [String]) {
        let url = URL(string: baseURL) ?? URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!
        super.init(apiKey: apiKey, model: model, languageHints: languageHints, endpoint: url)
        NSLog("Murmur: CustomSTTClient using endpoint \(url.absoluteString) model=\(model)")
    }
}
