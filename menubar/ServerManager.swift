// ServerManager.swift
// Manages the embedded Python server lifecycle:
// copies files on first run, sets up venv, manages launchd, tracks state.

import Foundation
import Combine

@MainActor
class ServerManager: ObservableObject {

    static let shared = ServerManager()

    // MARK: - State

    enum State: Equatable {
        case checking
        case installing(String)   // progress message
        case needsCredentials
        case launching
        case waitingForAuth       // server up, browser opened for OAuth
        case ready
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking), (.needsCredentials, .needsCredentials),
                 (.launching, .launching), (.waitingForAuth, .waitingForAuth),
                 (.ready, .ready):                        return true
            case (.installing(let a), .installing(let b)): return a == b
            case (.error(let a),      .error(let b)):      return a == b
            default: return false
            }
        }
    }

    @Published var state: State = .checking

    // MARK: - Paths

    private let fm = FileManager.default

    /// ~/Library/Application Support/ytAnalytics/server/
    let serverDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ytAnalytics/server")
    }()

    var credentialsDir:  URL { serverDir.appendingPathComponent("credentials") }
    var credentialsFile: URL { credentialsDir.appendingPathComponent("client_secret.json") }
    var tokenFile:       URL { credentialsDir.appendingPathComponent("token.json") }
    var venvDir:         URL { serverDir.appendingPathComponent("venv") }
    var configFile:      URL { serverDir.appendingPathComponent("config.json") }
    var pythonBin:       URL { venvDir.appendingPathComponent("bin/python") }

    private var plistURL: URL {
        fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents/com.ytanalytics.server.plist")
    }
    private var logDir: URL {
        fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/ytAnalytics")
    }

    // MARK: - Entry point

    func start() {
        Task { await run() }
    }

    private func run() async {
        state = .checking

        if !fm.fileExists(atPath: serverDir.appendingPathComponent("server.py").path) {
            await install()
            guard case .needsCredentials = state else { return }
        }

        if !fm.fileExists(atPath: credentialsFile.path) {
            state = .needsCredentials
            return
        }

        await launchServer()
    }

    // MARK: - Install (first run)

    private func install() async {
        do {
            state = .installing("Creating folders…")
            try fm.createDirectory(at: serverDir,      withIntermediateDirectories: true)
            try fm.createDirectory(at: credentialsDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: logDir,         withIntermediateDirectories: true)

            state = .installing("Copying server files…")
            guard let bundleServer = Bundle.main.resourceURL?.appendingPathComponent("server") else {
                throw NSError(domain: "ServerManager", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Server files missing from app bundle."])
            }
            for item in try fm.contentsOfDirectory(at: bundleServer, includingPropertiesForKeys: nil) {
                let dest = serverDir.appendingPathComponent(item.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: item, to: dest)
            }

            state = .installing("Setting up Python environment…")
            try await shell("/usr/bin/python3", ["-m", "venv", venvDir.path])

            state = .installing("Installing dependencies (this takes ~1 min)…")
            let pip = venvDir.appendingPathComponent("bin/pip").path
            let req = serverDir.appendingPathComponent("requirements.txt").path
            try await shell(pip, ["install", "-q", "--upgrade", "pip"])
            try await shell(pip, ["install", "-q", "-r", req])

            state = .needsCredentials

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Credentials

    /// Call after user drops / selects their client_secret.json.
    func installCredentials(from sourceURL: URL) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        if fm.fileExists(atPath: credentialsFile.path) {
            try fm.removeItem(at: credentialsFile)
        }
        try fm.copyItem(at: sourceURL, to: credentialsFile)
    }

    /// Start the server after credentials have been installed.
    func startAfterCredentials() {
        Task { await launchServer() }
    }

    // MARK: - Server launch

    private func launchServer() async {
        writePlist()
        state = .launching

        // Unload old instance, load new
        launchctl("unload", plistURL.path)
        launchctl("load",   plistURL.path)

        // Poll until server responds
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if await serverIsUp() {
                state = .ready
                return
            }
        }

        // Server launched but OAuth hasn't completed yet (browser is open)
        state = .waitingForAuth
        await waitForAuth()
    }

    private func waitForAuth() async {
        // Keep polling every 2s until server is actually ready
        for _ in 0..<120 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if await serverIsUp() {
                state = .ready
                return
            }
        }
        state = .error("Google sign-in timed out. Please re-open the app to try again.")
    }

    func restartServer() {
        launchctl("unload", plistURL.path)
        launchctl("load",   plistURL.path)
    }

    // MARK: - Health

    func serverIsUp() async -> Bool {
        guard let url = URL(string: "http://localhost:8765/health") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 2)
        req.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    // MARK: - Launchd plist

    private func writePlist() {
        try? fm.createDirectory(at: plistURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>             <string>com.ytanalytics.server</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(pythonBin.path)</string>
                <string>\(serverDir.appendingPathComponent("server.py").path)</string>
                <string>--config</string>
                <string>\(configFile.path)</string>
            </array>
            <key>RunAtLoad</key>         <true/>
            <key>KeepAlive</key>         <true/>
            <key>WorkingDirectory</key>  <string>\(serverDir.path)</string>
            <key>StandardOutPath</key>   <string>\(logDir.path)/server.log</string>
            <key>StandardErrorPath</key> <string>\(logDir.path)/server.err</string>
            <key>ThrottleInterval</key>  <integer>10</integer>
        </dict>
        </plist>
        """
        try? content.write(to: plistURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    @discardableResult
    private func launchctl(_ verb: String, _ arg: String) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = [verb, arg]
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus
    }

    private func shell(_ exe: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 { cont.resume() }
                else { cont.resume(throwing: NSError(domain: "shell", code: Int(proc.terminationStatus))) }
            }
            do    { try p.run() }
            catch { cont.resume(throwing: error) }
        }
    }
}
