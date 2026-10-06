import AppKit

/// Erzeugt über mdprint (../markdown-printer) ein PDF und öffnet es.
enum PDFExport {
    static var executable: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appending(path: ".local/bin/mdprint"),
            URL(fileURLWithPath: "/opt/homebrew/bin/mdprint"),
            URL(fileURLWithPath: "/usr/local/bin/mdprint"),
        ].first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Läuft im Hintergrund; `completion` kommt auf dem Main Thread, mit Fehlertext oder nil.
    @MainActor
    static func run(_ file: URL, completion: @escaping @MainActor (String?) -> Void) {
        guard let exe = executable else {
            completion("mdprint wurde nicht gefunden. Bitte im Ordner markdown-printer ./install.sh ausführen.")
            return
        }
        let process = Process()
        process.executableURL = exe
        process.arguments = ["--open", file.path]
        process.currentDirectoryURL = file.deletingLastPathComponent()
        // Apps erben keinen Shell-PATH; ohne Homebrew fände env nur das alte /usr/bin/python3.
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = "/opt/homebrew/bin:\(home)/.local/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = env
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { p in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let error = p.terminationStatus == 0 ? nil : (text.isEmpty ? "Exit-Code \(p.terminationStatus)" : text)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(error) } }
        }
        do {
            try process.run()
        } catch {
            completion(error.localizedDescription)
        }
    }

    @MainActor
    static func showError(_ message: String, for file: URL) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "PDF für „\(file.lastPathComponent)“ fehlgeschlagen"
        alert.informativeText = String(message.suffix(4000))
        alert.runModal()
    }
}
