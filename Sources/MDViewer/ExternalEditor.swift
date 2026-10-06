import AppKit

enum ExternalEditor {
    static let knownBundleIDs = [
        "abnerworks.Typora",
        "pro.writer.mac",
        "com.microsoft.VSCode",
        "com.apple.TextEdit",
    ]

    static var installed: [URL] {
        knownBundleIDs.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }

    /// Eingestellter Editor, sonst der erste installierte bekannte.
    static var current: URL? {
        if let path = UserDefaults.standard.string(forKey: PrefKey.editorPath),
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return installed.first
    }

    static func displayName(_ app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }

    static func open(_ file: URL) {
        guard let app = current else {
            NSWorkspace.shared.open(file)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
