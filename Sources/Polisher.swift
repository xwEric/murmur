import Foundation

/// Polishes raw transcribed text via a local LLM CLI.
///
/// Backends:
///   - "claude" (default): `claude -p TEXT --system-prompt SYS --model MODEL --output-format text`
///   - "codex":            `codex exec --skip-git-repo-check --sandbox read-only -m MODEL "SYS\n\nTEXT"`
enum Polisher {
    /// Default polish instruction — kept short on purpose. Users override via Settings.
    static let defaultSystemPrompt = "Polish this voice-input transcript: remove filler words, fix obvious mis-recognitions, preserve the original language and meaning. Output the result as ONE single continuous line — NO line breaks, no newlines, no paragraph breaks. Reply with the polished text only — no quotes, no markdown, no explanation."

    static func polish(_ text: String,
                       backend: String,
                       model: String,
                       systemPrompt: String? = nil,
                       completion: @escaping (Result<String, Error>) -> Void) {
        let prompt: String = {
            if let p = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
                return p
            }
            return defaultSystemPrompt
        }()
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String, Error>
            switch backend {
            case "codex":
                result = runCodex(text: text, model: model, systemPrompt: prompt)
            default:
                result = runClaude(text: text, model: model, systemPrompt: prompt)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Binary lookup

    private static func findBinary(_ name: String) -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.bun/bin/\(name)",
            "\(home)/.npm-global/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        let fm = FileManager.default
        for p in candidates where fm.isExecutableFile(atPath: p) { return p }

        // Fallback: ask login shell. Also covers nvm-managed binaries.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "command -v \(name)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               fm.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }

    private static func makeEnv() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        // Include nvm + homebrew bin so codex (often nvm-installed) can resolve node etc.
        let extra = [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node",  // not exact but parent — codex itself has full path
            "/usr/bin",
            "/bin",
        ].joined(separator: ":")
        let oldPath = env["PATH"] ?? ""
        env["PATH"] = extra + (oldPath.isEmpty ? "" : ":" + oldPath)
        return env
    }

    // MARK: - Backends

    private static func runClaude(text: String, model: String, systemPrompt: String) -> Result<String, Error> {
        guard let bin = findBinary("claude") else {
            return .failure(NSError(domain: "Polisher", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "找不到 claude CLI（probed ~/.local/bin, /opt/homebrew/bin 等）"
            ]))
        }
        NSLog("Murmur: polish via claude (\(model)) at \(bin)")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = [
            "-p", text,
            "--system-prompt", systemPrompt,
            "--model", model,
            "--output-format", "text",
        ]
        proc.environment = makeEnv()
        return runProcess(proc, label: "claude")
    }

    private static func runCodex(text: String, model: String, systemPrompt: String) -> Result<String, Error> {
        guard let bin = findBinary("codex") else {
            return .failure(NSError(domain: "Polisher", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "找不到 codex CLI"
            ]))
        }
        NSLog("Murmur: polish via codex (\(model)) at \(bin)")
        let fullPrompt = "\(systemPrompt)\n\nINPUT:\n\(text)\n\nPOLISHED:"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = [
            "exec",
            "--skip-git-repo-check",
            "--sandbox", "read-only",
            "-m", model,
            fullPrompt,
        ]
        proc.environment = makeEnv()
        let result = runProcess(proc, label: "codex")
        return result.map { stripCodexNoise($0) }
    }

    /// Replace any sequence of newlines (and surrounding whitespace) with a single space,
    /// then collapse runs of multiple spaces. Result is always a single line.
    private static func collapseNewlines(_ s: String) -> String {
        var out = ""
        var prevWasSpace = false
        for ch in s {
            if ch == "\n" || ch == "\r" || ch == "\u{2028}" || ch == "\u{2029}" {
                if !prevWasSpace { out.append(" "); prevWasSpace = true }
            } else if ch == " " || ch == "\t" {
                if !prevWasSpace { out.append(" "); prevWasSpace = true }
            } else {
                out.append(ch)
                prevWasSpace = false
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Codex stdout layout (observed):
    ///
    ///     OpenAI Codex vX.Y
    ///     --------
    ///     workdir: ...
    ///     model: ...
    ///     ... (more header)
    ///     --------
    ///     user
    ///     <our prompt>
    ///
    ///     <timestamps and tool noise…>
    ///     codex
    ///     <THE ACTUAL ANSWER>
    ///
    ///     tokens used
    ///     12,345
    ///
    /// Strategy: take everything between the LAST `^codex$` line and the next `tokens used` line.
    private static func stripCodexNoise(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")
        var lastCodexIdx: Int?
        var tokensIdx: Int?
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces).lowercased()
            if t == "codex" { lastCodexIdx = i }
            if t.hasPrefix("tokens used") && lastCodexIdx != nil { tokensIdx = i; break }
        }
        if let start = lastCodexIdx, let end = tokensIdx, start + 1 < end {
            let slice = lines[(start + 1)..<end].joined(separator: "\n")
            let trimmed = slice.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        // Fallback: take the last non-empty paragraph
        let paragraphs = raw.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("tokens used") }
        return paragraphs.last ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runProcess(_ proc: Process, label: String) -> Result<String, Error> {
        // Avoid TCC prompts: claude/codex may scan cwd / ~/Music / removable volumes via plugin
        // auto-discovery. Pinning cwd to /tmp keeps file system probes harmless.
        proc.currentDirectoryURL = URL(fileURLWithPath: "/tmp")

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            let start = Date()
            try proc.run()
            proc.waitUntilExit()
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)

            let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            NSLog("Murmur: \(label) exit=\(proc.terminationStatus) in \(elapsed)ms; stdout=\(stdout.count) stderr=\(stderr.count)")

            if proc.terminationStatus != 0 {
                let msg = stderr.isEmpty ? "\(label) exited \(proc.terminationStatus)" :
                                           "\(label): \(stderr.prefix(300))"
                return .failure(NSError(domain: "Polisher", code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: msg]))
            }

            // Trim outer whitespace AND collapse any internal newlines to single spaces.
            // Defense-in-depth: the prompt says "no line breaks", but if the LLM ignores
            // that we still want a single-line result.
            let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let polished = collapseNewlines(trimmed)
            if polished.isEmpty {
                return .failure(NSError(domain: "Polisher", code: -3,
                                        userInfo: [NSLocalizedDescriptionKey: "\(label) 返回空"]))
            }
            return .success(polished)
        } catch {
            return .failure(error)
        }
    }
}
