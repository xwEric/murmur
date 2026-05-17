import Foundation

/// Tiny localization helper — picks zh-CN strings if the user's preferred language is Chinese,
/// otherwise English. We don't use NSLocalizedString because it requires a .lproj bundle setup
/// that's awkward for a single-binary swiftc build.
enum Strings {
    static let isZH: Bool = {
        let lang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return lang.hasPrefix("zh")
    }()

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
    static var menuOpenConfig: String { L("打开配置目录", "Open Config Folder") }
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
    static var settingsSecGeneralHint:  String { L("识别语言与说话人设置", "Language hints and speaker behavior.") }
    static var settingsSecProviderHint: String { L("选择实时语音识别服务，并填写对应 API key。", "Choose a real-time speech-to-text service and enter its API key.") }
    static var settingsSecPolishHint:   String { L("识别完成后用 LLM 润色文字（可选）。", "Optionally polish the transcript with an LLM after recognition.") }

    // Provider selector
    static var settingsProviderSelect: String { L("识别服务", "Provider") }

    // Provider display names
    static var providerSoniox:   String { L("Soniox (stt-rt-preview)",  "Soniox (stt-rt-preview)") }
    static var providerDeepgram: String { L("Deepgram (Nova-3)",        "Deepgram (Nova-3)") }
    static var providerOpenAI:   String { L("OpenAI Realtime",          "OpenAI Realtime") }
    static var providerCustom:   String { L("自定义 (OpenAI 兼容)",     "Custom (OpenAI-compatible)") }

    // Soniox
    static var settingsSonioxKey: String { L("Soniox API Key", "Soniox API Key") }
    static var settingsSonioxKeyHelp: String { L("从 console.soniox.com 获取。", "Get yours at console.soniox.com.") }
    static var settingsSonioxModel: String { L("Soniox 模型", "Soniox Model") }

    // Deepgram
    static var settingsDeepgramKey: String { L("Deepgram API Key", "Deepgram API Key") }
    static var settingsDeepgramKeyHelp: String { L("console.deepgram.com → API Keys", "console.deepgram.com → API Keys") }
    static var settingsDeepgramModel: String { L("Deepgram 模型", "Deepgram Model") }

    // OpenAI
    static var settingsOpenAIKey: String { L("OpenAI API Key", "OpenAI API Key") }
    static var settingsOpenAIKeyHelp: String { L("platform.openai.com/api-keys", "platform.openai.com/api-keys") }
    static var settingsOpenAIModel: String { L("OpenAI 模型", "OpenAI Model") }

    // Custom
    static var settingsCustomBaseUrl: String { L("Base URL (wss://…)", "Base URL (wss://…)") }
    static var settingsCustomBaseUrlHelp: String { L("任何 OpenAI Realtime 兼容端点（Azure / vLLM / 私有部署等）。", "Any OpenAI-Realtime-compatible endpoint (Azure / vLLM / self-hosted).") }
    static var settingsCustomKey: String { L("API Key", "API Key") }
    static var settingsCustomModel: String { L("模型名称", "Model name") }
    static var settingsCustomModelHelp: String { L("将在 transcription_session.update 中发送。", "Sent in transcription_session.update.") }

    // Other
    static var settingsLangHints: String { L("识别语言", "Language hints") }
    static var settingsLangHintsHelp: String { L("勾选多个语言时，Deepgram 会自动切换到 multi 模式。", "Selecting multiple languages enables multilingual mode (e.g. Deepgram multi).") }
    static var settingsPolishBackend: String { L("润色工具", "Polish backend") }
    static var settingsPolishModel: String { L("润色模型", "Polish model") }
    static var settingsPolishPrompt: String { L("润色提示词（留空使用默认）", "Polish Prompt (leave empty for default)") }
    static var settingsPolishPromptHelp: String { L("自定义 system prompt；留空时使用 Polisher 默认提示词。", "Custom system prompt; empty = built-in default.") }
    static var settingsSpeakerLock: String { L("锁定主说话人（仅 Soniox，实验）", "Lock to primary speaker (Soniox only, experimental)") }
    static var settingsSpeakerLockHelp: String { L("基于 Soniox 在线说话人聚类。准确度有限，若身边总有干扰可试。", "Based on Soniox online speaker clustering. Limited accuracy — try if background voices interfere.") }
    static var settingsSave: String { L("保存", "Save") }
    static var settingsCancel: String { L("取消", "Cancel") }
    static var settingsSaveOK: String { L("已保存", "Saved") }
    static var settingsSaveOKBody: String { L("配置已写入 ~/.claude-profile/dictate/config.json", "Config written to ~/.claude-profile/dictate/config.json") }

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
