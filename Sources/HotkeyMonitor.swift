import AppKit

/// Global hotkey monitor.
///
/// Detects:
///   - solo right-⌘ press-release → onRightCmdToggle
///   - solo Alt (either side) press-release → onAltToggle
///   - Esc keyDown → onEscape (ONLY when `consumeEsc == true`; the event is then swallowed)
///
/// Uses `.defaultTap` so we can selectively CONSUME the Esc key when our overlay
/// is visible. All other events pass through unchanged.
final class HotkeyMonitor {
    private let onRightCmdToggle: () -> Void
    private let onAltToggle: () -> Void
    private let onEscape: () -> Void
    private let onSpaceToggle: () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var rightCmdDown = false
    private var otherKeyWhileRightCmd = false

    private var altDown = false
    private var otherKeyWhileAlt = false

    // Track space-key press window so we only fire on a "solo" Space (no
    // modifiers held, no other keys pressed between down and up).
    private var spaceDown = false
    private var otherKeyWhileSpace = false
    private var spaceDownHadModifiers = false

    /// When true, Esc keyDown is swallowed (doesn't reach other apps).
    var consumeEsc: Bool = false
    /// When true, solo-Space keyDown/keyUp is swallowed and reported via onSpaceToggle.
    /// When false, Space passes through untouched.
    var consumeSpace: Bool = false

    private static let rightCmdMask: UInt64 = 0x10
    private static let altAnyMask: UInt64 = CGEventFlags.maskAlternate.rawValue
    private static let escKeyCode: CGKeyCode = 53
    private static let spaceKeyCode: CGKeyCode = 49  // kVK_Space
    // Mask of modifier flags that, if any are set, disqualify a Space press as "solo".
    // (We let plain Space + caps-lock through; caps-lock is in maskAlphaShift.)
    private static let spaceDisqualifyingModMask: UInt64 =
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskSecondaryFn.rawValue

    private(set) var isActive: Bool = false

    init(onRightCmdToggle: @escaping () -> Void,
         onAltToggle: @escaping () -> Void,
         onEscape: @escaping () -> Void,
         onSpaceToggle: @escaping () -> Void) {
        self.onRightCmdToggle = onRightCmdToggle
        self.onAltToggle = onAltToggle
        self.onEscape = onEscape
        self.onSpaceToggle = onSpaceToggle
    }

    @discardableResult
    func start() -> Bool {
        if eventTap != nil { return true }

        let mask = (1 << CGEventType.flagsChanged.rawValue) |
                   (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.keyUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // .defaultTap (options: []) lets us return nil from the callback to swallow events.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: Self.tapCallback,
            userInfo: selfPtr
        ) else {
            NSLog("Murmur: CGEvent.tapCreate FAILED — Accessibility permission missing.")
            isActive = false
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("Murmur: CGEvent tap installed (consume mode).")
        isActive = true
        return true
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
        let consume = monitor.handle(event: event, type: type)
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    /// Returns `true` to consume (drop) the event, `false` to let it pass through.
    private func handle(event: CGEvent, type: CGEventType) -> Bool {
        switch type {
        case .flagsChanged:
            let flags = event.flags.rawValue
            let rightCmdNow = (flags & Self.rightCmdMask) != 0
            let altNow = (flags & Self.altAnyMask) != 0

            if rightCmdNow && !rightCmdDown {
                rightCmdDown = true
                otherKeyWhileRightCmd = false
            } else if !rightCmdNow && rightCmdDown {
                rightCmdDown = false
                if !otherKeyWhileRightCmd {
                    NSLog("Murmur: solo right-⌘")
                    DispatchQueue.main.async { [weak self] in self?.onRightCmdToggle() }
                }
            }

            if altNow && !altDown {
                altDown = true
                otherKeyWhileAlt = false
            } else if !altNow && altDown {
                altDown = false
                if !otherKeyWhileAlt {
                    NSLog("Murmur: solo Alt")
                    DispatchQueue.main.async { [weak self] in self?.onAltToggle() }
                }
            }
            return false  // never consume flag events

        case .keyDown:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if rightCmdDown { otherKeyWhileRightCmd = true }
            if altDown { otherKeyWhileAlt = true }
            // Any non-space keyDown while Space is held disqualifies it as a "solo" press.
            if spaceDown && keyCode != Self.spaceKeyCode { otherKeyWhileSpace = true }

            if keyCode == Self.escKeyCode && consumeEsc {
                NSLog("Murmur: consuming Esc keyDown")
                DispatchQueue.main.async { [weak self] in self?.onEscape() }
                return true
            }

            if keyCode == Self.spaceKeyCode && consumeSpace {
                // Only intercept genuine solo Space (no modifiers, not autorepeat).
                let flags = event.flags.rawValue
                let hasMods = (flags & Self.spaceDisqualifyingModMask) != 0
                if isAutorepeat {
                    // Suppress autorepeated Space while in pause-toggle mode so we
                    // don't spam pause/resume; still consume to avoid leaking spaces.
                    return true
                }
                if !spaceDown {
                    spaceDown = true
                    otherKeyWhileSpace = false
                    spaceDownHadModifiers = hasMods
                }
                if hasMods {
                    // Modifier-combo: let the host app handle it.
                    return false
                }
                return true
            }
            return false

        case .keyUp:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == Self.escKeyCode && consumeEsc {
                // Consume the matching keyUp so apps don't see a phantom release.
                return true
            }
            if keyCode == Self.spaceKeyCode {
                let wasDown = spaceDown
                let wasSolo = wasDown && !otherKeyWhileSpace && !spaceDownHadModifiers
                spaceDown = false
                otherKeyWhileSpace = false
                spaceDownHadModifiers = false
                if consumeSpace && wasSolo {
                    NSLog("Murmur: solo Space — toggle pause")
                    DispatchQueue.main.async { [weak self] in self?.onSpaceToggle() }
                    return true
                }
            }
            return false

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            NSLog("Murmur: tap disabled by system; re-enabling")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false

        default:
            return false
        }
    }
}
