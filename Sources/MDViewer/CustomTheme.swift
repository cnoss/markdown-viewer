import AppKit

/// Eigene CSS-Datei des Nutzers, wird nach style.css in den Viewer geladen.
enum CustomTheme {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MD Viewer/theme.css")
    }

    static func ensureExists() {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        reset()
    }

    static func reset() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? template.write(to: url, atomically: true, encoding: .utf8)
    }

    static func read() -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Öffnet die Datei in VS Code, falls vorhanden – sonst in der Standard-App für CSS.
    static func edit() {
        ensureExists()
        if let code = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
            NSWorkspace.shared.open([url], withApplicationAt: code, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Kopiert die Hilfe neben theme.css und zeigt sie im Viewer.
    @MainActor
    static func showHelp() {
        ensureExists()
        guard let bundled = Bundle.main.url(forResource: "Hilfe", withExtension: "md") else { return }
        let help = url.deletingLastPathComponent().appending(path: "Hilfe.md")
        try? FileManager.default.removeItem(at: help)
        try? FileManager.default.copyItem(at: bundled, to: help)
        AppState.shared.open(help)
        NSApp.activate()
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }

    static func reveal() {
        ensureExists()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static let template = """
    /*
     * MD Viewer – eigenes Theme
     *
     * Diese Datei wird nach dem Standard-Layout geladen. Alles, was hier steht,
     * überschreibt die Vorgaben. Beim Speichern aktualisiert sich der Viewer sofort.
     * Zum Aktivieren einer Zeile einfach die Kommentarzeichen entfernen.
     * Anleitung und Rezepte: Menü Hilfe → MD Viewer Hilfe (⌘?)
     */

    /* ---------- Helles Erscheinungsbild ---------- */
    :root {
      /* --text: #1d1d1f;        Fließtext */
      /* --muted: #6e6e73;       Zitate, Nebeninfos */
      /* --faint: #a1a1a6;       Listenpunkte, Meta */
      /* --bg: #ffffff;          Hintergrund */
      /* --rule: #e6e6ea;        Linien, Tabellenränder */
      /* --code-bg: #f5f5f7;     Hintergrund von Code */
      /* --accent: #0a66c2;      Links, Häkchen */
      /* --mark: #fff3b0;        <mark>-Hervorhebung */

      /* --font-sans: -apple-system, "Helvetica Neue", sans-serif; */
      /* --font-serif: ui-serif, "New York", Georgia, serif; */
      /* --font-mono: ui-monospace, "SF Mono", Menlo, monospace; */
      /* --line-height: 1.68; */

      /* --width-narrow: 41rem;  Inhaltsbreite „Schmal“ */
      /* --width-medium: 62rem;  Inhaltsbreite „Mittel“ */
    }

    /* ---------- Dunkles Erscheinungsbild ---------- */
    @media (prefers-color-scheme: dark) {
      :root {
        /* --text: #e6e6eb; */
        /* --bg: #1e1e20; */
        /* --code-bg: #28282b; */
        /* --accent: #5aa9ff; */
      }
    }

    /* ---------- Beispiele für gezielte Anpassungen ---------- */

    /* Überschriften in Akzentfarbe */
    /* h1, h2 { color: var(--accent); } */

    /* Zweite Ebene mit Linie darunter */
    /* h2 { padding-bottom: .3em; border-bottom: 1px solid var(--rule); } */

    /* Tabellen immer über die volle Inhaltsbreite */
    /* table { display: table; width: 100%; } */

    /* Zebrastreifen in Tabellen */
    /* tr:nth-child(even) td { background: var(--code-bg); } */

    /* Mehr Luft oben */
    /* article { padding-top: 6rem; } */

    """
}
