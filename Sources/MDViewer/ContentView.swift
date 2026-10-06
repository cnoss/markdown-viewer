import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state
    @AppStorage(PrefKey.fontSize) private var fontSize = 17.0
    @AppStorage(PrefKey.fontStyle) private var fontStyle = "sans"
    @AppStorage(PrefKey.editorPath) private var editorPath = ""
    @AppStorage(PrefKey.appearance) private var appearance = "system"
    @AppStorage(PrefKey.contentWidth) private var contentWidth = "narrow"

    var body: some View {
        NavigationSplitView {
            BrowserView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 310, max: 520)
        } detail: {
            if let file = state.openFile {
                MarkdownWebView(file: file, fontSize: fontSize, fontStyle: fontStyle, contentWidth: contentWidth)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "Keine Datei geöffnet",
                    systemImage: "doc.text",
                    description: Text("Wähle links eine Datei aus oder zieh eine hierher.")
                )
            }
        }
        .navigationTitle(state.openFile?.lastPathComponent ?? "MD Viewer")
        .navigationSubtitle(state.openFile?.deletingLastPathComponent().abbreviatedPath ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Inhaltsbreite", selection: $contentWidth) {
                        ForEach(ContentWidth.all, id: \.self) { Text(ContentWidth.label($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Inhaltsbreite", systemImage: contentWidth == "full"
                          ? "arrow.left.and.right.square.fill" : "arrow.left.and.right.square")
                } primaryAction: {
                    contentWidth = ContentWidth.next(after: contentWidth)
                }
                .help("Inhaltsbreite: \(ContentWidth.label(contentWidth)) – Klick wechselt (⌘\\)")

                Button { state.exportPDF() } label: {
                    if state.exportingPDF != nil {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("PDF", systemImage: "doc.richtext")
                    }
                }
                .help("Als PDF drucken mit mdprint (⌘P)")
                .disabled(state.openFile == nil || state.exportingPDF != nil)

                Button { state.revealInFinder() } label: {
                    Label("Im Finder zeigen", systemImage: "folder")
                }
                .help("Im Finder zeigen (⇧⌘R)")
                .disabled(state.openFile == nil)

                Button { state.openInEditor() } label: {
                    Label("Im Editor öffnen", systemImage: "square.and.pencil")
                }
                .help("In \(editorName) öffnen (⌘E)")
                .disabled(state.openFile == nil)
            }
        }
        .onChange(of: appearance, initial: true) { _, value in
            Appearance.apply(value)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            state.open(url)
            return true
        }
    }

    private var editorName: String {
        _ = editorPath // neu berechnen, wenn sich die Einstellung ändert
        return ExternalEditor.current.map(ExternalEditor.displayName) ?? "Standard-App"
    }
}
