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

        self.entries = Self.sortedEntries(entries)
    }

    func add(_ entry: HistoryEntry) {
        entries.removeAll { $0.deduplicationKey == entry.deduplicationKey }
        entries.insert(entry, at: 0)
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
            .sorted(by: Self.historyEntrySort)
            .filter { entry in
                let key = entry.deduplicationKey
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
        entries.sort(by: Self.historyEntrySort)
        persist()
    }

    private static func sortedEntries(_ entries: [HistoryEntry]) -> [HistoryEntry] {
        entries.sorted(by: historyEntrySort)
    }

    private static func historyEntrySort(_ lhs: HistoryEntry, _ rhs: HistoryEntry) -> Bool {
        if lhs.openedAt != rhs.openedAt {
            return lhs.openedAt > rhs.openedAt
        }
        if lhs.urlString.isEmpty != rhs.urlString.isEmpty {
            return !lhs.urlString.isEmpty
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class OpenEventStore: ObservableObject {
    @Published private(set) var records: [OpenEventRecord]

    private let storageKey = "MakaleSwiftUI.open-events"
    private let sentGracePeriod: TimeInterval = 120
    private let sentRetention: TimeInterval = 24 * 60 * 60
    private let retryBaseDelay: TimeInterval = 10
    private let retryMaxDelay: TimeInterval = 120

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let records = try? JSONDecoder().decode([OpenEventRecord].self, from: data)
        else {
            self.records = []
            return
        }

        self.records = records
        resetInterruptedSyncs()
        pruneSentRecords()
    }

    func enqueue(_ record: OpenEventRecord) {
        records.append(record)
        sortAndPersist()
    }

    func beginSync(id: UUID) -> OpenEventRecord? {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return nil }
        records[index].status = .syncing
        records[index].retryCount += 1
        records[index].lastAttemptAt = Date()
        records[index].lastError = nil
        persist()
        return records[index]
    }

    func markSent(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = .sent
        records[index].syncedAt = Date()
        records[index].lastError = nil
        pruneSentRecords()
        persist()
    }

    func markFailed(id: UUID, errorDescription: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = .failed
        records[index].lastError = errorDescription
        persist()
    }

    func nextSyncCandidate(for email: String) -> OpenEventRecord? {
        let now = Date()
        return records
            .filter { record in
                guard let payload = record.articlePayload else { return false }
                guard payload.email == email else { return false }
                switch record.status {
                case .pending:
                    return true
                case .failed:
                    let lastAttemptAt = record.lastAttemptAt ?? .distantPast
                    return now.timeIntervalSince(lastAttemptAt) >= retryDelay(for: record)
                case .syncing, .sent:
                    return false
                }
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .first
    }

    func historyEntriesForMerge(email: String, kind: HistoryKind?) -> [HistoryEntry] {
        let now = Date()
        return records
            .filter { record in
                guard record.shouldMergeIntoHistory(now: now, sentGracePeriod: sentGracePeriod) else { return false }
                guard let payload = record.articlePayload else { return false }
                guard payload.email == email else { return false }
                return kind == nil || kind == .article
            }
            .map(\.historyEntry)
            .sorted { $0.openedAt > $1.openedAt }
    }

    func clear() {
        records = []
        persist()
    }

    private func pruneSentRecords() {
        let now = Date()
        records.removeAll { record in
            guard record.status == .sent, let syncedAt = record.syncedAt else { return false }
            return now.timeIntervalSince(syncedAt) > sentRetention
        }
    }

    private func resetInterruptedSyncs() {
        for index in records.indices where records[index].status == .syncing {
            records[index].status = .pending
        }
    }

    private func retryDelay(for record: OpenEventRecord) -> TimeInterval {
        let retryExponent = max(0, min(record.retryCount - 1, 4))
        return min(retryBaseDelay * pow(2, Double(retryExponent)), retryMaxDelay)
    }

    private func sortAndPersist() {
        records.sort { $0.createdAt > $1.createdAt }
        pruneSentRecords()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
