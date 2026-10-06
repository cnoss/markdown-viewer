import Foundation

struct Entry: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let modified: Date?
    /// Ordnerpfad relativ zum aktuellen Verzeichnis (nur bei Suchtreffern in Unterordnern).
    var subpath: String?

    var id: URL { url }
}

enum FileListing {
    private static let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey]
    private static let skippedFolders: Set<String> = ["node_modules", "Library", "DerivedData", "Pods", "vendor"]

    /// Ordner und Markdown-Dateien im Verzeichnis, Ordner zuerst.
    static func list(_ dir: URL) -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let entries = urls.compactMap { url -> Entry? in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let isDir = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
            guard isDir || url.isMarkdown else { return nil }
            return Entry(url: url, name: url.lastPathComponent, isDirectory: isDir,
                         modified: values?.contentModificationDate)
        }
        return entries.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Markdown-Dateien in allen Unterordnern, deren Pfad alle Suchwörter enthält.
    static func search(_ dir: URL, query: String, limit: Int = 400) async -> [Entry] {
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty,
              let enumerator = FileManager.default.enumerator(
                at: dir, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }

        let basePath = dir.standardizedFileURL.path
        var results: [Entry] = []
        var visited = 0

        while let url = enumerator.nextObject() as? URL {
            visited += 1
            if visited % 500 == 0, Task.isCancelled { return [] }
            if visited > 200_000 || results.count >= limit { break }

            if skippedFolders.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard url.isMarkdown else { continue }

            let rel = String(url.standardizedFileURL.path.dropFirst(basePath.count + 1))
            let haystack = rel.lowercased()
            guard terms.allSatisfy(haystack.contains) else { continue }

            let folder = (rel as NSString).deletingLastPathComponent
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            results.append(Entry(url: url, name: url.lastPathComponent, isDirectory: false,
                                 modified: modified, subpath: folder.isEmpty ? nil : folder))
        }
        // Treffer im Dateinamen vor Treffern nur im Pfad, dann neueste zuerst.
        return results.sorted { a, b in
            let an = terms.allSatisfy(a.name.lowercased().contains)
            let bn = terms.allSatisfy(b.name.lowercased().contains)
            if an != bn { return an }
            return (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
        }
    }
}
