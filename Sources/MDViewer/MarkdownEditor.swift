import SwiftUI
import AppKit

/// Bearbeitungsmodus: der Markdown-Quelltext in einem nativen Textfeld.
/// Speichert automatisch kurz nach dem Tippen, beim Verlassen und beim Dateiwechsel.
struct MarkdownEditor: NSViewRepresentable {
    let file: URL
    let fontSize: Double
    let fontStyle: String
    let contentWidth: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = EditorStyle.background

        let textView = EditorTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        // Typografische Ersetzungen würden Markdown-Syntax verfälschen.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.drawsBackground = false
        textView.insertionPointColor = EditorStyle.accent
        textView.onEscape = { AppState.shared.toggleEditing() }

        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        scroll.documentView = textView
        context.coordinator.textView = textView

        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(file: file, fontSize: fontSize, fontStyle: fontStyle, contentWidth: contentWidth)
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        coordinator.save()
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, @preconcurrency NSTextStorageDelegate {
        weak var textView: EditorTextView?
        private var file: URL?
        private var encoding = String.Encoding.utf8
        /// Stand auf der Platte nach dem letzten Laden oder Speichern.
        private var lastSynced = ""
        private var watcher: FileWatcher?
        private var pendingSave: DispatchWorkItem?
        private var style = EditorStyle(fontSize: 17, fontStyle: "sans")
        private var contentWidth = ""

        override init() {
            super.init()
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(saveNotification),
                               name: NSApplication.willTerminateNotification, object: nil)
            center.addObserver(self, selector: #selector(saveNotification),
                               name: NSApplication.didResignActiveNotification, object: nil)
            AppState.shared.saveEditor = { [weak self] in self?.save() }
        }

        func detach() {
            NotificationCenter.default.removeObserver(self)
            watcher = nil
            AppState.shared.saveEditor = nil
        }

        func update(file: URL, fontSize: Double, fontStyle: String, contentWidth: String) {
            guard let textView else { return }
            let newStyle = EditorStyle(fontSize: fontSize, fontStyle: fontStyle)
            if newStyle != style || contentWidth != self.contentWidth {
                style = newStyle
                self.contentWidth = contentWidth
                textView.apply(style, contentWidth: contentWidth)
                if let storage = textView.textStorage { MarkdownHighlighter.apply(to: storage, style: style) }
            }
            if file != self.file {
                save()
                self.file = file
                load(resetSelection: true)
                watcher = FileWatcher(url: file) { [weak self] in self?.diskChanged() }
            }
        }

        // MARK: Laden und Speichern

        private func load(resetSelection: Bool) {
            guard let textView, let file else { return }
            pendingSave?.cancel()
            let selection = textView.selectedRange()
            if let (text, enc) = MarkdownFile.read(file) {
                encoding = enc
                lastSynced = text
                textView.string = text
                textView.isEditable = FileManager.default.isWritableFile(atPath: file.path)
            } else {
                lastSynced = ""
                textView.string = ""
                textView.isEditable = false
            }
            textView.undoManager?.removeAllActions()
            let length = (textView.string as NSString).length
            textView.setSelectedRange(resetSelection
                ? NSRange(location: 0, length: 0)
                : NSRange(location: min(selection.location, length), length: 0))
            if resetSelection { textView.scroll(.zero) }
        }

        @objc private func saveNotification() { save() }

        func save() {
            pendingSave?.cancel()
            guard let textView, let file, textView.isEditable, textView.string != lastSynced else { return }
            let text = textView.string
            do {
                try MarkdownFile.write(text, to: file, encoding: encoding)
                lastSynced = text
            } catch {
                let alert = NSAlert(error: error)
                alert.messageText = "„\(file.lastPathComponent)“ konnte nicht gespeichert werden"
                alert.runModal()
            }
        }

        private func scheduleSave() {
            pendingSave?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.save() }
            pendingSave = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
        }

        /// Die Datei wurde auf der Platte geändert – von uns selbst oder von außen.
        private func diskChanged() {
            guard let textView, let file, let (disk, _) = MarkdownFile.read(file),
                  disk != lastSynced else { return } // eigenes Speichern
            if textView.string == lastSynced {
                load(resetSelection: false)
                return
            }
            let alert = NSAlert()
            alert.messageText = "„\(file.lastPathComponent)“ wurde außerhalb geändert"
            alert.informativeText = "Beim Neuladen gehen deine noch nicht gespeicherten Änderungen verloren."
            alert.addButton(withTitle: "Neu laden")
            alert.addButton(withTitle: "Meine Version behalten")
            if alert.runModal() == .alertFirstButtonReturn {
                load(resetSelection: false)
            } else {
                lastSynced = disk
                save()
            }
        }

        // MARK: Delegates

        func textDidChange(_ notification: Notification) { scheduleSave() }

        func textStorage(_ storage: NSTextStorage, didProcessEditing mask: NSTextStorageEditActions,
                         range: NSRange, changeInLength delta: Int) {
            guard mask.contains(.editedCharacters) else { return }
            MarkdownHighlighter.apply(to: storage, style: style, batch: false)
        }
    }
}

/// Textfeld mit begrenzter, zentrierter Zeilenlänge wie im Viewer.
final class EditorTextView: NSTextView {
    var onEscape: (() -> Void)?
    private var maxContentWidth = CGFloat.greatestFiniteMagnitude
    private var sidePadding: CGFloat = 40

    func apply(_ style: EditorStyle, contentWidth: String) {
        let rem = CGFloat(style.fontSize)
        switch contentWidth {
        case "medium": maxContentWidth = 62 * rem
        case "full": maxContentWidth = .greatestFiniteMagnitude
        default: maxContentWidth = 41 * rem
        }
        sidePadding = (contentWidth == "full" ? 3 : 2.75) * rem
        textContainerInset = NSSize(width: sidePadding, height: 3 * rem)
        typingAttributes = style.baseAttributes
        defaultParagraphStyle = style.paragraph
        updateInset()
    }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        updateInset()
    }

    private func updateInset() {
        let side = max(sidePadding, (bounds.width - maxContentWidth) / 2)
        if textContainerInset.width != side {
            textContainerInset = NSSize(width: side, height: textContainerInset.height)
        }
    }

    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

// MARK: - Darstellung

struct EditorStyle: Equatable {
    let fontSize: Double
    let fontStyle: String

    // Farben wie im Viewer (style.css).
    static let background = NSColor.dynamic(light: 0xffffff, dark: 0x1e1e20)
    static let text = NSColor.dynamic(light: 0x1d1d1f, dark: 0xe6e6eb)
    static let muted = NSColor.dynamic(light: 0x6e6e73, dark: 0x9a9aa0)
    static let faint = NSColor.dynamic(light: 0xa1a1a6, dark: 0x6c6c72)
    static let codeBackground = NSColor.dynamic(light: 0xf5f5f7, dark: 0x28282b)
    static let accent = NSColor.dynamic(light: 0x0a66c2, dark: 0x5aa9ff)

    var font: NSFont {
        let base = NSFont.systemFont(ofSize: fontSize)
        guard fontStyle == "serif", let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        return NSFont(descriptor: serif, size: fontSize) ?? base
    }

    var mono: NSFont { .monospacedSystemFont(ofSize: fontSize * 0.88, weight: .regular) }

    var paragraph: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.45
        return p
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: Self.text, .paragraphStyle: paragraph]
    }
}

/// Dezente Hervorhebung der Markdown-Syntax. Die Zeichen bleiben unverändert sichtbar.
enum MarkdownHighlighter {
    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = [.anchorsMatchLines]) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let frontMatter = regex(#"\A---\n.*?\n(---|\.\.\.)$"#, [.anchorsMatchLines, .dotMatchesLineSeparators])
    private static let fence = regex(#"^(```|~~~).*?(^\1[ \t]*$|\z)"#, [.anchorsMatchLines, .dotMatchesLineSeparators])
    private static let heading = regex(#"^(#{1,6})[ \t].*$"#)
    private static let quote = regex(#"^[ \t]*>.*$"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d+[.)])[ \t]+(\[[ xX]\][ \t])?"#)
    private static let rule = regex(#"^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*$"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)[^\n]+?(?<=\S)\1"#)
    private static let italic = regex(#"(?<![*\w])\*(?=[^\s*])[^*\n]+?(?<=\S)\*(?!\*)|(?<![_\w])_(?=\S)[^_\n]+?(?<=\S)_(?!\w)"#)
    private static let code = regex(#"`[^`\n]+`"#)
    private static let link = regex(#"!?\[[^\]\n]*\]\(([^)\n]*)\)"#)

    /// `batch: false` innerhalb von `didProcessEditing`, dort läuft bereits eine Bearbeitung.
    static func apply(to storage: NSTextStorage, style: EditorStyle, batch: Bool = true) {
        let text = storage.string
        let all = NSRange(location: 0, length: storage.length)
        if batch { storage.beginEditing() }
        storage.setAttributes(style.baseAttributes, range: all)

        func each(_ re: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            re.enumerateMatches(in: text, range: all) { m, _, _ in if let m { body(m) } }
        }
        func color(_ c: NSColor, _ r: NSRange) { storage.addAttribute(.foregroundColor, value: c, range: r) }
        func trait(_ t: NSFontTraitMask, _ r: NSRange) {
            storage.enumerateAttribute(.font, in: r) { value, sub, _ in
                guard let f = value as? NSFont else { return }
                storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: t), range: sub)
            }
        }

        each(heading) { m in
            trait(.boldFontMask, m.range)
            color(EditorStyle.faint, m.range(at: 1))
        }
        each(quote) { color(EditorStyle.muted, $0.range) }
        each(listMarker) { color(EditorStyle.faint, $0.range) }
        each(rule) { color(EditorStyle.faint, $0.range) }
        each(link) { m in
            color(EditorStyle.accent, m.range)
            color(EditorStyle.faint, m.range(at: 1))
        }
        each(bold) { trait(.boldFontMask, $0.range) }
        each(italic) { trait(.italicFontMask, $0.range) }
        // Code zuletzt, damit Fett/Kursiv darin wieder überschrieben wird.
        each(code) { m in
            storage.addAttributes([.font: style.mono, .backgroundColor: EditorStyle.codeBackground,
                                   .foregroundColor: EditorStyle.text], range: m.range)
        }
        for re in [fence, frontMatter] {
            each(re) { storage.addAttributes([.font: style.mono, .foregroundColor: EditorStyle.muted], range: $0.range) }
        }
        if batch { storage.endEditing() }
    }
}

// MARK: - Datei lesen und schreiben

enum MarkdownFile {
    static func read(_ url: URL) -> (String, String.Encoding)? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return (text, .utf8) }
        var encoding = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &encoding) { return (text, encoding) }
        if let text = try? String(contentsOf: url, encoding: .isoLatin1) { return (text, .isoLatin1) }
        return nil
    }

    /// Schreibt über eine temporäre Datei und ersetzt dann das Original.
    /// So liegt nie eine halbe Datei auf der Platte, und Rechte sowie Symlinks bleiben erhalten.
    static func write(_ text: String, to url: URL, encoding: String.Encoding) throws {
        let target = url.resolvingSymlinksInPath()
        let data = text.data(using: encoding) ?? Data(text.utf8)
        let fm = FileManager.default
        let tempDir = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: target, create: true)
        let temp = tempDir.appending(path: target.lastPathComponent)
        try data.write(to: temp)
        let permissions = try? fm.attributesOfItem(atPath: target.path)[.posixPermissions]
        _ = try fm.replaceItemAt(target, withItemAt: temp)
        if let permissions { try? fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path) }
        try? fm.removeItem(at: tempDir)
    }
}

extension NSColor {
    static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        func rgb(_ v: UInt32) -> NSColor {
            NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                    blue: CGFloat(v & 0xff) / 255, alpha: 1)
        }
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? rgb(dark) : rgb(light)
        }
    }
}
