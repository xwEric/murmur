import AppKit

/// Bottom-center overlay, Spokenly-style. Single window for live + review.
///
/// Sizing rules:
///   - Starts at 1-line capacity
///   - Grows up to 4 lines as text wraps
///   - When text exceeds 4 lines at 18 pt: font shrinks down to 10 pt
///   - When even at 4 lines + 10 pt the text still overflows: keep height fixed
///     and let the inner NSScrollView take over (vertical scroll, auto-scrolled
///     to the latest content)
///   - Window anchors at its bottom edge so growth pushes upward
///   - Fully opaque (1.0 alpha)
final class LiveTextWindow {
    enum Mode {
        case recording
        case finalizing
        case polishing
        case reviewing(isPolished: Bool)
        case error(String)
        case paused
    }

    private let panel: NSPanel
    private let effectView: NSVisualEffectView
    private let textScroll: NSScrollView
    private let textView: NSTextView
    private let statusLabel: NSTextField
    private let hintLabel: NSTextField

    // Layout constants
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
    private var currentScrolling: Bool = false
    private var bottomLeftAnchor: NSPoint = .zero

    init() {
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
        p.ignoresMouseEvents = false  // allow scrolling with mouse wheel
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.alphaValue = 0.0

        let effect = NSVisualEffectView(frame: p.contentView!.bounds)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]

        // 9-slice maskImage so rounded corners + window shadow stay aligned.
        let radius: CGFloat = 14
        let edge = ceil(radius * 2 + 1)
        let mask = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        mask.resizingMode = .stretch
        effect.maskImage = mask

        p.contentView = effect
        p.invalidateShadow()

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

        // Scrollable text area
        let scroll = NSScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .none

        let tv = NSTextView(frame: .zero)
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textColor = NSColor.labelColor
        tv.font = .systemFont(ofSize: 18, weight: .regular)
        tv.textContainerInset = NSSize(width: 0, height: 0)
        tv.textContainer?.lineFragmentPadding = 0
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = .width
        tv.textContainer?.widthTracksTextView = true
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = tv

        effect.addSubview(scroll)

        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            status.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),

            hint.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            hint.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            hint.leadingAnchor.constraint(greaterThanOrEqualTo: status.trailingAnchor, constant: 12),

            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -14),
        ])

        self.panel = p
        self.effectView = effect
        self.textScroll = scroll
        self.textView = tv
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
            self.currentScrolling = false
            self.textView.font = .systemFont(ofSize: self.maxFontSize, weight: .regular)
            self.textView.string = ""
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
            case .paused:
                self.statusLabel.stringValue = Strings.statusPaused
                self.statusLabel.textColor = NSColor.systemYellow
                self.hintLabel.stringValue = Strings.hintPaused
            }
        }
    }

    func setText(_ text: String) {
        DispatchQueue.main.async {
            self.apply(text: text)
        }
    }

    // MARK: - Sizing

    /// Picks the largest font (≤ 18 pt) that lets `text` fit within `maxLines`.
    /// If even at `minFontSize` the text still overflows, we cap the window at
    /// maxLines and let NSScrollView handle scrolling (auto-scrolled to bottom).
    private func apply(text: String) {
        let textWidth = windowWidth - 2 * horizontalPadding

        var chosenFont: CGFloat = maxFontSize
        var lineCount: Int = 1
        var willScroll: Bool = false

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
                // Cap at maxLines × minFont; scroll handles the rest.
                chosenFont = minFontSize
                lineCount = maxLines
                willScroll = true
            }
        }

        // Apply font + text
        if abs(currentFontSize - chosenFont) > 0.1 {
            textView.font = .systemFont(ofSize: chosenFont, weight: .regular)
        }
        if textView.string != text {
            textView.string = text
        }

        // Auto-scroll to the end so the latest words are visible.
        // (NSTextView coordinate system: flipped, bottom = end of doc.)
        if willScroll {
            textView.scrollToEndOfDocument(nil)
        } else {
            // Reset scroll position to top so the visible area is aligned.
            textView.scroll(.zero)
        }

        // Only resize the window when geometry actually changes.
        let geometryChanged = (chosenFont != currentFontSize) ||
                              (lineCount != currentLineCount) ||
                              (willScroll != currentScrolling)
        if geometryChanged {
            currentFontSize = chosenFont
            currentLineCount = lineCount
            currentScrolling = willScroll
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
        panel.invalidateShadow()
    }
}
