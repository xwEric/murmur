import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private let state = AppState()
    private var hotkey: HotkeyMonitor!
    private var recorder: AudioRecorder!
    private var stt: STTClient?
    private var config: Config!
    private var permissionPollTimer: Timer?
    private let liveWindow = LiveTextWindow()
    private var settingsWindow: SettingsWindow?
    private var targetApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Murmur: applicationDidFinishLaunching")

        // Install a minimal application main menu so Cmd+X/C/V/A and Cmd+Z/Z+Shift
        // work in Settings text fields. Without this, .accessory apps have no
        // Edit menu in the responder chain and the keystrokes are no-ops.
        installMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Read UI language from config BEFORE building the menu (so labels render correctly).
        // Missing config or load error → English default.
        if let cfg = try? Config.load() {
            Strings.applyConfigLanguage(cfg.uiLanguage)
        }

        buildMenu()
        updateMenuBarIcon()

        do {
            config = try Config.load()
        } catch {
            NSLog("Murmur: config load failed: \(error)")
            showAlert(title: Strings.alertConfigMissing,
                      body: error.localizedDescription,
                      style: .critical)
            // Open settings to let user enter API key right away
            openSettings()
            return
        }

        recorder = AudioRecorder()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            NSLog("Murmur: mic permission granted=\(granted)")
        }

        hotkey = HotkeyMonitor(
            onRightCmdToggle: { [weak self] in self?.onRightCmd() },
            onAltToggle:      { [weak self] in self?.onAlt() },
            onEscape:         { [weak self] in self?.onEsc() },
            onSpaceToggle:    { [weak self] in self?.onSpace() }
        )

        // Consume Esc only when our overlay is active (phase != .idle).
        // Consume Space only while actively recording or paused (so the user
        // can toggle pause/resume without typing a space character).
        state.onChange = { [weak self] phase in
            guard let self = self else { return }
            self.hotkey.consumeEsc = (phase != .idle)
            self.hotkey.consumeSpace = (phase == .recording || phase == .paused)
        }

        attemptHotkeyStart(promptIfMissing: true)
    }

    // MARK: - Hotkey handlers

    private func onRightCmd() {
        switch state.phase {
        case .idle:        startRecording()
        case .recording:   stopRecording(autoInsert: true, autoPolish: false)
        case .paused:      stopRecording(autoInsert: true, autoPolish: false)
        case .reviewing:   commitCurrent()
        case .finalizing, .polishing:
            NSLog("Murmur: right⌘ ignored — phase=\(state.phase)")
        }
    }

    private func onAlt() {
        switch state.phase {
        case .idle:
            return
        case .recording:
            stopRecording(autoInsert: false, autoPolish: true)
        case .paused:
            stopRecording(autoInsert: false, autoPolish: true)
        case .reviewing:
            if state.polished != nil {
                state.displayingPolished.toggle()
                liveWindow.setText(state.currentText)
                liveWindow.setMode(.reviewing(isPolished: state.displayingPolished))
            } else {
                triggerPolish()
            }
        case .finalizing, .polishing:
            NSLog("Murmur: Alt ignored — phase=\(state.phase)")
        }
    }

    private func onEsc() {
        guard state.phase != .idle else { return }
        NSLog("Murmur: Esc — cancel session (phase=\(state.phase))")
        recorder?.stop()
        stt?.cancel()
        stt = nil
        liveWindow.hide()
        state.resetSession()
        state.set(.idle)
    }

    private func onSpace() {
        switch state.phase {
        case .recording:
            NSLog("Murmur: Space — pause")
            recorder.pause()
            state.set(.paused)
            liveWindow.setMode(.paused)
        case .paused:
            let aliveSocket = stt?.isAlive ?? false
            NSLog("Murmur: Space — resume (socket alive=\(aliveSocket))")
            do {
                try recorder.resume()
                if !aliveSocket {
                    // Socket timed out during pause. Promote what we already have
                    // to "committed" and start a fresh STT session that appends.
                    state.promoteSessionToCommitted()
                    let client = makeSTTClient()
                    client.connect()
                    stt = client
                    recorder.onAudio = { [weak client] data in client?.sendAudio(data) }
                    liveWindow.setText(state.raw)  // refresh display with committed text
                }
                state.set(.recording)
                liveWindow.setMode(.recording)
            } catch {
                NSLog("Murmur: recorder.resume() error: \(error)")
                liveWindow.setMode(.error(error.localizedDescription))
            }
        default:
            break
        }
    }

    // MARK: - Recording flow

    private func startRecording() {
        NSLog("Murmur: startRecording")
        state.resetSession()

        // Validate config (API keys must be present for the selected provider).
        // Fast sync check — no shell forks, no HTTP. The actual STT connect happens below.
        if let err = config.validate() {
            NSLog("Murmur: config invalid — \(err)")
            showSettingsAlert(title: Strings.alertSTTNeedSetup,
                              body: Strings.alertSTTNeedSetupBody + "\n\n" + err)
            state.set(.idle)
            return
        }

        // Snapshot the frontmost app for focus restoration before pasting.
        targetApp = NSWorkspace.shared.frontmostApplication
        NSLog("Murmur: target app at record-start = \(targetApp?.localizedName ?? "?") pid=\(targetApp?.processIdentifier ?? -1)")

        if config.playSounds { SoundPlayer.start() }
        state.set(.recording)
        liveWindow.show()
        liveWindow.setMode(.recording)
        liveWindow.setText("")

        let client = makeSTTClient()
        client.connect()
        stt = client

        recorder.onAudio = { [weak client] data in client?.sendAudio(data) }
        do {
            try recorder.start()
        } catch {
            NSLog("Murmur: recorder.start() error: \(error)")
            liveWindow.setMode(.error("\(Strings.errMicStartFail): \(error.localizedDescription)"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.liveWindow.hide()
                self.state.set(.idle)
            }
            stt?.cancel()
            stt = nil
            return
        }

        // Parallel mic-permission probe — never blocks the start path.
        verifyMicPermissionInBackground()
    }

    /// Builds + wires an STTClient via the factory. Used both for initial connect and
    /// for mid-recording reconnect (when the socket dies during pause).
    private func makeSTTClient() -> STTClient {
        let client = STTClientFactory.make(config: config)
        client.onLiveUpdate = { [weak self] text in
            guard let self = self else { return }
            self.state.sessionText = text
            if self.state.phase == .recording || self.state.phase == .paused {
                self.liveWindow.setText(self.state.raw)
            }
        }
        client.onFinalText = { [weak self] text in
            guard let self = self else { return }
            NSLog("Murmur: final text length=\(text.count) autoPolish=\(self.state.autoPolishAfterFinalize) autoInsert=\(self.state.autoInsertAfterFinalize)")
            DispatchQueue.main.async {
                self.state.sessionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = self.state.raw.trimmingCharacters(in: .whitespacesAndNewlines)
                self.stt = nil

                if combined.isEmpty {
                    self.liveWindow.setMode(.error(Strings.errEmptyTranscription))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.liveWindow.hide()
                        self.state.resetSession()
                        self.state.set(.idle)
                    }
                    return
                }
                self.liveWindow.setText(combined)

                if self.state.autoInsertAfterFinalize {
                    self.liveWindow.hide()
                    let target = self.targetApp
                    self.state.resetSession()
                    self.state.set(.idle)
                    TextInjector.inject(combined, targetApp: target)
                } else if self.state.autoPolishAfterFinalize {
                    self.state.set(.reviewing)
                    self.triggerPolish()
                } else {
                    self.state.set(.reviewing)
                    self.liveWindow.setMode(.reviewing(isPolished: false))
                }
            }
        }
        client.onError = { [weak self] err in
            guard let self = self else { return }
            NSLog("Murmur: STT error: \(err.localizedDescription) (phase=\(self.state.phase))")
            DispatchQueue.main.async {
                // If we're paused, the socket likely timed out — don't tear down.
                // We'll reconnect on resume via onSpace().
                if self.state.phase == .paused {
                    NSLog("Murmur: socket lost while paused — will reconnect on resume")
                    return
                }
                self.recorder.stop()
                self.liveWindow.setMode(.error(err.localizedDescription))
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.liveWindow.hide()
                    self.state.resetSession()
                    self.state.set(.idle)
                }
                self.stt = nil
            }
        }
        return client
    }

    /// Non-blocking microphone permission check. If status is denied or the user
    /// rejects the just-shown prompt, we abort the in-flight recording and show
    /// a popup directing them to System Settings.
    private func verifyMicPermissionInBackground() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return  // happy path
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.abortRecording(reason: "mic denied")
                self?.showMicPermissionAlert()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    NSLog("Murmur: mic request returned granted=\(granted)")
                    if !granted {
                        self?.abortRecording(reason: "mic denied (just prompted)")
                        self?.showMicPermissionAlert()
                    }
                }
            }
        @unknown default:
            return
        }
    }

    private func abortRecording(reason: String) {
        NSLog("Murmur: abortRecording — \(reason)")
        recorder.stop()
        stt?.cancel()
        stt = nil
        liveWindow.hide()
        state.resetSession()
        state.set(.idle)
    }

    private func showMicPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = Strings.alertMicNeeded
        alert.informativeText = Strings.alertMicNeededBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: Strings.btnOpenMicSettings)
        alert.addButton(withTitle: Strings.btnLater)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func stopRecording(autoInsert: Bool, autoPolish: Bool) {
        NSLog("Murmur: stopRecording autoInsert=\(autoInsert) autoPolish=\(autoPolish)")
        if config?.playSounds ?? true { SoundPlayer.stop() }
        recorder.stop()
        state.autoInsertAfterFinalize = autoInsert
        state.autoPolishAfterFinalize = autoPolish
        state.set(.finalizing)
        liveWindow.setMode(.finalizing)
        stt?.finish()
    }

    // MARK: - Polish

    private func triggerPolish() {
        guard !state.raw.isEmpty else {
            state.set(.reviewing)
            liveWindow.setMode(.reviewing(isPolished: false))
            return
        }

        // Fast sync pre-flight: instant config-only check (no shell fork, no HTTP).
        // The real polish call below runs on a background queue so failures from the
        // backend itself surface async via the failure branch.
        if let err = Polisher.validateConfig(backend: config.polishBackend,
                                              apiBaseUrl: config.polishApiBaseUrl,
                                              apiKey: config.polishApiKey) {
            NSLog("Murmur: polish pre-flight failed — \(err)")
            // Fall through to reviewing-original so the user can still commit raw text.
            state.displayingPolished = false
            state.set(.reviewing)
            liveWindow.setText(state.raw)
            liveWindow.setMode(.reviewing(isPolished: false))
            showSettingsAlert(title: Strings.alertPolishError,
                              body: Strings.alertPolishErrorBody + "\n\n" + err)
            return
        }

        NSLog("Murmur: polish via \(config.polishBackend)/\(config.polishModel) on \(state.raw.count) chars")
        state.set(.polishing)
        liveWindow.setMode(.polishing)

        let raw = state.raw
        Polisher.polish(raw,
                        backend: config.polishBackend,
                        model: config.polishModel,
                        systemPrompt: config.polishPrompt,
                        apiBaseUrl: config.polishApiBaseUrl,
                        apiKey: config.polishApiKey) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let polished):
                NSLog("Murmur: polish success: \(polished.count) chars")
                self.state.polished = polished
                self.state.displayingPolished = true
                self.state.set(.reviewing)
                self.liveWindow.setText(polished)
                self.liveWindow.setMode(.reviewing(isPolished: true))
            case .failure(let err):
                NSLog("Murmur: polish failure: \(err.localizedDescription)")
                self.state.displayingPolished = false
                self.state.set(.reviewing)
                // Revert overlay to raw text so user can still commit.
                self.liveWindow.setText(self.state.raw)
                self.liveWindow.setMode(.reviewing(isPolished: false))
                self.showSettingsAlert(title: Strings.alertPolishError,
                                       body: Strings.alertPolishErrorBody + "\n\n" + err.localizedDescription)
            }
        }
    }

    private func commitCurrent() {
        let text = state.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("Murmur: commitCurrent — inserting \(text.count) chars (polished=\(state.displayingPolished))")
        liveWindow.hide()
        let target = targetApp
        state.resetSession()
        state.set(.idle)
        if !text.isEmpty { TextInjector.inject(text, targetApp: target) }
    }

    // MARK: - Permissions

    private func attemptHotkeyStart(promptIfMissing: Bool) {
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": promptIfMissing] as CFDictionary)
        NSLog("Murmur: AXIsProcessTrusted = \(trusted)")
        if trusted {
            let ok = hotkey.start()
            updateStatusLine(active: ok)
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            if !ok && promptIfMissing { showPermissionRequiredAlert() }
        } else {
            updateStatusLine(active: false)
            if promptIfMissing { showPermissionRequiredAlert() }
            startPolling()
        }
    }

    private func startPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, AXIsProcessTrusted() else { return }
            NSLog("Murmur: Accessibility newly granted — retrying hotkey start")
            self.permissionPollTimer?.invalidate()
            self.permissionPollTimer = nil
            let ok = self.hotkey.start()
            self.updateStatusLine(active: ok)
            if ok {
                self.showAlert(title: Strings.alertAccessGranted,
                               body: Strings.alertAccessGrantedBody,
                               style: .informational)
            }
        }
    }

    private func showPermissionRequiredAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = Strings.alertAccessNeeded
        alert.informativeText = Strings.alertAccessNeededBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: Strings.btnOpenSettings)
        alert.addButton(withTitle: Strings.btnLater)
        if alert.runModal() == .alertFirstButtonReturn { openAccessibility() }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: Strings.menuStatusStarting, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem(title: Strings.menuTagline, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Strings.menuSettings, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: Strings.menuTestRecording, action: #selector(testToggle), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: Strings.menuRecheckPerms, action: #selector(recheckPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Strings.menuOpenAccess, action: #selector(openAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Strings.menuQuit, action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    private func updateStatusLine(active: Bool) {
        statusMenuItem.title = active ? Strings.menuStatusActive : Strings.menuStatusInactive
    }

    @objc private func testToggle() { onRightCmd() }
    @objc private func recheckPermissions() { attemptHotkeyStart(promptIfMissing: true) }

    /// Loads the menu bar icon from the bundled PNG. The logo has its own white
    /// background, so isTemplate is false (we don't want the system to recolor it).
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        let path = Bundle.main.resourcePath.flatMap { "\($0)/menubar_banana.png" }
        if let p = path, FileManager.default.fileExists(atPath: p),
           let img = NSImage(contentsOfFile: p) {
            img.isTemplate = false
            img.size = NSSize(width: 18, height: 18)
            button.image = img
            button.title = ""
        } else {
            button.title = "⬡"
            button.image = nil
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(
                onSaved: { [weak self] newCfg in
                    guard let self = self else { return }
                    let langChanged = (Strings.isZH != (newCfg.uiLanguage == "zh"))
                    self.config = newCfg
                    Strings.applyConfigLanguage(newCfg.uiLanguage)
                    if langChanged { self.buildMenu() }
                    NSLog("Murmur: config reloaded after settings save (langChanged=\(langChanged))")
                },
                onClose: { [weak self] in
                    self?.settingsWindowDidClose()
                }
            )
        }
        // Promote to a regular app while Settings is open. As .accessory the window
        // is unreliably focusable and can disappear when the user switches apps.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.show()
    }

    private func settingsWindowDidClose() {
        // Drop back to menu-bar-only mode so we don't keep a Dock icon around.
        NSApp.setActivationPolicy(.accessory)
    }

    /// Builds a minimal main menu so standard Cmd+X/C/V/A and Cmd+Z work in
    /// any text field inside the Settings window. Without this, .accessory
    /// apps have no Edit menu in the responder chain, so AppKit drops those
    /// keystrokes silently.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu (first item, title typically replaced by the system with the
        // app name in bold, regardless of what we set here).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Murmur",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        // Edit menu — the critical one. Selectors are forwarded down the
        // responder chain so they hit NSTextField / NSTextView automatically.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo",
                                    action: Selector(("undo:")),
                                    keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo",
                                  action: Selector(("redo:")),
                                  keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut",
                                    action: #selector(NSText.cut(_:)),
                                    keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",
                                    action: #selector(NSText.copy(_:)),
                                    keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",
                                    action: #selector(NSText.paste(_:)),
                                    keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All",
                                    action: #selector(NSText.selectAll(_:)),
                                    keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func showAlert(title: String, body: String, style: NSAlert.Style = .informational) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = style
        alert.runModal()
    }

    /// Modal alert with [Open Settings] [Later] buttons. Opens Settings when the user clicks it.
    /// Used for both STT-not-configured (pre-flight) and polish-failed (post-flight) cases.
    private func showSettingsAlert(title: String, body: String, style: NSAlert.Style = .warning) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = style
        alert.addButton(withTitle: Strings.btnOpenSettings)
        alert.addButton(withTitle: Strings.btnLater)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSettings()
        }
    }
}
