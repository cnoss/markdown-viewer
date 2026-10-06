import SwiftUI

/// Die „Konsole“: Pfadzeile, Eingabezeile und Liste der Ordner und Markdown-Dateien.
struct BrowserView: View {
    @Environment(AppState.self) private var state
    @AppStorage("recursiveSearch") private var recursive = true

    @State private var query = ""
    @State private var entries: [Entry] = []
    @State private var highlighted: URL?
    @State private var searching = false
    @State private var refreshToken = 0
    @State private var dirWatcher: FileWatcher?

    private struct LoadKey: Equatable {
        let dir: URL, query: String, recursive: Bool, refresh: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            consoleLine
            Divider().padding(.top, 8)
            list
            Divider()
            footer
        }
        .task(id: LoadKey(dir: state.directory, query: query, recursive: recursive, refresh: refreshToken)) {
            await load()
        }
        .onChange(of: state.directory, initial: true) { _, dir in
            dirWatcher = FileWatcher(url: dir) { refreshToken += 1 }
        }
        .onChange(of: highlighted) { _, url in
            if let url, !FileManager.default.isDirectory(url) { state.openFile = url }
        }
    }

    // MARK: Teile

    private var header: some View {
        HStack(spacing: 6) {
            Button { state.goToParent() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Übergeordneter Ordner (← oder ⌘↑)")
            .disabled(state.directory.path == "/")

            Text(state.directory.abbreviatedPath)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .help(state.directory.path)

            Spacer(minLength: 4)

            Menu {
                ForEach(Place.all) { place in
                    Button(place.name) { state.navigate(to: place.url) }
                }
                Divider()
                Button("Ordner wählen …") { state.showOpenPanel() }
            } label: {
                Image(systemName: "folder")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Orte")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var consoleLine: some View {
        HStack(spacing: 6) {
            Text("›")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tint)
            ConsoleField(text: $query,
                         placeholder: "Filtern, ~/pfad oder ..",
                         focusToken: state.consoleFocusToken,
                         onKey: handle)
            if searching {
                ProgressView().controlSize(.small)
            }
            if !query.isEmpty && !isPathInput {
                Button { recursive.toggle() } label: {
                    Image(systemName: recursive ? "square.stack.3d.down.right.fill" : "square.stack.3d.down.right")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(recursive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .help(recursive ? "Sucht auch in Unterordnern" : "Sucht nur in diesem Ordner")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.055)))
        .padding(.horizontal, 10)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(entries) { entry in
                        EntryRow(entry: entry, highlighted: entry.url == highlighted)
                            .id(entry.url)
                            .onTapGesture(count: 2) { activate(entry) }
                            .simultaneousGesture(TapGesture().onEnded { highlighted = entry.url })
                            .contextMenu { contextMenu(for: entry) }
                    }
                }
                .padding(6)
            }
            .overlay {
                if entries.isEmpty && !searching {
                    Text(query.isEmpty ? "Keine Markdown-Dateien hier" : "Nichts gefunden")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .onChange(of: highlighted) { _, url in
                if let url { proxy.scrollTo(url) }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(countText)
            Spacer()
            Text("← zurück  → rein  ↵ öffnen")
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func contextMenu(for entry: Entry) -> some View {
        if !entry.isDirectory {
            Button("Im Editor öffnen") { state.openInEditor(entry.url) }
        }
        Button("Im Finder zeigen") { state.revealInFinder(entry.url) }
        Button("Pfad kopieren") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.url.path, forType: .string)
        }
    }

    private var countText: String {
        let files = entries.filter { !$0.isDirectory }.count
        let dirs = entries.count - files
        var parts = ["\(files) \(files == 1 ? "Datei" : "Dateien")"]
        if dirs > 0 { parts.append("\(dirs) \(dirs == 1 ? "Ordner" : "Ordner")") }
        return parts.joined(separator: " · ")
    }

    // MARK: Pfadeingabe

    private var isPathInput: Bool {
        query.hasPrefix("/") || query.hasPrefix("~") || query.hasPrefix("..")
    }

    /// Wandelt die Eingabe in (Ordner, Namensanfang) um, z. B. "~/Doc" → (~, "Doc").
    private func resolvePathInput() -> (dir: URL, prefix: String) {
        var path = (query as NSString).expandingTildeInPath
        if !path.hasPrefix("/") { path = state.directory.appending(path: path).path }
        if query.hasSuffix("/") || query == ".." || query == "~" {
            return (URL(fileURLWithPath: path).standardizedFileURL, "")
        }
        let url = URL(fileURLWithPath: path)
        return (url.deletingLastPathComponent().standardizedFileURL, url.lastPathComponent)
    }

    // MARK: Laden

    private func load() async {
        let dir = state.directory
        if isPathInput {
            let (target, prefix) = resolvePathInput()
            entries = FileListing.list(target).filter {
                prefix.isEmpty || $0.name.lowercased().hasPrefix(prefix.lowercased())
            }
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            entries = FileListing.list(dir)
        } else if recursive {
            searching = true
            defer { searching = false }
            try? await Task.sleep(for: .milliseconds(140))
            if Task.isCancelled { return }
            let results = await FileListing.search(dir, query: query)
            if Task.isCancelled { return }
            entries = results
        } else {
            let terms = query.lowercased().split(separator: " ").map(String.init)
            entries = FileListing.list(dir).filter { e in terms.allSatisfy(e.name.lowercased().contains) }
        }
        updateHighlight()
    }

    private func updateHighlight() {
        let ids = Set(entries.map(\.url))
        if let pending = state.pendingHighlight, ids.contains(pending) {
            highlighted = pending
            state.pendingHighlight = nil
        } else if let current = highlighted, ids.contains(current) {
            return
        } else if let open = state.openFile, ids.contains(open), query.isEmpty {
            highlighted = open
        } else {
            highlighted = entries.first(where: { !$0.isDirectory })?.url ?? entries.first?.url
        }
    }

    // MARK: Tastatur

    private func handle(_ key: ConsoleField.Key) {
        switch key {
        case .up: moveHighlight(by: -1)
        case .down: moveHighlight(by: 1)
        case .escape: query = ""
        case .backspaceOnEmpty, .parent, .leftOnEmpty: state.goToParent()
        case .rightOnEmpty:
            if let entry = currentEntry, entry.isDirectory { activate(entry) }
        case .enter:
            if let entry = currentEntry {
                activate(entry)
            } else if isPathInput {
                let (dir, prefix) = resolvePathInput()
                let target = dir.appending(path: prefix)
                if FileManager.default.fileExists(atPath: target.path) {
                    query = ""
                    state.open(target)
                }
            }
        case .tab:
            guard let entry = currentEntry else { return }
            if isPathInput {
                // Vervollständigen wie in der Shell.
                query = entry.url.abbreviatedPath + (entry.isDirectory ? "/" : "")
            } else if entry.isDirectory {
                activate(entry)
            }
        }
    }

    private var currentEntry: Entry? {
        entries.first { $0.url == highlighted }
    }

    private func moveHighlight(by delta: Int) {
        guard !entries.isEmpty else { return }
        let index = entries.firstIndex { $0.url == highlighted } ?? (delta > 0 ? -1 : entries.count)
        let next = min(max(index + delta, 0), entries.count - 1)
        highlighted = entries[next].url
    }

    /// Enter oder Doppelklick: Ordner betreten, Datei im Editor öffnen.
    private func activate(_ entry: Entry) {
        if entry.isDirectory {
            query = ""
            state.navigate(to: entry.url)
        } else {
            state.openInEditor(entry.url)
        }
    }
}

private struct EntryRow: View {
    let entry: Entry
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(entry.isDirectory ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let sub = entry.subpath {
                    Text(sub)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer(minLength: 6)

            if !entry.isDirectory, let date = entry.modified {
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(highlighted ? Color.accentColor.opacity(0.2) : .clear)
        )
        .contentShape(Rectangle())
    }
}
