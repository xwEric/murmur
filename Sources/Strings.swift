import Foundation

/// Tiny localization helper — driven by Config.uiLanguage. Defaults to English.
/// We don't use NSLocalizedString because it requires a .lproj bundle setup
/// that's awkward for a single-binary swiftc build.
enum Strings {
    /// Mutated by `applyConfigLanguage` at app launch and on Settings save.
    static var isZH: Bool = systemPrefersChinese()

    /// `code` may be "auto" | "en" | "zh". "auto" → follow system locale.
    static func applyConfigLanguage(_ code: String) {
        switch code.lowercased() {
        case "zh": isZH = true
        case "en": isZH = false
        default:   isZH = systemPrefersChinese()
        }
    }

    private static func systemPrefersChinese() -> Bool {
        let lang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return lang.hasPrefix("zh")
    }

    private static func L(_ zh: String, _ en: String) -> String { isZH ? zh : en }

    // Status labels
    static var statusRecording: String { L("🔴  录音中", "🔴  RECORDING") }
    static var statusPaused: String { L("⏸  已暂停", "⏸  PAUSED") }
    static var statusFinalizing: String { L("⏳  处理中…", "⏳  FINALIZING…") }
    static var statusPolishing: String { L("✨  润色中…", "✨  POLISHING…") }
    static var statusPolished: String { L("✨  已润色", "✨  POLISHED") }
    static var statusOriginal: String { L("📝  原文", "📝  ORIGINAL") }
    static var statusError: String { L("⚠️  出错", "⚠️  ERROR") }

    // Hint labels (top-right of overlay)
    static var hintRecording: String { L("右⌘ 插入  ·  Alt 润色  ·  空格 暂停  ·  Esc 取消", "Right ⌘ commit  ·  Alt polish  ·  Space pause  ·  Esc cancel") }
    static var hintPaused: String { L("空格 继续  ·  右⌘ 插入  ·  Alt 润色  ·  Esc 取消", "Space resume  ·  Right ⌘ commit  ·  Alt polish  ·  Esc cancel") }
    static var hintProcessing: String { L("Esc 取消", "Esc cancel") }
    static var hintReviewOriginal: String { L("右⌘ 插入  ·  Alt 润色  ·  Esc 取消", "Right ⌘ insert  ·  Alt polish  ·  Esc cancel") }
    static var hintReviewPolished: String { L("右⌘ 插入  ·  Alt 切回原文  ·  Esc 取消", "Right ⌘ insert  ·  Alt revert  ·  Esc cancel") }

    // Error inline
    static var errEmptyTranscription: String { L("识别为空（可能未检测到语音）", "Empty transcription (no speech detected?)") }
    static var errMicStartFail: String { L("录音启动失败", "Failed to start microphone") }

    // Mic permission alerts
    static var alertMicNeeded: String { L("需要麦克风权限", "Microphone Permission Required") }
    static var alertMicNeededBody: String {
        L("Murmur 需要麦克风权限才能录音。请去 System Settings → Privacy & Security → Microphone 中勾选 Murmur，然后重试。",
          "Murmur needs microphone permission to record. Open System Settings → Privacy & Security → Microphone and enable Murmur, then try again.")
    }
    static var btnOpenMicSettings: String { L("打开设置", "Open Settings") }

    // Menu items
    static var menuTagline: String { L("右⌘ 录音  ·  Alt 润色  ·  Esc 取消", "Right ⌘ record  ·  Alt polish  ·  Esc cancel") }
    static var menuTestRecording: String { L("测试录音 (debug)", "Test Recording (debug)") }
    static var menuRecheckPerms: String { L("重新检测权限", "Re-check Permissions") }
    static var menuOpenAccess: String { L("打开辅助功能设置", "Open Accessibility Settings") }
    static var menuSettings: String { L("设置…", "Settings…") }
    static var menuQuit: String { L("退出 Murmur", "Quit Murmur") }
    static var menuStatusActive: String { L("状态：hotkey 已激活 ✓", "Status: hotkey ACTIVE ✓") }
    static var menuStatusInactive: String { L("状态：hotkey 未授权 ✗", "Status: hotkey NOT GRANTED ✗") }
    static var menuStatusStarting: String { L("状态：启动中…", "Status: starting…") }

    // Settings window — header & sections
    static var settingsTitle: String { L("Murmur 设置", "Murmur Settings") }
    static var settingsSecGeneral:  String { L("通用",     "General") }
    static var settingsSecProvider: String { L("识别引擎", "STT Provider") }
    static var settingsSecPolish:   String { L("润色",     "Polish") }
    static var settingsSecGeneralHint:  String { L("界面语言、识别语言与说话人设置", "Interface language, recognition language hints, and speaker behavior.") }

    // UI language
    static var settingsUILanguage: String { L("界面语言", "Interface Language") }
    static var settingsUILanguageHelp: String { L("切换 Murmur 自身的菜单和设置语言。默认跟随系统语言；重启后所有界面完全刷新。", "Switches Murmur's own menu and Settings labels. Defaults to system language; restart for everything to refresh.") }
    static var settingsUILangAuto: String { L("跟随系统", "Auto (System)") }
    static var settingsUILangEnglish: String { L("English", "English") }
    static var settingsUILangChinese: String { L("中文", "中文") }
    static var settingsSecProviderHint: String { L("选择实时语音识别服务，并填写对应 API key。", "Choose a real-time speech-to-text service and enter its API key.") }
    static var settingsSecPolishHint:   String { L("识别完成后用 LLM 润色文字（可选）。", "Optionally polish the transcript with an LLM after recognition.") }

    // Provider selector
    static var settingsProviderSelect: String { L("识别服务", "Provider") }

    // Provider display names
    static var providerSoniox:   String { L("Soniox (stt-rt-preview)",  "Soniox (stt-rt-preview)") }
    static var providerDeepgram: String { L("Deepgram (Nova-3)",        "Deepgram (Nova-3)") }
    static var providerOpenAI:   String { L("OpenAI Realtime",          "OpenAI Realtime") }
    static var providerCustom:   String { L("自定义 (OpenAI 兼容)",     "Custom (OpenAI-compatible)") }

    // Per-provider clickable signup links
    static var settingsLinkSoniox: String   { L("→ 注册 Soniox 并获取 API key", "→ Sign up at Soniox and get an API key") }
    static var settingsLinkDeepgram: String { L("→ 注册 Deepgram 并获取 API key（送 $200 额度）", "→ Sign up at Deepgram and get an API key ($200 free credit)") }
    static var settingsLinkOpenAI: String   { L("→ 在 OpenAI Platform 创建 API key", "→ Create an API key on OpenAI Platform") }

    // Soniox
    static var settingsSonioxKey: String { L("Soniox API Key", "Soniox API Key") }
    static var settingsSonioxKeyHelp: String { L(
        "申请步骤：\n1. 注册 console.soniox.com（Google 登录可用）\n2. Settings → API Keys → Create new key\n3. 多语言识别质量最好；注册有免费额度，之后约 $0.04/分钟",
        "How to get it:\n1. Sign up at console.soniox.com (Google login works)\n2. Settings → API Keys → Create new key\n3. Best multilingual quality; free trial included, ~$0.04/min after"
    ) }
    static var settingsSonioxModel: String { L("Soniox 模型", "Soniox Model") }

    // Deepgram
    static var settingsDeepgramKey: String { L("Deepgram API Key", "Deepgram API Key") }
    static var settingsDeepgramKeyHelp: String { L(
        "申请步骤：\n1. 注册 console.deepgram.com（新账号送 $200 额度，约 750 小时音频）\n2. 进入控制台 → API Keys → Create a New API Key\n3. 角色选 \"Member\" 即可；适合英文为主、对延迟敏感的场景",
        "How to get it:\n1. Sign up at console.deepgram.com (new accounts get $200 free credit ≈ 750 hours)\n2. Console → API Keys → Create a New API Key\n3. Role: \"Member\" is enough; best for English-heavy or latency-sensitive use"
    ) }
    static var settingsDeepgramModel: String { L("Deepgram 模型", "Deepgram Model") }

    // OpenAI
    static var settingsOpenAIKey: String { L("OpenAI API Key", "OpenAI API Key") }
    static var settingsOpenAIKeyHelp: String { L(
        "申请步骤：\n1. 去 platform.openai.com/api-keys 创建 key（需要付费账户）\n2. 确保账户开通了 Realtime API 访问（多数付费账户默认有）\n3. 默认 gpt-4o-mini-transcribe；可选 gpt-4o-transcribe 质量更高但更贵",
        "How to get it:\n1. Create a key at platform.openai.com/api-keys (paid account required)\n2. Make sure your account has Realtime API access (most paid accounts do)\n3. Default model: gpt-4o-mini-transcribe; gpt-4o-transcribe is higher quality but pricier"
    ) }
    static var settingsOpenAIModel: String { L("OpenAI 模型", "OpenAI Model") }

    // Custom
    static var settingsCustomBaseUrl: String { L("Base URL (wss://…)", "Base URL (wss://…)") }
    static var settingsCustomBaseUrlHelp: String { L(
        "适用于任何 OpenAI Realtime 兼容服务：Azure OpenAI、自建 vLLM、私有部署等。\nURL 格式：wss://your-host/v1/realtime?intent=transcription\n协议遵循 OpenAI 官方文档（transcription_session.update + input_audio_buffer.append）",
        "For any OpenAI-Realtime-compatible service: Azure OpenAI, self-hosted vLLM, private deployments, etc.\nURL format: wss://your-host/v1/realtime?intent=transcription\nProtocol follows OpenAI spec (transcription_session.update + input_audio_buffer.append)"
    ) }
    static var settingsCustomKey: String { L("API Key", "API Key") }
    static var settingsCustomKeyHelp: String { L(
        "服务商在 Authorization: Bearer header 中期望的值。",
        "Whatever your endpoint expects in the Authorization: Bearer header."
    ) }
    static var settingsCustomModel: String { L("模型名称", "Model name") }
    static var settingsCustomModelHelp: String { L(
        "将在 transcription_session.update 的 model 字段中发送。",
        "Sent as the model field in transcription_session.update."
    ) }

    // Other
    static var settingsLangHints: String { L("识别语言", "Language hints") }
    static var settingsLangHintsHelp: String { L("勾选多个语言时，Deepgram 会自动切换到 multi 模式。", "Selecting multiple languages enables multilingual mode (e.g. Deepgram multi).") }
    static var settingsPolishBackend: String { L("润色工具", "Polish backend") }
    static var settingsPolishModel: String { L("润色模型", "Polish model") }
    static var settingsPolishPrompt: String { L("润色提示词（留空使用默认）", "Polish Prompt (leave empty for default)") }
    static var settingsPolishApiBaseUrl: String { L("Base URL", "Base URL") }
    static var settingsPolishApiBaseUrlHelp: String { L(
        "OpenAI 兼容端点。OpenAI 用 https://api.openai.com/v1；本地 vLLM/LM Studio 用对应地址。",
        "OpenAI-compatible endpoint. Use https://api.openai.com/v1 for OpenAI; vLLM/LM Studio etc. use their own URL."
    ) }
    static var settingsPolishApiKey: String { L("API Key", "API Key") }
    static var settingsPolishApiKeyHelp: String { L(
        "Bearer token。本地模型如果不要求鉴权可以留空。",
        "Bearer token. May be left empty for local endpoints that don't require auth."
    ) }
    static var settingsRefreshModels: String { L("拉取可用模型", "Refresh available models") }
    static var settingsFetchingModels: String { L("正在拉取…", "Fetching…") }
    static var settingsFetchModelsOK: String { L("拉取成功", "Models loaded") }
    static var settingsFetchModelsFail: String { L("拉取失败", "Could not load models") }
    static var settingsPolishBackendCli: String { L("CLI", "CLI") }
    static var settingsPolishBackendApi: String { L("OpenAI 兼容 API", "OpenAI-compatible API") }
    static var settingsPolishPromptHelp: String { L("自定义 system prompt；留空时使用 Polisher 默认提示词。", "Custom system prompt; empty = built-in default.") }
    static var settingsSpeakerLock: String { L("锁定主说话人（仅 Soniox，实验）", "Lock to primary speaker (Soniox only, experimental)") }
    static var settingsSpeakerLockHelp: String { L("基于 Soniox 在线说话人聚类。准确度有限，若身边总有干扰可试。", "Based on Soniox online speaker clustering. Limited accuracy — try if background voices interfere.") }
    static var settingsSave: String { L("保存", "Save") }
    static var settingsCancel: String { L("取消", "Cancel") }
    static var settingsSaveOK: String { L("已保存", "Saved") }
    static var settingsSaveOKBody: String { L("配置已写入 ~/.claude-profile/dictate/config.json", "Config written to ~/.claude-profile/dictate/config.json") }

    // STT pre-flight (start recording without API key)
    static var alertSTTNeedSetup: String { L("尚未配置识别服务", "Speech-to-Text Not Configured") }
    static var alertSTTNeedSetupBody: String {
        L("Murmur 需要至少一个 STT 服务的 API key 才能开始录音。请在 Settings → STT Provider 中填写你选用的 provider 的 key，然后再试一次。",
          "Murmur needs an API key for at least one Speech-to-Text provider before it can record. Open Settings → STT Provider, paste your provider's API key, and try again.")
    }

    // Polish pre-flight + failure dialog
    static var alertPolishError: String { L("润色无法完成", "Polish Failed") }
    static var alertPolishErrorBody: String {
        L("当前选择的润色后端不可用。请打开 Settings → Polish 检查 CLI 是否已安装、API key 是否填写正确，或切换到另一种润色方式。",
          "The selected polish backend isn't working. Open Settings → Polish and check that the CLI is installed and logged in, or that the API key is correct — or switch to a different polish method.")
    }

    // Permission alerts
    static var alertConfigMissing: String { L("配置缺失", "Config Missing") }
    static var alertAccessNeeded: String { L("需要辅助功能权限", "Accessibility Permission Required") }
    static var alertAccessNeededBody: String {
        L("Murmur 需要在 System Settings → Privacy & Security → Accessibility 中被勾选，才能监听 hotkey 并粘贴文本。",
          "Murmur needs Accessibility permission (System Settings → Privacy & Security → Accessibility) to monitor hotkeys and paste text.")
    }
    static var alertAccessGranted: String { L("辅助功能已授权 ✓", "Accessibility Granted ✓") }
    static var alertAccessGrantedBody: String { L("现在按一下右 ⌘ 即可开始录音。", "Press Right ⌘ to start recording.") }
    static var btnOpenSettings: String { L("打开设置", "Open Settings") }
    static var btnLater: String { L("稍后", "Later") }
}
