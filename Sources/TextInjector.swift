import AppKit

enum TextInjector {
    /// Saves the current pasteboard, writes `text`, simulates Cmd+V, restores pasteboard.
    ///
    /// `targetApp`: the app that was frontmost when recording started. When set, we re-activate
    /// it before pasting so focus returns to the original text field even if the user clicked
    /// elsewhere during recording.
    static func inject(_ text: String, targetApp: NSRunningApplication? = nil) {
        NSLog("Murmur: TextInjector.inject \(text.count) chars (targetApp pid=\(targetApp?.processIdentifier ?? -1) name=\(targetApp?.localizedName ?? "?"))")
        let pb = NSPasteboard.general

        let saved: [(types: [NSPasteboard.PasteboardType], data: [NSPasteboard.PasteboardType: Data])] =
            (pb.pasteboardItems ?? []).map { item in
                var bag: [NSPasteboard.PasteboardType: Data] = [:]
                for t in item.types {
                    if let d = item.data(forType: t) { bag[t] = d }
                }
                return (item.types, bag)
            }

        pb.clearContents()
        pb.setString(text, forType: .string)

        // Refocus the original target app before pasting.
        if let app = targetApp, !app.isTerminated, !app.isActive {
            NSLog("Murmur: re-activating target app \(app.localizedName ?? "?")")
            app.activate(options: [])
            // Activation is async; give WindowServer ~120 ms to deliver focus.
            usleep(120_000)
        }

        pasteShortcut()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            pb.clearContents()
            let restored: [NSPasteboardItem] = saved.compactMap { snap in
                let item = NSPasteboardItem()
                for t in snap.types {
                    if let d = snap.data[t] { item.setData(d, forType: t) }
                }
                return item.types.isEmpty ? nil : item
            }
            if !restored.isEmpty {
                pb.writeObjects(restored)
            }
        }
    }

    private static func pasteShortcut() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9  // kVK_ANSI_V

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand

        let loc = CGEventTapLocation.cghidEventTap
        down?.post(tap: loc)
        up?.post(tap: loc)
    }
}
