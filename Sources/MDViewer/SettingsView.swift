import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(PrefKey.editorPath) private var editorPath = ""
    @AppStorage(PrefKey.fontStyle) private var fontStyle = "sans"
    @AppStorage(PrefKey.fontSize) private var fontSize = 17.0
    @AppStorage(PrefKey.appearance) private var appearance = "system"
    @AppStorage(PrefKey.contentWidth) private var contentWidth = "narrow"
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Picker("Editor", selection: editorSelection) {
                    ForEach(editorChoices, id: \.path) { app in
                        Label {
                            Text(ExternalEditor.displayName(app))
                        } icon: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        }
                        .tag(app.path)
                    }
                }
                Button("Andere App wählen …", action: chooseApp)
            } footer: {
                Text("⌘E, Enter oder Doppelklick öffnet die Datei dort. Gespeicherte Änderungen erscheinen sofort im Viewer.")
                    .foregroundStyle(.secondary)
            }

            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Hell").tag("light")
                    Text("Dunkel").tag("dark")
                }
                .pickerStyle(.segmented)
                Picker("Schrift", selection: $fontStyle) {
                    Text("Sans (SF Pro)").tag("sans")
                    Text("Serif (New York)").tag("serif")
                }
                .pickerStyle(.segmented)
                Picker("Inhaltsbreite", selection: $contentWidth) {
                    Text("Schmal").tag("narrow")
                    Text("Mittel").tag("medium")
                    Text("Voll").tag("full")
                }
                .pickerStyle(.segmented)
                LabeledContent("Größe") {
                    HStack {
                        Slider(value: $fontSize, in: 13...24, step: 1)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section {
                HStack {
                    Button("Theme bearbeiten …") { CustomTheme.edit() }
                    Button("Im Finder zeigen") { CustomTheme.reveal() }
                    Spacer()
                    Button("Zurücksetzen", role: .destructive) { confirmReset = true }
                    Button { CustomTheme.showHelp() } label: {
                        Image(systemName: "questionmark")
                    }
                    .buttonStyle(.bordered)
                    .clipShape(Circle())
                    .help("Anleitung: Variablen, Selektoren und Rezepte")
                }
            } header: {
                Text("Eigenes Theme")
            } footer: {
                Text("Eine CSS-Datei, die nach dem Standard-Layout geladen wird. Farben, Schriften und Breiten lassen sich dort überschreiben – Änderungen erscheinen beim Speichern sofort.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Theme auf die Vorlage zurücksetzen?", isPresented: $confirmReset) {
            Button("Zurücksetzen", role: .destructive) { CustomTheme.reset() }
        } message: {
            Text("Deine Anpassungen in theme.css gehen dabei verloren.")
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var editorChoices: [URL] {
        var apps = ExternalEditor.installed
        if let current = ExternalEditor.current, !apps.contains(current) {
            apps.append(current)
        }
        return apps
    }

    private var editorSelection: Binding<String> {
        Binding(
            get: { ExternalEditor.current?.path ?? "" },
            set: { editorPath = $0 }
        )
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            editorPath = url.path
        }
    }
}
