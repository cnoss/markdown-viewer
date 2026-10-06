import AppKit

/// Finder-Dienst „In MD Viewer öffnen“ (Rechtsklick auf Ordner oder Markdown-Datei).
final class ServiceProvider: NSObject {
    @objc(openInViewer:userData:error:)
    func openInViewer(_ pboard: NSPasteboard, userData: String?,
                      error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL]
        guard let url = urls?.first else { return }
        MainActor.assumeIsolated {
            AppState.shared.open(url)
            NSApp.activate()
        }
    }
}
