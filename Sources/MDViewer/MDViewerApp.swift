import SwiftUI

@main
struct MDViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared
    @AppStorage(PrefKey.fontSize) private var fontSize = 17.0
    @AppStorage(PrefKey.contentWidth) private var contentWidth = "narrow"

    var body: some Scene {
        Window("MD Viewer", id: "main") {
            ContentView()
                .environment(state)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Öffnen …") { state.showOpenPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Im Editor öffnen") { state.openInEditor() }
                    .keyboardShortcut("e")
                    .disabled(state.openFile == nil)
                Button("Im Finder zeigen") { state.revealInFinder() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(state.openFile == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button("Als PDF drucken") { state.exportPDF() }
                    .keyboardShortcut("p")
                    .disabled(state.openFile == nil || state.exportingPDF != nil)
            }
            CommandGroup(before: .toolbar) {
                Button("Größer") { fontSize = min(fontSize + 1, 26) }
                    .keyboardShortcut("+")
                Button("Kleiner") { fontSize = max(fontSize - 1, 12) }
                    .keyboardShortcut("-")
                Button("Originalgröße") { fontSize = 17 }
                    .keyboardShortcut("0")
                Button("Inhaltsbreite wechseln") { contentWidth = ContentWidth.next(after: contentWidth) }
                    .keyboardShortcut("\\")
                Divider()
            }
            CommandGroup(replacing: .help) {
                Button("MD Viewer Hilfe") { CustomTheme.showHelp() }
                    .keyboardShortcut("?")
            }
            CommandMenu("Gehe zu") {
                Button("Filtern / Pfad eingeben") { state.focusConsole() }
                    .keyboardShortcut("k")
                Button("Übergeordneter Ordner") { state.goToParent() }
                    .keyboardShortcut(.upArrow)
                Divider()
                ForEach(Place.all) { place in
                    Button(place.name) { state.navigate(to: place.url) }
                        .keyboardShortcut(place.shortcut, modifiers: place.modifiers)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        MainActor.assumeIsolated { AppState.shared.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
