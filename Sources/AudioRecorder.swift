import AVFoundation

/// Captures mic input and emits 16 kHz mono signed-16-bit-LE PCM chunks for Soniox.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16,
                      sampleRate: 16000,
                      channels: 1,
                      interleaved: true)!
    }()

    var onAudio: ((Data) -> Void)?

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "AudioRecorder", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone not available"])
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
    }

    /// Pause audio capture without tearing down the tap/converter. While paused,
    /// no buffers are delivered to `onAudio`, so nothing is sent to Soniox.
    func pause() {
        guard engine.isRunning else { return }
        NSLog("Dictate: AudioRecorder.pause()")
        engine.pause()
    }

    /// Resume audio capture after a pause(). Safe to call repeatedly.
    func resume() throws {
        guard !engine.isRunning else { return }
        NSLog("Dictate: AudioRecorder.resume()")
        try engine.start()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed { outStatus.pointee = .noDataNow; return nil }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            NSLog("Dictate AVAudioConverter error: \(error)")
            return
        }
        guard status != .error,
              outBuffer.frameLength > 0,
              let int16 = outBuffer.int16ChannelData else { return }

        // Audio level diagnostic: compute peak amplitude of this chunk (Int16 range = ±32767).
        // Helps tell apart "mic silent" vs "mic captures fine but Soniox rejects".
        let frames = Int(outBuffer.frameLength)
        var peak: Int32 = 0
        let ptr = int16[0]
        for i in 0..<frames {
            let v = Int32(ptr[i])
            let abs = v < 0 ? -v : v
            if abs > peak { peak = abs }
        }
        chunkIndex += 1
        if chunkIndex % 10 == 0 {
            NSLog("Dictate: audio chunk #\(chunkIndex) frames=\(frames) peak=\(peak)/32767 (\(Int(Double(peak) / 327.67))% full-scale)")
        }

        let byteCount = frames * MemoryLayout<Int16>.size
        let data = Data(bytes: ptr, count: byteCount)
        onAudio?(data)
    }

    private var chunkIndex = 0
}
