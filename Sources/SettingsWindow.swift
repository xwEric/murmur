import AppKit

struct LangOption {
    let code: String
    let display: String
}

let SonioxLanguages: [LangOption] = [
    LangOption(code: "zh", display: "中文"),
    LangOption(code: "en", display: "English"),
    LangOption(code: "ja", display: "日本語"),
    LangOption(code: "ko", display: "한국어"),
    LangOption(code: "es", display: "Español"),
    LangOption(code: "fr", display: "Français"),
    LangOption(code: "de", display: "Deutsch"),
    LangOption(code: "ru", display: "Русский"),
    LangOption(code: "pt", display: "Português"),
    LangOption(code: "it", display: "Italiano"),
    LangOption(code: "nl", display: "Nederlands"),
    LangOption(code: "pl", display: "Polski"),
    LangOption(code: "tr", display: "Türkçe"),
    LangOption(code: "ar", display: "العربية"),
    LangOption(code: "hi", display: "हिन्दी"),
    LangOption(code: "th", display: "ภาษาไทย"),
    LangOption(code: "vi", display: "Tiếng Việt"),
    LangOption(code: "uk", display: "Українська"),
]

/// Available models per polish backend. Keys are exact backend strings.
let PolishModels: [String: [String]] = [
    "claude": ["sonnet", "haiku", "opus"],
    "codex":  ["gpt-5-codex", "gpt-5", "gpt-4o", "o3-mini"],
]

let SonioxModels: [String] = ["stt-rt-preview"]

final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private let onSaved: (Config) -> Void

    private var apiKeyField: NSSecureTextField!
    private var sonioxModelPopup: NSPopUpButton!
    private var langCheckboxes: [String: NSButton] = [:]
    private var speakerLockCheckbox: NSButton!
    private var backendPopup: NSPopUpButton!
    private var polishModelPopup: NSPopUpButton!
    private var polishPromptTextView: PlaceholderTextView!

    init(onSaved: @escaping (Config) -> Void) {
        self.onSaved = onSaved
        super.init()
    }

    func show() {
        if window == nil { build() }
        let current = (try? Config.load()) ?? Config(
            apiKey: "",
            model: Config.defaultSonioxModel,
            languageHints: Config.defaultLanguageHints,
            polishBackend: Config.defaultPolishBackend,
            polishModel: Config.defaultPolishModelClaude,
            speakerLock: false,
            polishPrompt: ""
        )
        apiKeyField.stringValue = current.apiKey

        // Soniox model: ensure current is in the popup list, else add it
        if !SonioxModels.contains(current.model) {
            sonioxModelPopup.addItem(withTitle: current.model)
        }
        sonioxModelPopup.selectItem(withTitle: current.model)

        // Language checkboxes
        let selected = Set(current.languageHints)
        for (code, box) in langCheckboxes {
            box.state = selected.contains(code) ? .on : .off
        }

        // Speaker lock
        speakerLockCheckbox.state = current.speakerLock ? .on : .off

        // Backend
        backendPopup.selectItem(withTitle: current.polishBackend)
        rebuildPolishModelOptions(currentModel: current.polishModel)

        // Polish prompt: text or empty (placeholder shows default)
        polishPromptTextView.string = current.polishPrompt

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let w: CGFloat = 560

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = Strings.settingsTitle
        window.delegate = self
        window.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        window.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        // API key (still a secure text field; the only free-text input)
        apiKeyField = NSSecureTextField()
        apiKeyField.placeholderString = "soniox API key"
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeRow(label: Strings.settingsSonioxKey, field: apiKeyField, width: w))

        // Soniox model dropdown
        sonioxModelPopup = NSPopUpButton()
        sonioxModelPopup.addItems(withTitles: SonioxModels)
        sonioxModelPopup.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeRow(label: Strings.settingsSonioxModel, field: sonioxModelPopup, width: w))

        // Language multi-select grid
        stack.addArrangedSubview(makeLangSection(width: w))

        // Speaker lock toggle
        speakerLockCheckbox = NSButton(checkboxWithTitle: Strings.settingsSpeakerLock,
                                       target: nil, action: nil)
        let speakerHelp = NSTextField(labelWithString: Strings.settingsSpeakerLockHelp)
        speakerHelp.font = .systemFont(ofSize: 10)
        speakerHelp.textColor = NSColor.tertiaryLabelColor
        let speakerStack = NSStackView(views: [speakerLockCheckbox, speakerHelp])
        speakerStack.orientation = .vertical
        speakerStack.alignment = .leading
        speakerStack.spacing = 2
        stack.addArrangedSubview(speakerStack)

        // Polish backend dropdown
        backendPopup = NSPopUpButton()
        backendPopup.addItems(withTitles: ["claude", "codex"])
        backendPopup.target = self
        backendPopup.action = #selector(backendChanged)
        backendPopup.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeRow(label: Strings.settingsPolishBackend, field: backendPopup, width: w))

        // Polish model dropdown (populated based on backend)
        polishModelPopup = NSPopUpButton()
        polishModelPopup.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeRow(label: Strings.settingsPolishModel, field: polishModelPopup, width: w))

        // Polish prompt (multi-line editable with placeholder)
        let promptScroll = NSScrollView()
        promptScroll.borderType = .bezelBorder
        promptScroll.hasVerticalScroller = true
        promptScroll.autohidesScrollers = true
        promptScroll.translatesAutoresizingMaskIntoConstraints = false

        polishPromptTextView = PlaceholderTextView(frame: .zero)
        polishPromptTextView.placeholderString = Polisher.defaultSystemPrompt
        polishPromptTextView.font = .systemFont(ofSize: 12)
        polishPromptTextView.textColor = NSColor.labelColor
        polishPromptTextView.backgroundColor = NSColor.textBackgroundColor
        polishPromptTextView.isEditable = true
        polishPromptTextView.isRichText = false
        polishPromptTextView.isAutomaticQuoteSubstitutionEnabled = false
        polishPromptTextView.isAutomaticDashSubstitutionEnabled = false
        polishPromptTextView.allowsUndo = true
        polishPromptTextView.textContainerInset = NSSize(width: 4, height: 4)
        promptScroll.documentView = polishPromptTextView

        stack.addArrangedSubview(makePromptRow(label: Strings.settingsPolishPrompt,
                                               scroll: promptScroll, width: w))

        // Buttons
        let cancelBtn = NSButton(title: Strings.settingsCancel, target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        let saveBtn = NSButton(title: Strings.settingsSave, target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        let buttonRow = NSStackView(views: [spacer, cancelBtn, saveBtn])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(buttonRow)
        NSLayoutConstraint.activate([
            buttonRow.widthAnchor.constraint(equalToConstant: w - 48),
            spacer.heightAnchor.constraint(equalToConstant: 1),
        ])

        window.setContentSize(stack.fittingSize)
    }

    private func makeRow(label: String, field: NSView, width: CGFloat) -> NSView {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = NSColor.secondaryLabelColor
        let row = NSStackView(views: [lbl, field])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: width - 48),
        ])
        return row
    }

    private func makePromptRow(label: String, scroll: NSView, width: CGFloat) -> NSView {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = NSColor.secondaryLabelColor
        let row = NSStackView(views: [lbl, scroll])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: width - 48),
            scroll.heightAnchor.constraint(equalToConstant: 80),
        ])
        return row
    }

    private func makeLangSection(width: CGFloat) -> NSView {
        let title = NSTextField(labelWithString: Strings.settingsLangHints)
        title.font = .systemFont(ofSize: 11, weight: .semibold)
        title.textColor = NSColor.secondaryLabelColor

        let columns = 3
        let rowsPerCol = (SonioxLanguages.count + columns - 1) / columns
        var rows: [NSStackView] = []
        for r in 0..<rowsPerCol {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .firstBaseline
            rowStack.spacing = 12
            rowStack.distribution = .fillEqually
            for c in 0..<columns {
                let idx = c * rowsPerCol + r
                if idx < SonioxLanguages.count {
                    let lang = SonioxLanguages[idx]
                    let cb = NSButton(checkboxWithTitle: "\(lang.display)  (\(lang.code))",
                                      target: nil, action: nil)
                    cb.translatesAutoresizingMaskIntoConstraints = false
                    langCheckboxes[lang.code] = cb
                    rowStack.addArrangedSubview(cb)
                } else {
                    rowStack.addArrangedSubview(NSView())
                }
            }
            rows.append(rowStack)
        }

        let grid = NSStackView(views: rows)
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 6
        grid.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView(views: [title, grid])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.widthAnchor.constraint(equalToConstant: width - 48),
        ])
        return container
    }

    private func rebuildPolishModelOptions(currentModel: String?) {
        let backend = backendPopup.titleOfSelectedItem ?? "claude"
        let options = PolishModels[backend] ?? ["sonnet"]
        polishModelPopup.removeAllItems()
        polishModelPopup.addItems(withTitles: options)
        if let m = currentModel, options.contains(m) {
            polishModelPopup.selectItem(withTitle: m)
        } else {
            // Pick a sensible default for this backend
            let def = backend == "codex" ? Config.defaultPolishModelCodex : Config.defaultPolishModelClaude
            if options.contains(def) {
                polishModelPopup.selectItem(withTitle: def)
            } else {
                polishModelPopup.selectItem(at: 0)
            }
        }
    }

    @objc private func backendChanged() {
        rebuildPolishModelOptions(currentModel: nil)
    }

    @objc private func cancel() { window.close() }

    @objc private func save() {
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !apiKey.isEmpty else {
            let alert = NSAlert()
            alert.messageText = Strings.settingsSonioxKey
            alert.informativeText = "API key required."
            alert.runModal()
            return
        }

        let sonioxModel = sonioxModelPopup.titleOfSelectedItem ?? Config.defaultSonioxModel

        var selectedCodes: [String] = []
        for lang in SonioxLanguages {
            if langCheckboxes[lang.code]?.state == .on { selectedCodes.append(lang.code) }
        }
        if selectedCodes.isEmpty { selectedCodes = Config.defaultLanguageHints }

        let backend = backendPopup.titleOfSelectedItem ?? Config.defaultPolishBackend
        let polishModel = polishModelPopup.titleOfSelectedItem
            ?? (backend == "codex" ? Config.defaultPolishModelCodex : Config.defaultPolishModelClaude)

        // Polish prompt: store whatever user typed (trimmed). Empty = use built-in default.
        let polishPrompt = polishPromptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        let cfg = Config(
            apiKey: apiKey,
            model: sonioxModel,
            languageHints: selectedCodes,
            polishBackend: backend,
            polishModel: polishModel,
            speakerLock: speakerLockCheckbox.state == .on,
            polishPrompt: polishPrompt
        )
        do {
            try cfg.save()
            onSaved(cfg)
            window.close()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Save failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
