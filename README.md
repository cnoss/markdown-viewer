# MD Viewer

Ein ruhiger, nativer Markdown-Viewer für den Mac (SwiftUI + WebKit). Lesen hier, schreiben im Editor deiner Wahl. Bedienung und Theme-Anleitung im Detail: [Resources/Hilfe.md](Resources/Hilfe.md), in der App unter **Hilfe** (⌘?).

## Funktionen

- Dateibrowser mit Konsolenzeile: tippen filtert, ⇥ vervollständigt Pfade, Pfeiltasten navigieren
- Live-Aktualisierung: Speichern im Editor zeigt die Änderung sofort an
- Einfacher Bearbeitungsmodus (⌘↩) mit dezenter Syntaxhervorhebung und automatischem Speichern
- Öffnen im externen Editor (⌘E), z. B. Typora, iA Writer, VS Code
- PDF-Export per Knopf oder ⌘P über [mdprint](../markdown-printer)
- Hell/Dunkel, Sans/Serif, Schriftgröße, drei Inhaltsbreiten
- Eigenes Theme als CSS-Datei, wird beim Speichern live übernommen
- Finder-Dienst „In MD Viewer öffnen“ für Ordner und Markdown-Dateien

## Bauen und installieren

Voraussetzung: macOS 14 oder neuer, Swift 6 (Xcode oder Command Line Tools).

```sh
./build.sh           # → build/MD Viewer.app
./build.sh install   # zusätzlich nach ~/Applications kopieren und registrieren
```

Das App-Icon wird beim ersten Build aus [Support/make-icon.swift](Support/make-icon.swift) erzeugt. Signiert wird ad hoc.

Stammt `.build/` aus einem anderen Ordner (z. B. nach einer Umbenennung), schlägt der Build mit einem Module-Cache-Fehler fehl. Dann `rm -rf .build` und neu bauen.

### Als Standard-App für Markdown

Im Finder: `.md`-Datei auswählen → ⌘I → „Öffnen mit“ → MD Viewer → **Alle ändern …**

Oder mit [duti](https://github.com/moretension/duti):

```sh
for uti in net.ia.markdown net.daringfireball.markdown io.typora.markdown; do
  duti -s de.cnoss.mdviewer $uti all
done
```

`.md` wird je nach installierten Apps einer anderen UTI zugeordnet (z. B. `net.ia.markdown` durch iA Writer), deshalb alle drei.

## PDF-Export

Der Knopf ruft `mdprint --open <datei>` auf. mdprint wird in `~/.local/bin`, `/opt/homebrew/bin` und `/usr/local/bin` gesucht, die Installation erledigt `./install.sh` im Projekt markdown-printer. Weil Apps keinen Shell-PATH erben, setzt MD Viewer den PATH selbst auf Homebrew zuerst. Sonst liefe mdprint mit dem alten `/usr/bin/python3`. Fehler von Pandoc oder Typst erscheinen als Dialog.

## Eigenes Theme

```
~/Library/Application Support/MD Viewer/theme.css
```

Wird nach dem Standard-Layout geladen und überschreibt es. Bearbeiten und Zurücksetzen über die Einstellungen (⌘,). Variablen, Selektoren und Rezepte stehen in der Hilfe.

## Aufbau

| Datei | Zweck |
|---|---|
| `Sources/MDViewer/MDViewerApp.swift` | App, Menüs, Tastenkürzel, AppDelegate |
| `Sources/MDViewer/AppState.swift` | Zustand: Ordner, offene Datei, Aktionen |
| `Sources/MDViewer/ContentView.swift` | Fenster mit Seitenleiste und Werkzeugleiste |
| `Sources/MDViewer/BrowserView.swift` | Dateiliste mit Konsolenzeile |
| `Sources/MDViewer/ConsoleField.swift` | Eingabefeld mit Tastaturbehandlung |
| `Sources/MDViewer/FileListing.swift` | Einlesen und Filtern von Ordnern |
| `Sources/MDViewer/FileWatcher.swift` | Meldet Änderungen an Datei, Ordner und theme.css |
| `Sources/MDViewer/MarkdownWebView.swift` | WKWebView-Anbindung |
| `Sources/MDViewer/MarkdownEditor.swift` | Bearbeitungsmodus: Textfeld, Hervorhebung, Speichern |
| `Sources/MDViewer/PDFExport.swift` | Aufruf von mdprint |
| `Sources/MDViewer/ExternalEditor.swift` | Externen Editor finden und öffnen |
| `Sources/MDViewer/CustomTheme.swift` | theme.css und Hilfe |
| `Sources/MDViewer/SettingsView.swift` | Einstellungen |
| `Sources/MDViewer/ServiceProvider.swift` | Finder-Dienst |
| `Resources/Web/` | Renderer: marked, DOMPurify, highlight.js, Layout |
| `Support/Info.plist` | Bundle-ID, Dokumenttypen, Dienst |
