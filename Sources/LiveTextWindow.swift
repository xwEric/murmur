import AppKit

/// Bottom-center overlay, Spokenly-style. Single window for live + review.
///
/// Sizing rules:
///   - Starts at 1-line capacity
///   - Grows up to 4 lines as text wraps
///   - When text exceeds 4 lines @ 18 pt: font shrinks down to 10 pt
///   - At 4 lines + 10 pt and STILL overflowing: head-truncate the displayed string
///   - Only resizes the window when lineCount or font actually changes (eliminates jitter)
///   - 80% overall opacity
final class LiveTextWindow {
    enum Mode {
        case recording
        case paused
        case finalizing
        case polishing
        case reviewing(isPolished: Bool)
        case error(String)
    }

    private let panel: NSPanel
    private let effectView: NSVisualEffectView
    private let textField: NSTextField
    private let statusLabel: NSTextField
    private let hintLabel: NSTextField

    private let windowWidth: CGFloat = 720
    private let horizontalPadding: CGFloat = 20
    private let topPadding: CGFloat = 12
    private let statusHeight: CGFloat = 14
    private let gapBelowStatus: CGFloat = 10
    private let bottomPadding: CGFloat = 14
    private let maxLines: Int = 4
    private let maxFontSize: CGFloat = 18
    private let minFontSize: CGFloat = 10

    private var currentFontSize: CGFloat = 18
    private var currentLineCount: Int = 1
    private var bottomLeftAnchor: NSPoint = .zero

    init() {
        // initial: 1 line at 18pt
        let initFont = NSFont.systemFont(ofSize: 18, weight: .regular)
        let initLineH = initFont.boundingRectForFont.height
        let initialHeight = 12 + 14 + 10 + (initLineH + 4) + 14

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: initialHeight),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.alphaValue = 0.0

        let effect = NSVisualEffectView(frame: p.contentView!.bounds)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        p.contentView = effect

        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: 11, weight: .semibold)
        status.textColor = NSColor.secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(status)

        let hint = NSTextField(labelWithString: "")
        hint.font = .systemFont(ofSize: 10, weight: .regular)
        hint.textColor = NSColor.tertiaryLabelColor
        hint.alignment = .right
        hint.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hint)

        let text = NSTextField(wrappingLabelWithString: "")
        text.font = .systemFont(ofSize: 18, weight: .regular)
        text.textColor = NSColor.labelColor
        text.lineBreakMode = .byWordWrapping       // real wrap (fixes "no wrap, head ellipsis")
        text.maximumNumberOfLines = 1
        text.cell?.truncatesLastVisibleLine = true
        text.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(text)

        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            status.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),

            hint.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            hint.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            hint.leadingAnchor.constraint(greaterThanOrEqualTo: status.trailingAnchor, constant: 12),

            text.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 10),
            text.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            text.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            text.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -14),
        ])

        self.panel = p
        self.effectView = effect
        self.textField = text
        self.statusLabel = status
        self.hintLabel = hint

        anchorAtBottomCenter(height: initialHeight)
    }

    private func anchorAtBottomCenter(height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - windowWidth / 2
        let y = visible.minY + 80
        bottomLeftAnchor = NSPoint(x: x, y: y)
        panel.setFrame(NSRect(x: x, y: y, width: windowWidth, height: height), display: true)
    }

    // MARK: - Show / Hide

    func show() {
        DispatchQueue.main.async {
            self.currentLineCount = 1
            self.currentFontSize = self.maxFontSize
            self.textField.font = .systemFont(ofSize: self.maxFontSize, weight: .regular)
            self.textField.maximumNumberOfLines = 1
            self.textField.stringValue = ""
            self.resizeToFit(lines: 1, font: self.maxFontSize, animate: false)
            self.anchorAtBottomCenter(height: self.panel.frame.height)
            self.panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                self.panel.animator().alphaValue = 1.0
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                self.panel.animator().alphaValue = 0
            }, completionHandler: {
                self.panel.orderOut(nil)
            })
        }
    }

    // MARK: - Public updates

    func setMode(_ mode: Mode) {
        DispatchQueue.main.async {
            switch mode {
            case .recording:
                self.statusLabel.stringValue = Strings.statusRecording
                self.statusLabel.textColor = NSColor.systemRed
                self.hintLabel.stringValue = Strings.hintRecording
            case .paused:
                self.statusLabel.stringValue = Strings.statusPaused
                self.statusLabel.textColor = NSColor.systemYellow
                self.hintLabel.stringValue = Strings.hintPaused
            case .finalizing:
                self.statusLabel.stringValue = Strings.statusFinalizing
                self.statusLabel.textColor = NSColor.secondaryLabelColor
                self.hintLabel.stringValue = Strings.hintProcessing
            case .polishing:
                self.statusLabel.stringValue = Strings.statusPolishing
                self.statusLabel.textColor = NSColor.systemPurple
                self.hintLabel.stringValue = Strings.hintProcessing
            case .reviewing(let isPolished):
                if isPolished {
                    self.statusLabel.stringValue = Strings.statusPolished
                    self.statusLabel.textColor = NSColor.systemPurple
                    self.hintLabel.stringValue = Strings.hintReviewPolished
                } else {
                    self.statusLabel.stringValue = Strings.statusOriginal
                    self.statusLabel.textColor = NSColor.systemBlue
                    self.hintLabel.stringValue = Strings.hintReviewOriginal
                }
            case .error(let msg):
                self.statusLabel.stringValue = Strings.statusError
                self.statusLabel.textColor = NSColor.systemOrange
                self.hintLabel.stringValue = msg
            }
        }
    }

    func setText(_ text: String) {
        DispatchQueue.main.async {
            self.apply(text: text)
        }
    }

    // MARK: - Sizing

    private func apply(text: String) {
        let textWidth = windowWidth - 2 * horizontalPadding

        // Compute best font + line count
        var chosenFont: CGFloat = maxFontSize
        var lineCount: Int = 1
        var displayText = text

        if !text.isEmpty {
            var size = maxFontSize
            var fits = false
            while size >= minFontSize {
                let font = NSFont.systemFont(ofSize: size, weight: .regular)
                let lh = font.boundingRectForFont.height
                let bounds = (text as NSString).boundingRect(
                    with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font]
                )
                let lines = max(1, Int(ceil(bounds.height / lh)))
                if lines <= maxLines {
                    chosenFont = size
                    lineCount = lines
                    fits = true
                    break
                }
                size -= 1
            }
            if !fits {
                // Pin at min font + max lines; head-truncate the displayed string.
                chosenFont = minFontSize
                lineCount = maxLines
                displayText = headTruncate(text, font: NSFont.systemFont(ofSize: minFontSize, weight: .regular),
                                           width: textWidth, maxLines: maxLines)
            }
        }

        // Apply font + max lines first (cheap, no jitter)
        if abs(currentFontSize - chosenFont) > 0.1 {
            textField.font = .systemFont(ofSize: chosenFont, weight: .regular)
        }
        if textField.maximumNumberOfLines != lineCount {
            textField.maximumNumberOfLines = lineCount
        }
        textField.stringValue = displayText

        // Only resize window when geometry actually changes
        let geometryChanged = (chosenFont != currentFontSize) || (lineCount != currentLineCount)
        if geometryChanged {
            currentFontSize = chosenFont
            currentLineCount = lineCount
            resizeToFit(lines: lineCount, font: chosenFont, animate: true)
        }
    }

    private func resizeToFit(lines: Int, font fontSize: CGFloat, animate: Bool) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = font.boundingRectForFont.height
        let textBlockHeight = lineHeight * CGFloat(lines) + 4
        let totalHeight = topPadding + statusHeight + gapBelowStatus + textBlockHeight + bottomPadding

        var frame = panel.frame
        frame.size.height = totalHeight
        frame.origin.y = bottomLeftAnchor.y  // bottom-anchored — grows upward

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    /// Drop characters from the head, prefixed with "…", until the result fits in `maxLines` at `font`.
    private func headTruncate(_ text: String, font: NSFont, width: CGFloat, maxLines: Int) -> String {
        let lineH = font.boundingRectForFont.height
        let maxHeight = lineH * CGFloat(maxLines) + 2

        // Binary-ish: drop in 5% chunks until it fits
        var s = text
        let stepFraction = 0.05
        while !s.isEmpty {
            let candidate = "…" + s
            let bounds = (candidate as NSString).boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            if bounds.height <= maxHeight { return candidate }
            let drop = max(1, Int(Double(s.count) * stepFraction))
            s = String(s.dropFirst(drop))
        }
        return "…"
    }
}
