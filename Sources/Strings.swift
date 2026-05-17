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

    // Settings window
    static var settingsTitle: String { L("Murmur 设置", "Murmur Settings") }
    static var settingsSonioxKey: String { L("Soniox API Key", "Soniox API Key") }
    static var settingsSonioxModel: String { L("Soniox 模型", "Soniox Model") }
    static var settingsLangHints: String { L("识别语言（逗号分隔，如 zh,en）", "Language hints (comma-separated, e.g. zh,en)") }
    static var settingsPolishBackend: String { L("润色工具", "Polish Tool") }
    static var settingsPolishModel: String { L("润色模型", "Polish Model") }
    static var settingsPolishPrompt: String { L("润色提示词（留空使用默认）", "Polish Prompt (leave empty for default)") }
    static var settingsSpeakerLock: String { L("锁定主说话人（实验，默认关）", "Lock to primary speaker (experimental, default OFF)") }
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
