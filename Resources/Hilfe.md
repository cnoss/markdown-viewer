# MD Viewer – Hilfe

Ein ruhiger Viewer für Markdown-Dateien. Lesen hier, schreiben im Editor deiner Wahl.

## Inhalt

- [Bedienung](#bedienung)
- [Eigenes Theme](#eigenes-theme)
- [Die Variablen](#die-variablen)
- [Hell und dunkel](#hell-und-dunkel)
- [Elemente gezielt gestalten](#elemente-gezielt-gestalten)
- [Rezepte](#rezepte)
- [Mit dem Web-Inspektor arbeiten](#mit-dem-web-inspektor-arbeiten)
- [Fehlersuche](#fehlersuche)

---

## Bedienung

### Konsole (links)

Die Eingabezeile hat immer den Fokus. Tippen filtert die Liste.

| Taste | Wirkung |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Eintrag wählen, Datei erscheint sofort rechts |
| <kbd>←</kbd> | Eine Ebene nach oben (bei leerer Eingabe) |
| <kbd>→</kbd> | Markierten Ordner betreten (bei leerer Eingabe) |
| <kbd>↵</kbd> | Ordner betreten bzw. Datei im Editor öffnen |
| <kbd>⌫</kbd> | Eine Ebene nach oben (bei leerer Eingabe) |
| <kbd>Esc</kbd> | Eingabe leeren |
| `~/Doc` + <kbd>⇥</kbd> | Pfad vervollständigen wie in der Shell |
| `..` + <kbd>↵</kbd> | Eine Ebene nach oben |

Der Stapel-Knopf rechts in der Eingabezeile schaltet um, ob die Suche auch Unterordner durchsucht.

### Tastenkürzel

| Kürzel | Wirkung |
|---|---|
| <kbd>⌘E</kbd> | Datei im eingestellten Editor öffnen |
| <kbd>⇧⌘R</kbd> | Datei im Finder zeigen |
| <kbd>⌘K</kbd> | In die Eingabezeile springen |
| <kbd>⌘↑</kbd> | Übergeordneter Ordner |
| <kbd>⌥⌘L</kbd> | Downloads |
| <kbd>⇧⌘D</kbd> / <kbd>⇧⌘O</kbd> / <kbd>⇧⌘H</kbd> | Schreibtisch / Dokumente / Benutzerordner |
| <kbd>⌘+</kbd> <kbd>⌘-</kbd> <kbd>⌘0</kbd> | Schrift größer / kleiner / zurücksetzen |
| <kbd>⌘\\</kbd> | Inhaltsbreite wechseln (Schmal → Mittel → Voll) |
| <kbd>⌘,</kbd> | Einstellungen |

### Finder

- **Rechtsklick → In MD Viewer öffnen** funktioniert auf Ordnern und Markdown-Dateien.
- Taucht der Eintrag nicht auf: *Systemeinstellungen → Tastatur → Tastaturkurzbefehle → Dienste → Dateien und Ordner*.
- Speicherst du eine Datei im Editor, aktualisiert sich die Ansicht sofort.

---

## Eigenes Theme

Dein Theme ist eine einzige CSS-Datei: [theme.css](theme.css). Sie liegt im selben Ordner wie diese Hilfe:

```
~/Library/Application Support/MD Viewer/theme.css
```

Öffnen kannst du sie über *Einstellungen → Eigenes Theme → Theme bearbeiten …*

So funktioniert es:

1. Die Datei wird **nach** dem Standard-Layout geladen. Was du dort schreibst, gewinnt.
2. Beim **Speichern** aktualisiert sich der Viewer sofort, ohne Neustart.
3. Die Vorlage ist komplett auskommentiert. Kommentarzeichen `/* … */` entfernen, und die Zeile wirkt.
4. *Zurücksetzen* in den Einstellungen stellt die Vorlage wieder her.

> **Tipp:** Lass diese Hilfe oder eine eigene Testdatei im Viewer offen, während du `theme.css` im Editor bearbeitest. So siehst du jede Änderung beim Speichern.

---

## Die Variablen

Am schnellsten passt du das Layout über Variablen an. Sie stehen im Block `:root`:

```css
:root {
  --accent: #b4361e;
  --font-sans: "Avenir Next", sans-serif;
}
```

### Farben

| Variable | Wofür | Hell | Dunkel |
|---|---|---|---|
| `--text` | Fließtext | `#1d1d1f` | `#e6e6eb` |
| `--muted` | Zitate, Nebeninfos | `#6e6e73` | `#9a9aa0` |
| `--faint` | Listenpunkte, Meta-Zeile | `#a1a1a6` | `#6c6c72` |
| `--bg` | Hintergrund | `#ffffff` | `#1e1e20` |
| `--rule` | Linien, Tabellenränder | `#e6e6ea` | `#343437` |
| `--code-bg` | Hintergrund von Code | `#f5f5f7` | `#28282b` |
| `--accent` | Links, Häkchen, Markierung | `#0a66c2` | `#5aa9ff` |
| `--mark` | `<mark>`-Hervorhebung | `#fff3b0` | `#5c4d12` |

### Schrift und Maße

| Variable | Wofür | Standard |
|---|---|---|
| `--font-sans` | Schrift bei Einstellung „Sans“ | SF Pro |
| `--font-serif` | Schrift bei Einstellung „Serif“ | New York |
| `--font-mono` | Code | SF Mono |
| `--line-height` | Zeilenabstand im Fließtext | `1.68` |
| `--width-narrow` | Inhaltsbreite „Schmal“ | `41rem` |
| `--width-medium` | Inhaltsbreite „Mittel“ | `62rem` |

Jede auf dem Mac installierte Schrift funktioniert, z. B. aus der App *Schriftsammlung* oder von Adobe Fonts. Der Name muss so geschrieben sein, wie er in der Schriftsammlung steht.

**Schriftgröße** und **Inhaltsbreite** stellst du nicht im CSS ein, sondern in den Einstellungen bzw. mit <kbd>⌘+</kbd> und <kbd>⌘\\</kbd>. Alle Größen im Layout sind in `rem` angegeben und skalieren mit.

---

## Hell und dunkel

Farben für das dunkle Erscheinungsbild gehören in einen eigenen Block:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #15171a;
    --accent: #ff8a65;
  }
}
```

Das gilt unabhängig davon, ob „Dunkel“ in den Einstellungen fest gewählt ist oder dem System folgt.

---

## Elemente gezielt gestalten

Reicht eine Variable nicht, sprichst du die Elemente direkt an. Alles steckt in `article`:

| Selektor | Element |
|---|---|
| `h1` … `h6` | Überschriften |
| `p` | Absätze |
| `a` | Links |
| `ul`, `ol`, `li`, `li::marker` | Listen und ihre Aufzählungszeichen |
| `blockquote` | Zitate |
| `pre`, `pre code` | Code-Blöcke |
| `:not(pre) > code` | Code im Fließtext |
| `table`, `th`, `td`, `tr` | Tabellen |
| `img` | Bilder |
| `hr` | Trennlinie |
| `kbd`, `mark` | Tasten, Hervorhebungen |
| `.front-matter` | Meta-Zeile aus dem YAML-Kopf (`title:`, `date:` …) |
| `article` | Der gesamte Inhaltsbereich (Ränder, Breite) |

Je nach Einstellung tragen sich diese Zustände am `body` ein:

| Selektor | Bedeutung |
|---|---|
| `body.serif` | Schrift „Serif“ ist gewählt |
| `body[data-width="narrow"]` | Inhaltsbreite „Schmal“ |
| `body[data-width="medium"]` | Inhaltsbreite „Mittel“ |
| `body[data-width="full"]` | Inhaltsbreite „Voll“ |

---

## Rezepte

Alle Rezepte kannst du einzeln kopieren und kombinieren.

### Überschriften in Akzentfarbe

```css
h1, h2 { color: var(--accent); }
```

### Linie unter H2

```css
h2 {
  padding-bottom: .3em;
  border-bottom: 1px solid var(--rule);
}
```

### Tabellen immer über die volle Breite, mit Zebrastreifen

```css
table { display: table; width: 100%; }
tr:nth-child(even) td { background: var(--code-bg); }
th { background: var(--code-bg); padding-left: .75rem; }
td { padding-left: .75rem; }
```

### Bei „Voll“ trotzdem lesbare Absätze

Tabellen und Code nutzen die volle Breite, Fließtext bleibt angenehm schmal:

```css
body[data-width="full"] :is(p, ul, ol, blockquote, h1, h2, h3, h4) {
  max-width: 48rem;
}
```

### Warmes Papier-Theme

```css
:root {
  --bg: #fbf8f1;
  --text: #2b2722;
  --code-bg: #f1ece1;
  --rule: #e4dccb;
  --accent: #a2522c;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1d1b18;
    --text: #e9e3d6;
    --code-bg: #2a2722;
    --rule: #3a352d;
    --accent: #e09560;
  }
}
```

### Nummerierte Überschriften

```css
article { counter-reset: h2; }
h2 { counter-increment: h2; counter-reset: h3; }
h2::before { content: counter(h2) ". "; color: var(--faint); }
h3 { counter-increment: h3; }
h3::before { content: counter(h2) "." counter(h3) " "; color: var(--faint); }
```

### Kompaktere Darstellung

```css
:root { --line-height: 1.5; }
article { padding-top: 2.5rem; }
p, ul, ol, pre, table { margin-bottom: .8rem; }
h2 { margin-top: 1.8em; }
```

---

## Mit dem Web-Inspektor arbeiten

Damit siehst du für jedes Element, welche Regeln greifen, und kannst Werte live ausprobieren.

1. In **Safari**: *Einstellungen → Erweitert → „Funktionen für Webentwickler anzeigen“* einschalten.
2. Im Safari-Menü **Entwickler → [Name deines Macs] → MD Viewer** die angezeigte Seite wählen.
3. Elemente anklicken, Werte ändern, ausprobieren. Was gefällt, übernimmst du in `theme.css`.

Änderungen im Inspektor sind nur vorübergehend. Dauerhaft ist nur, was in `theme.css` steht.

---

## Fehlersuche

**Meine Änderung wirkt nicht.**
- Steht die Regel noch zwischen `/*` und `*/`?
- Fehlt ein Semikolon `;` oder eine schließende Klammer `}`? Ein Fehler kann alles danach unwirksam machen.
- Variablen gehören in einen `:root { … }`-Block.
- Hilft nichts: `!important` anhängen, z. B. `color: red !important;`.

**Alles ist kaputt.**
*Einstellungen → Eigenes Theme → Zurücksetzen* stellt die Vorlage wieder her.

**Eine Schrift wird nicht verwendet.**
Den genauen Namen in der *Schriftsammlung* nachsehen. Namen mit Leerzeichen in Anführungszeichen setzen: `"Avenir Next"`.
