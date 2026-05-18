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
                       apiBaseUrl: String = "",
                       apiKey: String = "",
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
            case "openai_api":
                result = runOpenAIAPI(text: text, model: model, systemPrompt: prompt,
                                       baseUrl: apiBaseUrl, apiKey: apiKey)
            default:
                result = runClaude(text: text, model: model, systemPrompt: prompt)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - OpenAI-compatible HTTP backend

    /// Fetches the list of model IDs from {baseUrl}/models. Calls back on main queue.
    /// Works for OpenAI proper, Azure OpenAI, vLLM, LM Studio, any compatible endpoint.
    static func fetchOpenAIModels(baseUrl: String, apiKey: String,
                                   completion: @escaping (Result<[String], Error>) -> Void) {
        let url = URL(string: "\(trimSlash(baseUrl))/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 15

        URLSession.shared.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                if let err = err { completion(.failure(err)); return }
                guard let data = data else {
                    completion(.failure(NSError(domain: "Polisher", code: -10,
                                                userInfo: [NSLocalizedDescriptionKey: "empty response"])))
                    return
                }
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode >= 400 {
                    let errMsg = ((json?["error"] as? [String: Any])?["message"] as? String)
                                 ?? "HTTP \(httpResp.statusCode)"
                    completion(.failure(NSError(domain: "Polisher", code: httpResp.statusCode,
                                                userInfo: [NSLocalizedDescriptionKey: errMsg])))
                    return
                }
                guard let arr = json?["data"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "Polisher", code: -11,
                                                userInfo: [NSLocalizedDescriptionKey: "unexpected response shape"])))
                    return
                }
                let ids = arr.compactMap { $0["id"] as? String }.sorted()
                completion(.success(ids))
            }
        }.resume()
    }

    private static func runOpenAIAPI(text: String, model: String, systemPrompt: String,
                                      baseUrl: String, apiKey: String) -> Result<String, Error> {
        guard !apiKey.isEmpty else {
            return .failure(NSError(domain: "Polisher", code: -20,
                                    userInfo: [NSLocalizedDescriptionKey: "API key is empty"]))
        }
        guard let url = URL(string: "\(trimSlash(baseUrl))/chat/completions") else {
            return .failure(NSError(domain: "Polisher", code: -21,
                                    userInfo: [NSLocalizedDescriptionKey: "invalid base URL"]))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "max_tokens": 1024,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        NSLog("Murmur: polish via openai_api at \(baseUrl) model=\(model) text=\(text.count) chars")
        let sem = DispatchSemaphore(value: 0)
        var outcome: Result<String, Error> = .failure(NSError(domain: "Polisher", code: -99,
                                                              userInfo: [NSLocalizedDescriptionKey: "no result"]))
        let start = Date()
        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            if let err = err { outcome = .failure(err); return }
            guard let data = data else {
                outcome = .failure(NSError(domain: "Polisher", code: -22,
                                           userInfo: [NSLocalizedDescriptionKey: "empty response"]))
                return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if let httpResp = resp as? HTTPURLResponse, httpResp.statusCode >= 400 {
                let errMsg = ((json?["error"] as? [String: Any])?["message"] as? String)
                             ?? String(data: data.prefix(300), encoding: .utf8)
                             ?? "HTTP \(httpResp.statusCode)"
                outcome = .failure(NSError(domain: "Polisher", code: httpResp.statusCode,
                                           userInfo: [NSLocalizedDescriptionKey: errMsg]))
                return
            }
            if let choices = json?["choices"] as? [[String: Any]],
               let first = choices.first,
               let msg = first["message"] as? [String: Any],
               let content = msg["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                outcome = .success(collapseNewlines(trimmed))
            } else {
                outcome = .failure(NSError(domain: "Polisher", code: -23,
                                           userInfo: [NSLocalizedDescriptionKey: "no choices in response"]))
            }
        }.resume()
        sem.wait()
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        NSLog("Murmur: openai_api polish elapsed=\(elapsed)ms")
        return outcome
    }

    private static func trimSlash(_ s: String) -> String {
        var r = s
        while r.hasSuffix("/") { r.removeLast() }
        return r
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

        // CRITICAL: redirect stdin to /dev/null. claude -p still waits 3 seconds for stdin
        // data when stdin is a TTY/pipe, even when the prompt is passed as an argument.
        // This single change cuts polish latency by ~3 seconds.
        if let devNull = FileHandle(forReadingAtPath: "/dev/null") {
            proc.standardInput = devNull
        }

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
