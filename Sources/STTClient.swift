import Foundation

/// Common interface for real-time streaming speech-to-text clients.
///
/// Implementations:
///   - SonioxClient        — Soniox stt-rt-preview WebSocket
///   - DeepgramClient      — Deepgram Nova-3 listen WebSocket
///   - OpenAIRealtimeClient — OpenAI gpt-4o-mini-transcribe realtime API
///   - CustomSTTClient     — OpenAI-compatible endpoint with user-supplied URL
///
/// Lifecycle:
///   1. set callbacks
///   2. connect()
///   3. repeatedly sendAudio(_:) with 16 kHz mono PCM s16le
///   4. finish() to flush + receive a final transcription
///   5. cancel() at any time to abort
///
/// Threading:
///   Callbacks may be delivered on arbitrary queues — dispatch to main when touching UI.
protocol STTClient: AnyObject {
    /// Called continuously as new tokens arrive; receives finals + tentatives concatenated.
    var onLiveUpdate: ((String) -> Void)? { get set }
    /// Called once when the server signals end-of-stream (or fallback timeout).
    var onFinalText: ((String) -> Void)? { get set }
    /// Called when the underlying transport fails or the server emits an error event.
    var onError: ((Error) -> Void)? { get set }

    /// Best-effort liveness signal — true while the underlying socket is connected.
    var isAlive: Bool { get }

    func connect()
    func sendAudio(_ data: Data)
    func finish()
    func cancel()
}
