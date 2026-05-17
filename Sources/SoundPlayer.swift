import AppKit
import AVFoundation

/// Plays the same start/end recording sounds as Spokenly (loaded from app bundle).
enum SoundPlayer {
    private static var startPlayer: AVAudioPlayer? = makePlayer(named: "start", ext: "mp3")
    private static var endPlayer: AVAudioPlayer? = makePlayer(named: "end", ext: "mp3")

    static func start() {
        if let p = startPlayer {
            p.currentTime = 0
            p.play()
        } else {
            NSSound(named: "Tink")?.play()
        }
    }

    static func stop() {
        if let p = endPlayer {
            p.currentTime = 0
            p.play()
        } else {
            NSSound(named: "Pop")?.play()
        }
    }

    private static func makePlayer(named: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: named, withExtension: ext) else {
            NSLog("Murmur: SoundPlayer — \(named).\(ext) not in bundle, falling back to NSSound")
            return nil
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0.8
            p.prepareToPlay()
            return p
        } catch {
            NSLog("Murmur: SoundPlayer init failed for \(named): \(error)")
            return nil
        }
    }
}
