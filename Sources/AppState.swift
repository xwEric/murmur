import Foundation

final class AppState {
    enum Phase { case idle, recording, paused, finalizing, reviewing, polishing }

    private(set) var phase: Phase = .idle {
        didSet { onChange?(phase) }
    }
    var onChange: ((Phase) -> Void)?

    /// Text from previous (closed) Soniox sub-sessions in the same recording.
    /// Populated when a socket dies during pause and we reconnect — old transcription
    /// is "committed" and the new session appends on top.
    var committedText: String = ""
    /// Text from the currently-active Soniox session (overwritten by each onLiveUpdate).
    var sessionText: String = ""
    /// Combined text shown to the user / fed to polish / inject.
    var raw: String { committedText + sessionText }

    var polished: String?
    var displayingPolished: Bool = false
    var autoPolishAfterFinalize: Bool = false  // Alt-during-recording sets this
    var autoInsertAfterFinalize: Bool = false  // right⌘-during-recording sets this

    func set(_ p: Phase) { DispatchQueue.main.async { self.phase = p } }

    func resetSession() {
        committedText = ""
        sessionText = ""
        polished = nil
        displayingPolished = false
        autoPolishAfterFinalize = false
        autoInsertAfterFinalize = false
    }

    /// Called when a Soniox socket dies and we open a new one mid-recording:
    /// promote what we have to "committed" so the new session appends to it.
    func promoteSessionToCommitted() {
        if !sessionText.isEmpty {
            // Add a single space between sub-sessions if both ends are word chars (heuristic).
            if !committedText.isEmpty,
               let last = committedText.last, !last.isWhitespace,
               let first = sessionText.first, !first.isWhitespace,
               !"，。！？,.!?；;".contains(last), !"，。！？,.!?；;".contains(first) {
                committedText += " "
            }
            committedText += sessionText
            sessionText = ""
        }
    }

    /// Returns whatever text should be shown / inserted right now.
    var currentText: String {
        if displayingPolished, let p = polished { return p }
        return raw
    }
}
