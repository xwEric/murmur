import AppKit

/// NSTextView that draws a placeholder string in `placeholderTextColor` when empty.
/// Use when you want a multi-line text editor with classic placeholder behavior.
final class PlaceholderTextView: NSTextView {
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.placeholderTextColor,
        ]
        let inset = textContainerInset
        let origin = NSPoint(
            x: inset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: inset.height
        )
        let drawRect = NSRect(origin: origin,
                              size: NSSize(width: bounds.width - origin.x * 2,
                                           height: bounds.height - origin.y * 2))
        (placeholderString as NSString).draw(in: drawRect, withAttributes: attrs)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}
