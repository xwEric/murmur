import AppKit

struct LangOption {
    let code: String
    let display: String
}

let DictateLanguages: [LangOption] = [
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
let DeepgramModels: [String] = ["nova-3", "nova-2", "enhanced", "base"]
let OpenAIRealtimeModels: [String] = ["gpt-4o-mini-transcribe", "gpt-4o-transcribe"]

/// Sidebar sections in Settings.
private enum SettingsSection: Int, CaseIterable {
    case general
    case provider
    case polish

    var title: String {
        switch self {
        case .general:  return Strings.settingsSecGeneral
        case .provider: return Strings.settingsSecProvider
        case .polish:   return Strings.settingsSecPolish
        }
    }
}

final class SettingsWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow!
    private let onSaved: (Config) -> Void

    // sidebar
    private var sidebarTable: NSTableView!
    private var detailContainer: NSView!
    private var detailViews: [SettingsSection: NSView] = [:]
    private var currentSection: SettingsSection = .general

    // General section
    private var langCheckboxes: [String: NSButton] = [:]
    private var speakerLockCheckbox: NSButton!

    // Provider section
    private var providerPopup: NSPopUpButton!
    private var providerStack: NSStackView!         // outer stack for provider section
    private var providerPanels: [String: NSView] = [:]
    private var sonioxKeyField: NSSecureTextField!
    private var sonioxModelPopup: NSPopUpButton!
    private var deepgramKeyField: NSSecureTextField!
    private var deepgramModelPopup: NSPopUpButton!
    private var openaiKeyField: NSSecureTextField!
    private var openaiModelPopup: NSPopUpButton!
    private var customBaseUrlField: NSTextField!
    private var customKeyField: NSSecureTextField!
    private var customModelField: NSTextField!

    // Polish section
    private var backendPopup: NSPopUpButton!
    private var polishModelPopup: NSPopUpButton!
    private var polishPromptTextView: PlaceholderTextView!
    // Polish: openai_api specific
    private var polishApiBaseUrlField: NSTextField!
    private var polishApiKeyField: NSSecureTextField!
    private var refreshModelsButton: NSButton!
    private var refreshModelsStatus: NSTextField!
    private var apiPanelStack: NSStackView!
    private var fetchedApiModels: [String] = []

    init(onSaved: @escaping (Config) -> Void) {
        self.onSaved = onSaved
        super.init()
    }

    // MARK: - Public entry point

    func show() {
        if window == nil { build() }
        let current = (try? Config.load()) ?? Config(
            sttProvider: Config.defaultSttProvider,
            sonioxApiKey: "",
            sonioxModel: Config.defaultSonioxModel,
            deepgramApiKey: "",
            deepgramModel: Config.defaultDeepgramModel,
            openaiApiKey: "",
            openaiModel: Config.defaultOpenAIModel,
            customBaseUrl: "",
            customApiKey: "",
            customModel: Config.defaultCustomModel,
            languageHints: Config.defaultLanguageHints,
            polishBackend: Config.defaultPolishBackend,
            polishModel: Config.defaultPolishModelClaude,
            polishPrompt: "",
            speakerLock: false,
            polishApiBaseUrl: Config.defaultPolishApiBaseUrl,
            polishApiKey: ""
        )
        populate(from: current)

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func populate(from c: Config) {
        // General
        let selected = Set(c.languageHints)
        for (code, box) in langCheckboxes { box.state = selected.contains(code) ? .on : .off }
        speakerLockCheckbox.state = c.speakerLock ? .on : .off

        // Provider selection
        providerPopup.selectItem(withTitle: providerDisplay(c.sttProvider))
        showProviderPanel(for: c.sttProvider)

        // Provider field values
        sonioxKeyField.stringValue = c.sonioxApiKey
        if !SonioxModels.contains(c.sonioxModel) { sonioxModelPopup.addItem(withTitle: c.sonioxModel) }
        sonioxModelPopup.selectItem(withTitle: c.sonioxModel)

        deepgramKeyField.stringValue = c.deepgramApiKey
        if !DeepgramModels.contains(c.deepgramModel) { deepgramModelPopup.addItem(withTitle: c.deepgramModel) }
        deepgramModelPopup.selectItem(withTitle: c.deepgramModel)

        openaiKeyField.stringValue = c.openaiApiKey
        if !OpenAIRealtimeModels.contains(c.openaiModel) { openaiModelPopup.addItem(withTitle: c.openaiModel) }
        openaiModelPopup.selectItem(withTitle: c.openaiModel)

        customBaseUrlField.stringValue = c.customBaseUrl
        customKeyField.stringValue = c.customApiKey
        customModelField.stringValue = c.customModel

        // Polish
        polishApiBaseUrlField.stringValue = c.polishApiBaseUrl
        polishApiKeyField.stringValue = c.polishApiKey
        setPolishBackendPopup(toKey: c.polishBackend)
        // Seed the dropdown with the saved model so it's available even before refresh.
        if c.polishBackend == "openai_api" && !c.polishModel.isEmpty {
            fetchedApiModels = [c.polishModel]
        }
        rebuildPolishModelOptions(currentModel: c.polishModel)
        polishPromptTextView.string = c.polishPrompt

        // Default section
        selectSection(currentSection)
    }

    // MARK: - Layout

    private func build() {
        let w: CGFloat = 720
        let h: CGFloat = 520

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = Strings.settingsTitle
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 460)

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        // Sidebar
        let sidebarScroll = NSScrollView()
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.borderType = .noBorder
        sidebarScroll.drawsBackground = false

        sidebarTable = NSTableView()
        sidebarTable.headerView = nil
        sidebarTable.style = .sourceList
        sidebarTable.selectionHighlightStyle = .regular
        sidebarTable.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTable.rowSizeStyle = .medium
        sidebarTable.allowsMultipleSelection = false
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        col.width = 180
        sidebarTable.addTableColumn(col)
        sidebarTable.dataSource = self
        sidebarTable.delegate = self
        sidebarTable.backgroundColor = .clear
        sidebarScroll.documentView = sidebarTable

        // Detail container
        detailContainer = NSView()
        detailContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.wantsLayer = true

        // Button bar
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

        content.addSubview(sidebarScroll)
        content.addSubview(detailContainer)
        content.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            sidebarScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebarScroll.topAnchor.constraint(equalTo: content.topAnchor),
            sidebarScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebarScroll.widthAnchor.constraint(equalToConstant: 180),

            detailContainer.leadingAnchor.constraint(equalTo: sidebarScroll.trailingAnchor),
            detailContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            detailContainer.topAnchor.constraint(equalTo: content.topAnchor),
            detailContainer.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -12),

            buttonRow.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttonRow.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor, constant: 16),
            buttonRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            buttonRow.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Build all section detail views ahead of time.
        for section in SettingsSection.allCases {
            let v = buildDetailView(for: section)
            detailViews[section] = v
        }

        // Default select first row
        sidebarTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        selectSection(.general)
    }

    private func buildDetailView(for section: SettingsSection) -> NSView {
        switch section {
        case .general:  return buildGeneralPanel()
        case .provider: return buildProviderPanel()
        case .polish:   return buildPolishPanel()
        }
    }

    // MARK: - General panel

    private func buildGeneralPanel() -> NSView {
        let stack = makeSectionStack(title: Strings.settingsSecGeneral,
                                     subtitle: Strings.settingsSecGeneralHint)

        // Language picker
        stack.addArrangedSubview(makeFieldLabel(Strings.settingsLangHints,
                                                 help: Strings.settingsLangHintsHelp))
        stack.addArrangedSubview(buildLanguageGrid())

        stack.addArrangedSubview(makeDivider())

        // Speaker lock
        speakerLockCheckbox = NSButton(checkboxWithTitle: Strings.settingsSpeakerLock,
                                       target: nil, action: nil)
        let speakerHelp = makeHintLabel(Strings.settingsSpeakerLockHelp)
        stack.addArrangedSubview(speakerLockCheckbox)
        stack.addArrangedSubview(speakerHelp)

        return wrapInScroll(stack)
    }

    private func buildLanguageGrid() -> NSView {
        let columns = 3
        let rowsPerCol = (DictateLanguages.count + columns - 1) / columns
        var rows: [NSStackView] = []
        for r in 0..<rowsPerCol {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .firstBaseline
            rowStack.spacing = 12
            rowStack.distribution = .fillEqually
            for c in 0..<columns {
                let idx = c * rowsPerCol + r
                if idx < DictateLanguages.count {
                    let lang = DictateLanguages[idx]
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
        return grid
    }

    // MARK: - Provider panel

    private func buildProviderPanel() -> NSView {
        let outer = makeSectionStack(title: Strings.settingsSecProvider,
                                     subtitle: Strings.settingsSecProviderHint)

        providerPopup = NSPopUpButton()
        providerPopup.translatesAutoresizingMaskIntoConstraints = false
        providerPopup.addItems(withTitles: [
            providerDisplay("soniox"),
            providerDisplay("deepgram"),
            providerDisplay("openai"),
            providerDisplay("custom"),
        ])
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)

        outer.addArrangedSubview(makeFieldLabel(Strings.settingsProviderSelect, help: nil))
        outer.addArrangedSubview(providerPopup)
        NSLayoutConstraint.activate([
            providerPopup.widthAnchor.constraint(equalToConstant: 360),
        ])

        outer.addArrangedSubview(makeDivider())

        // The container that swaps provider-specific panels
        providerStack = NSStackView()
        providerStack.orientation = .vertical
        providerStack.alignment = .leading
        providerStack.spacing = 12
        providerStack.translatesAutoresizingMaskIntoConstraints = false
        outer.addArrangedSubview(providerStack)

        // Build per-provider sub-panels
        providerPanels["soniox"] = buildSonioxPanel()
        providerPanels["deepgram"] = buildDeepgramPanel()
        providerPanels["openai"] = buildOpenAIPanel()
        providerPanels["custom"] = buildCustomPanel()

        return wrapInScroll(outer)
    }

    private func providerDisplay(_ key: String) -> String {
        switch key {
        case "soniox":   return Strings.providerSoniox
        case "deepgram": return Strings.providerDeepgram
        case "openai":   return Strings.providerOpenAI
        case "custom":   return Strings.providerCustom
        default:         return key
        }
    }

    private func providerKey(fromDisplay s: String) -> String {
        if s == Strings.providerSoniox   { return "soniox" }
        if s == Strings.providerDeepgram { return "deepgram" }
        if s == Strings.providerOpenAI   { return "openai" }
        if s == Strings.providerCustom   { return "custom" }
        return "soniox"
    }

    private func buildSonioxPanel() -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false

        s.addArrangedSubview(makeLinkButton(title: Strings.settingsLinkSoniox,
                                            url: "https://console.soniox.com"))

        sonioxKeyField = NSSecureTextField()
        sonioxKeyField.placeholderString = "soniox API key"
        sonioxKeyField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsSonioxKey,
                                          help: Strings.settingsSonioxKeyHelp,
                                          field: sonioxKeyField))

        sonioxModelPopup = NSPopUpButton()
        sonioxModelPopup.addItems(withTitles: SonioxModels)
        sonioxModelPopup.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsSonioxModel,
                                          help: nil,
                                          field: sonioxModelPopup))
        return s
    }

    private func buildDeepgramPanel() -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false

        s.addArrangedSubview(makeLinkButton(title: Strings.settingsLinkDeepgram,
                                            url: "https://console.deepgram.com"))

        deepgramKeyField = NSSecureTextField()
        deepgramKeyField.placeholderString = "deepgram API key"
        deepgramKeyField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsDeepgramKey,
                                          help: Strings.settingsDeepgramKeyHelp,
                                          field: deepgramKeyField))

        deepgramModelPopup = NSPopUpButton()
        deepgramModelPopup.addItems(withTitles: DeepgramModels)
        deepgramModelPopup.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsDeepgramModel,
                                          help: nil,
                                          field: deepgramModelPopup))
        return s
    }

    private func buildOpenAIPanel() -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false

        s.addArrangedSubview(makeLinkButton(title: Strings.settingsLinkOpenAI,
                                            url: "https://platform.openai.com/api-keys"))

        openaiKeyField = NSSecureTextField()
        openaiKeyField.placeholderString = "sk-..."
        openaiKeyField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsOpenAIKey,
                                          help: Strings.settingsOpenAIKeyHelp,
                                          field: openaiKeyField))

        openaiModelPopup = NSPopUpButton()
        openaiModelPopup.addItems(withTitles: OpenAIRealtimeModels)
        openaiModelPopup.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsOpenAIModel,
                                          help: nil,
                                          field: openaiModelPopup))
        return s
    }

    private func buildCustomPanel() -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false

        customBaseUrlField = NSTextField()
        customBaseUrlField.placeholderString = "wss://your-endpoint/v1/realtime?intent=transcription"
        customBaseUrlField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsCustomBaseUrl,
                                          help: Strings.settingsCustomBaseUrlHelp,
                                          field: customBaseUrlField))

        customKeyField = NSSecureTextField()
        customKeyField.placeholderString = "API key (sent as Bearer token)"
        customKeyField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsCustomKey,
                                          help: Strings.settingsCustomKeyHelp,
                                          field: customKeyField))

        customModelField = NSTextField()
        customModelField.placeholderString = "gpt-4o-mini-transcribe"
        customModelField.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsCustomModel,
                                          help: Strings.settingsCustomModelHelp,
                                          field: customModelField))

        return s
    }

    /// Renders a small underlined hyperlink-style button that opens `url` in the default browser.
    private func makeLinkButton(title: String, url: String) -> NSView {
        let btn = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.controlSize = .small
        btn.contentTintColor = NSColor.linkColor
        let attr = NSMutableAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.linkColor,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        btn.attributedTitle = attr
        btn.toolTip = url
        objc_setAssociatedObject(btn, &Self.linkURLKey, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private static var linkURLKey: UInt8 = 0

    @objc private func openLink(_ sender: NSButton) {
        guard let url = objc_getAssociatedObject(sender, &Self.linkURLKey) as? String,
              let u = URL(string: url) else { return }
        NSWorkspace.shared.open(u)
    }

    private func showProviderPanel(for key: String) {
        // Remove old panels from providerStack
        for sub in providerStack.arrangedSubviews { providerStack.removeArrangedSubview(sub); sub.removeFromSuperview() }
        if let panel = providerPanels[key] {
            providerStack.addArrangedSubview(panel)
            if panel is NSStackView {
                // ensure width grows to detail container
                NSLayoutConstraint.activate([
                    panel.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
                ])
            }
        }
    }

    @objc private func providerChanged() {
        let display = providerPopup.titleOfSelectedItem ?? ""
        let key = providerKey(fromDisplay: display)
        showProviderPanel(for: key)
    }

    // MARK: - Polish panel

    private func buildPolishPanel() -> NSView {
        let s = makeSectionStack(title: Strings.settingsSecPolish,
                                  subtitle: Strings.settingsSecPolishHint)

        backendPopup = NSPopUpButton()
        // Display titles → internal keys: "claude" / "codex" / "openai_api"
        backendPopup.addItems(withTitles: [
            "claude (CLI)",
            "codex (CLI)",
            Strings.settingsPolishBackendApi,
        ])
        backendPopup.target = self
        backendPopup.action = #selector(backendChanged)
        backendPopup.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsPolishBackend,
                                          help: nil,
                                          field: backendPopup))

        // API panel (shown only when openai_api selected)
        apiPanelStack = NSStackView()
        apiPanelStack.orientation = .vertical
        apiPanelStack.alignment = .leading
        apiPanelStack.spacing = 10
        apiPanelStack.translatesAutoresizingMaskIntoConstraints = false

        polishApiBaseUrlField = NSTextField()
        polishApiBaseUrlField.placeholderString = "https://api.openai.com/v1"
        polishApiBaseUrlField.translatesAutoresizingMaskIntoConstraints = false
        apiPanelStack.addArrangedSubview(makeFieldRow(label: Strings.settingsPolishApiBaseUrl,
                                                      help: Strings.settingsPolishApiBaseUrlHelp,
                                                      field: polishApiBaseUrlField))

        polishApiKeyField = NSSecureTextField()
        polishApiKeyField.placeholderString = "sk-..."
        polishApiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiPanelStack.addArrangedSubview(makeFieldRow(label: Strings.settingsPolishApiKey,
                                                      help: Strings.settingsPolishApiKeyHelp,
                                                      field: polishApiKeyField))

        refreshModelsButton = NSButton(title: Strings.settingsRefreshModels,
                                        target: self, action: #selector(refreshModels))
        refreshModelsButton.bezelStyle = .rounded
        refreshModelsStatus = NSTextField(labelWithString: "")
        refreshModelsStatus.font = .systemFont(ofSize: 11)
        refreshModelsStatus.textColor = NSColor.secondaryLabelColor
        let refreshRow = NSStackView(views: [refreshModelsButton, refreshModelsStatus])
        refreshRow.orientation = .horizontal
        refreshRow.spacing = 10
        refreshRow.alignment = .firstBaseline
        apiPanelStack.addArrangedSubview(refreshRow)

        s.addArrangedSubview(apiPanelStack)

        polishModelPopup = NSPopUpButton()
        polishModelPopup.translatesAutoresizingMaskIntoConstraints = false
        s.addArrangedSubview(makeFieldRow(label: Strings.settingsPolishModel,
                                          help: nil,
                                          field: polishModelPopup))

        s.addArrangedSubview(makeDivider())

        // Polish prompt (multi-line)
        s.addArrangedSubview(makeFieldLabel(Strings.settingsPolishPrompt,
                                             help: Strings.settingsPolishPromptHelp))

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

        NSLayoutConstraint.activate([
            promptScroll.heightAnchor.constraint(equalToConstant: 180),
            promptScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
        ])
        s.addArrangedSubview(promptScroll)

        return wrapInScroll(s)
    }

    /// Maps user-facing backend popup display text → internal config key.
    private func currentPolishBackendKey() -> String {
        switch backendPopup.titleOfSelectedItem ?? "" {
        case "codex (CLI)": return "codex"
        case Strings.settingsPolishBackendApi: return "openai_api"
        default: return "claude"
        }
    }

    private func setPolishBackendPopup(toKey key: String) {
        switch key {
        case "codex":      backendPopup.selectItem(withTitle: "codex (CLI)")
        case "openai_api": backendPopup.selectItem(withTitle: Strings.settingsPolishBackendApi)
        default:           backendPopup.selectItem(withTitle: "claude (CLI)")
        }
    }

    private func rebuildPolishModelOptions(currentModel: String?) {
        let backend = currentPolishBackendKey()
        let options: [String]
        if backend == "openai_api" {
            // Use fetched models if available, else just the current saved one as placeholder.
            options = fetchedApiModels.isEmpty
                ? (currentModel.map { [$0] } ?? [Config.defaultPolishApiModel])
                : fetchedApiModels
        } else {
            options = PolishModels[backend] ?? ["sonnet"]
        }
        polishModelPopup.removeAllItems()
        polishModelPopup.addItems(withTitles: options)
        if let m = currentModel, options.contains(m) {
            polishModelPopup.selectItem(withTitle: m)
        } else {
            let def: String
            switch backend {
            case "codex":      def = Config.defaultPolishModelCodex
            case "openai_api": def = Config.defaultPolishApiModel
            default:           def = Config.defaultPolishModelClaude
            }
            if options.contains(def) {
                polishModelPopup.selectItem(withTitle: def)
            } else {
                polishModelPopup.selectItem(at: 0)
            }
        }

        // Show/hide the API config panel based on backend
        apiPanelStack.isHidden = (backend != "openai_api")
    }

    @objc private func backendChanged() {
        // Keep the currently typed key intact when switching backends so user doesn't re-type
        rebuildPolishModelOptions(currentModel: nil)
    }

    @objc private func refreshModels() {
        let baseUrl = polishApiBaseUrlField.stringValue.trimmingCharacters(in: .whitespaces)
        let apiKey = polishApiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !baseUrl.isEmpty else {
            refreshModelsStatus.stringValue = "Base URL is empty"
            refreshModelsStatus.textColor = NSColor.systemRed
            return
        }
        refreshModelsButton.isEnabled = false
        refreshModelsStatus.stringValue = Strings.settingsFetchingModels
        refreshModelsStatus.textColor = NSColor.secondaryLabelColor

        Polisher.fetchOpenAIModels(baseUrl: baseUrl, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }
            self.refreshModelsButton.isEnabled = true
            switch result {
            case .success(let ids):
                self.fetchedApiModels = ids
                self.refreshModelsStatus.stringValue = "\(Strings.settingsFetchModelsOK) (\(ids.count))"
                self.refreshModelsStatus.textColor = NSColor.systemGreen
                self.rebuildPolishModelOptions(currentModel: self.polishModelPopup.titleOfSelectedItem)
            case .failure(let err):
                self.refreshModelsStatus.stringValue = "\(Strings.settingsFetchModelsFail): \(err.localizedDescription)"
                self.refreshModelsStatus.textColor = NSColor.systemRed
            }
        }
    }

    // MARK: - Helpers

    private func makeSectionStack(title: String, subtitle: String) -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 14
        s.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        s.translatesAutoresizingMaskIntoConstraints = false

        let h = NSTextField(labelWithString: title)
        h.font = .systemFont(ofSize: 18, weight: .semibold)
        h.textColor = NSColor.labelColor
        s.addArrangedSubview(h)

        if !subtitle.isEmpty {
            let sub = NSTextField(labelWithString: subtitle)
            sub.font = .systemFont(ofSize: 11)
            sub.textColor = NSColor.secondaryLabelColor
            sub.lineBreakMode = .byWordWrapping
            sub.maximumNumberOfLines = 0
            sub.preferredMaxLayoutWidth = 480
            s.addArrangedSubview(sub)
        }
        return s
    }

    private func makeFieldLabel(_ text: String, help: String?) -> NSStackView {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = NSColor.secondaryLabelColor
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 2
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.addArrangedSubview(lbl)
        if let help = help, !help.isEmpty {
            inner.addArrangedSubview(makeHintLabel(help))
        }
        return inner
    }

    private func makeFieldRow(label: String, help: String?, field: NSView) -> NSView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 4
        outer.translatesAutoresizingMaskIntoConstraints = false

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = NSColor.secondaryLabelColor
        outer.addArrangedSubview(lbl)

        field.translatesAutoresizingMaskIntoConstraints = false
        outer.addArrangedSubview(field)

        if let help = help, !help.isEmpty {
            outer.addArrangedSubview(makeHintLabel(help))
        }

        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: 480),
        ])
        return outer
    }

    private func makeHintLabel(_ s: String) -> NSTextField {
        let h = NSTextField(labelWithString: s)
        h.font = .systemFont(ofSize: 10)
        h.textColor = NSColor.tertiaryLabelColor
        h.lineBreakMode = .byWordWrapping
        h.maximumNumberOfLines = 0
        h.preferredMaxLayoutWidth = 480
        return h
    }

    private func makeDivider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.heightAnchor.constraint(equalToConstant: 1),
            line.widthAnchor.constraint(equalToConstant: 480),
        ])
        return line
    }

    private func wrapInScroll(_ inner: NSView) -> NSView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let docView = FlippedView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            inner.trailingAnchor.constraint(lessThanOrEqualTo: docView.trailingAnchor),
            inner.topAnchor.constraint(equalTo: docView.topAnchor),
            inner.bottomAnchor.constraint(equalTo: docView.bottomAnchor),
        ])

        scroll.documentView = docView
        return scroll
    }

    // MARK: - Section switching

    private func selectSection(_ section: SettingsSection) {
        currentSection = section
        for sub in detailContainer.subviews { sub.removeFromSuperview() }
        guard let v = detailViews[section] else { return }
        v.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            v.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            v.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
        ])
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        SettingsSection.allCases.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let section = SettingsSection.allCases[row]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: section.title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 28 }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTable.selectedRow
        guard row >= 0, row < SettingsSection.allCases.count else { return }
        selectSection(SettingsSection.allCases[row])
    }

    // MARK: - Save / Cancel

    @objc private func cancel() { window.close() }

    @objc private func save() {
        // Selected provider
        let providerDisplayName = providerPopup.titleOfSelectedItem ?? Strings.providerSoniox
        let provider = providerKey(fromDisplay: providerDisplayName)

        // Pull each provider's fields (always save all so the user doesn't lose them when switching)
        let sonioxKey = sonioxKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let sonioxModel = sonioxModelPopup.titleOfSelectedItem ?? Config.defaultSonioxModel

        let deepgramKey = deepgramKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let deepgramModel = deepgramModelPopup.titleOfSelectedItem ?? Config.defaultDeepgramModel

        let openaiKey = openaiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let openaiModel = openaiModelPopup.titleOfSelectedItem ?? Config.defaultOpenAIModel

        let customUrl = customBaseUrlField.stringValue.trimmingCharacters(in: .whitespaces)
        let customKey = customKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let customModel = customModelField.stringValue.trimmingCharacters(in: .whitespaces)

        // Validate selected provider
        switch provider {
        case "soniox" where sonioxKey.isEmpty:
            showInline(title: Strings.settingsSonioxKey, body: "API key required."); return
        case "deepgram" where deepgramKey.isEmpty:
            showInline(title: Strings.settingsDeepgramKey, body: "API key required."); return
        case "openai" where openaiKey.isEmpty:
            showInline(title: Strings.settingsOpenAIKey, body: "API key required."); return
        case "custom" where customUrl.isEmpty || customKey.isEmpty:
            showInline(title: Strings.providerCustom, body: "Base URL and API key required."); return
        default: break
        }

        // Languages
        var selectedCodes: [String] = []
        for lang in DictateLanguages {
            if langCheckboxes[lang.code]?.state == .on { selectedCodes.append(lang.code) }
        }
        if selectedCodes.isEmpty { selectedCodes = Config.defaultLanguageHints }

        // Polish
        let backend = currentPolishBackendKey()
        let polishModel: String = {
            if let m = polishModelPopup.titleOfSelectedItem, !m.isEmpty { return m }
            switch backend {
            case "codex":      return Config.defaultPolishModelCodex
            case "openai_api": return Config.defaultPolishApiModel
            default:           return Config.defaultPolishModelClaude
            }
        }()
        let polishPrompt = polishPromptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let polishApiBaseUrl = polishApiBaseUrlField.stringValue.trimmingCharacters(in: .whitespaces)
        let polishApiKey = polishApiKeyField.stringValue.trimmingCharacters(in: .whitespaces)

        let cfg = Config(
            sttProvider: provider,
            sonioxApiKey: sonioxKey,
            sonioxModel: sonioxModel,
            deepgramApiKey: deepgramKey,
            deepgramModel: deepgramModel,
            openaiApiKey: openaiKey,
            openaiModel: openaiModel,
            customBaseUrl: customUrl,
            customApiKey: customKey,
            customModel: customModel.isEmpty ? Config.defaultCustomModel : customModel,
            languageHints: selectedCodes,
            polishBackend: backend,
            polishModel: polishModel,
            polishPrompt: polishPrompt,
            speakerLock: speakerLockCheckbox.state == .on,
            polishApiBaseUrl: polishApiBaseUrl.isEmpty ? Config.defaultPolishApiBaseUrl : polishApiBaseUrl,
            polishApiKey: polishApiKey
        )
        do {
            try cfg.save()
            onSaved(cfg)
            window.close()
        } catch {
            showInline(title: "Save failed", body: error.localizedDescription)
        }
    }

    private func showInline(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }
}

/// Flipped NSView so the scrollable doc lays out top-down naturally.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
