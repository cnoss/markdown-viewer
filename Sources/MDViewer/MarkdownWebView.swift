import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let file: URL
    let fontSize: Double
    let fontStyle: String
    let contentWidth: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.isInspectable = true // Safari → Entwickler → MD Viewer
        context.coordinator.webView = webView

        if let template = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            // Leserechte auf das ganze Dateisystem, damit relative Bilder neben der Datei laden.
            webView.loadFileURL(template, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(file: file, fontSize: fontSize, fontStyle: fontStyle, contentWidth: contentWidth)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var pageLoaded = false
        private var file: URL?
        private var fontSize = 17.0
        private var fontStyle = "sans"
        private var contentWidth = "narrow"
        private var watcher: FileWatcher?
        private var themeWatcher: FileWatcher?

        override init() {
            super.init()
            CustomTheme.ensureExists()
            themeWatcher = FileWatcher(url: CustomTheme.url) { [weak self] in
                self?.render(keepScroll: true)
            }
        }

        func update(file: URL, fontSize: Double, fontStyle: String, contentWidth: String) {
            let fileChanged = file != self.file
            let styleChanged = fontSize != self.fontSize || fontStyle != self.fontStyle
                || contentWidth != self.contentWidth
            guard fileChanged || styleChanged else { return }

            self.file = file
            self.fontSize = fontSize
            self.fontStyle = fontStyle
            self.contentWidth = contentWidth

            if fileChanged {
                watcher = FileWatcher(url: file) { [weak self] in
                    self?.render(keepScroll: true)
                }
            }
            render(keepScroll: !fileChanged)
        }

        private func render(keepScroll: Bool) {
            guard pageLoaded, let webView, let file else { return }
            let markdown = Self.read(file)
            webView.callAsyncJavaScript(
                "return renderMarkdown(md, base, opts)",
                arguments: [
                    "md": markdown,
                    "base": file.deletingLastPathComponent().absoluteString,
                    "opts": ["fontSize": fontSize, "fontStyle": fontStyle, "width": contentWidth, "keepScroll": keepScroll,
                             "customCSS": CustomTheme.read()],
                ],
                in: nil, in: .page
            ) { result in
                if case .failure(let error) = result {
                    NSLog("Render-Fehler: \(error)")
                }
                SnapshotForTesting.takeIfRequested(webView)
            }
        }

        private static func read(_ url: URL) -> String {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
            var encoding = String.Encoding.utf8
            if let text = try? String(contentsOf: url, usedEncoding: &encoding) { return text }
            return (try? String(contentsOf: url, encoding: .isoLatin1)) ?? "*Datei konnte nicht gelesen werden.*"
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            render(keepScroll: false)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                // Nur das eigene Template darf geladen werden.
                decisionHandler(pageLoaded ? .cancel : .allow)
                return
            }
            decisionHandler(.cancel)
            if url.isFileURL {
                let target = URL(fileURLWithPath: url.path)
                if target.standardizedFileURL == CustomTheme.url.standardizedFileURL {
                    CustomTheme.edit()
                } else if target.isMarkdown || FileManager.default.isDirectory(target) {
                    AppState.shared.open(target)
                } else {
                    NSWorkspace.shared.open(target)
                }
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

/// Entwicklungshilfe: MDV_SNAPSHOT=/pfad.png schreibt nach dem ersten Rendern ein Bild und beendet die App.
@MainActor
enum SnapshotForTesting {
    private static var done = false

    static func takeIfRequested(_ webView: WKWebView) {
        guard !done, let out = ProcessInfo.processInfo.environment["MDV_SNAPSHOT"] else { return }
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let window = webView.window, let view = window.contentView,
               let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: out.replacingOccurrences(of: ".png", with: "-window.png")))
            }
            webView.takeSnapshot(with: nil) { image, _ in
                if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                NSApp.terminate(nil)
            }
        }
    }
}
