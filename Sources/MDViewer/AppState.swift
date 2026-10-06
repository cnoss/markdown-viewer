import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers

enum PrefKey {
    static let editorPath = "editorAppPath"
    static let fontStyle = "fontStyle"
    static let fontSize = "fontSize"
    static let lastDirectory = "lastDirectory"
    static let appearance = "appearance"
    static let contentWidth = "contentWidth"
}

/// Breite des Inhalts im Viewer: "narrow", "medium" oder "full".
enum ContentWidth {
    static let all = ["narrow", "medium", "full"]

    static func label(_ value: String) -> String {
        switch value {
        case "medium": "Mittel"
        case "full": "Volle Breite"
        default: "Schmal"
        }
    }

    static func next(after value: String) -> String {
        let i = all.firstIndex(of: value) ?? 0
        return all[(i + 1) % all.count]
    }
}

/// "system", "light" oder "dark" – gilt für die ganze App inklusive Viewer.
enum Appearance {
    static func apply(_ value: String) {
        switch value {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

@MainActor @Observable
final class AppState {
    static let shared = AppState()

    private(set) var directory: URL
    /// Die angezeigte Markdown-Datei.
    var openFile: URL?
    /// Eintrag, der nach dem nächsten Einlesen des Ordners markiert werden soll.
    var pendingHighlight: URL?
    /// Wird hochgezählt, um den Fokus in die Konsolenzeile zu setzen.
    private(set) var consoleFocusToken = 0
    /// Datei, für die gerade ein PDF erzeugt wird.
    private(set) var exportingPDF: URL?

    private init() {
        let fm = FileManager.default
        if let saved = UserDefaults.standard.string(forKey: PrefKey.lastDirectory),
           fm.isDirectory(URL(fileURLWithPath: saved)) {
            directory = URL(fileURLWithPath: saved)
        } else {
            directory = fm.homeDirectoryForCurrentUser.appending(path: "Downloads")
        }
    }

    func navigate(to dir: URL, highlight: URL? = nil) {
        directory = dir.standardizedFileURL
        pendingHighlight = highlight
        UserDefaults.standard.set(directory.path, forKey: PrefKey.lastDirectory)
    }

    func goToParent() {
        let parent = directory.deletingLastPathComponent()
        guard parent.path != directory.path else { return }
        navigate(to: parent, highlight: directory)
    }

    /// Öffnet eine Datei oder einen Ordner (Finder, Drag & Drop, Öffnen-Dialog).
    func open(_ url: URL) {
        let url = url.standardizedFileURL
        if FileManager.default.isDirectory(url) {
            navigate(to: url)
        } else {
            navigate(to: url.deletingLastPathComponent(), highlight: url)
            openFile = url
        }
    }

    func focusConsole() { consoleFocusToken += 1 }

    func openInEditor(_ url: URL? = nil) {
        guard let file = url ?? openFile else { return }
        ExternalEditor.open(file)
    }

    func exportPDF(_ url: URL? = nil) {
        guard let file = url ?? openFile, exportingPDF == nil else { return }
        exportingPDF = file
        PDFExport.run(file) { [weak self] error in
            self?.exportingPDF = nil
            if let error { PDFExport.showError(error, for: file) }
        }
    }

    func revealInFinder(_ url: URL? = nil) {
        guard let file = url ?? openFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.markdown, .folder, .plainText]
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }
}

extension FileManager {
    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

extension URL {
    var isMarkdown: Bool {
        ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"].contains(pathExtension.lowercased())
    }

    /// Pfad mit ~ statt Benutzerordner.
    var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

struct Place: Identifiable {
    let name: String
    let url: URL
    let shortcut: KeyEquivalent
    let modifiers: EventModifiers
    var id: String { name }

    static var all: [Place] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Place(name: "Downloads", url: home.appending(path: "Downloads"), shortcut: "l", modifiers: [.command, .option]),
            Place(name: "Schreibtisch", url: home.appending(path: "Desktop"), shortcut: "d", modifiers: [.command, .shift]),
            Place(name: "Dokumente", url: home.appending(path: "Documents"), shortcut: "o", modifiers: [.command, .shift]),
            Place(name: "Benutzerordner", url: home, shortcut: "h", modifiers: [.command, .shift]),
        ]
    }
}
