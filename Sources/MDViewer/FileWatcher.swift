import Foundation

/// Meldet Änderungen an einer Datei. Editoren speichern oft atomar
/// (neue Datei + Umbenennen), deshalb wird nach delete/rename neu angesetzt.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start(attempt: 0)
    }

    deinit {
        pending?.cancel()
        source?.cancel()
    }

    private func start(attempt: Int) {
        let fd = Darwin.open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            // Datei ist kurz weg (atomares Speichern) – ein paar Mal erneut versuchen.
            if attempt < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.start(attempt: attempt + 1)
                }
            }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self, unowned src] in
            guard let self else { return }
            if !src.data.isDisjoint(with: [.delete, .rename]) {
                src.cancel()
                self.source = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.start(attempt: 0)
                    self?.notify()
                }
            } else {
                self.notify()
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    /// Mehrere Schreibvorgänge kurz hintereinander zu einem Neuladen zusammenfassen.
    private func notify() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: item)
    }
}
