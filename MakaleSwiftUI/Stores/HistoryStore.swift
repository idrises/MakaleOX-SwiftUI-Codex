import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry]

    private let storageKey = "MakaleSwiftUI.history"

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else {
            self.entries = []
            return
        }

        self.entries = entries.sorted { $0.openedAt > $1.openedAt }
    }

    func add(_ entry: HistoryEntry) {
        entries.removeAll { $0.title == entry.title && $0.urlString == entry.urlString }
        entries.insert(entry, at: 0)
        if entries.count > 200 {
            entries = Array(entries.prefix(200))
        }
        persist()
    }

    func replace(with entries: [HistoryEntry]) {
        replace(with: entries, for: nil)
    }

    func replace(with entries: [HistoryEntry], for kind: HistoryKind?) {
        var seenKeys = Set<String>()

        let baseEntries: [HistoryEntry]
        if let kind {
            baseEntries = self.entries.filter { $0.kind != kind } + entries
        } else {
            baseEntries = entries
        }

        self.entries = baseEntries
            .sorted { $0.openedAt > $1.openedAt }
            .filter { entry in
                let key = [entry.kind.title, entry.title, entry.subtitle, entry.urlString].joined(separator: "|")
                if seenKeys.contains(key) {
                    return false
                }
                seenKeys.insert(key)
                return true
            }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    func update(_ entry: HistoryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        entries.sort { $0.openedAt > $1.openedAt }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
