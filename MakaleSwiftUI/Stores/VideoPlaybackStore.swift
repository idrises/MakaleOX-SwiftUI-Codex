import Foundation

struct VideoPlaybackRecord: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var lastPositionSeconds: Double
    var watchedSeconds: Double
    var durationSeconds: Double?
    var lastWatchedAt: Date
    var isCompleted: Bool

    var progressFraction: Double? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return min(max(lastPositionSeconds / durationSeconds, 0), 1)
    }
}

@MainActor
final class VideoPlaybackStore: ObservableObject {
    static let shared = VideoPlaybackStore()

    @Published private(set) var records: [String: VideoPlaybackRecord]

    private let storageKey = "MakaleSwiftUI.videoPlaybackProgress"
    private let resumeThresholdSeconds = 8.0
    private let completionThresholdSeconds = 3.0

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let records = try? JSONDecoder().decode([String: VideoPlaybackRecord].self, from: data)
        else {
            self.records = [:]
            return
        }

        self.records = records
    }

    func record(forRemoteURL remoteURL: URL) -> VideoPlaybackRecord? {
        records[remoteURL.absoluteString]
    }

    func resumeTime(forRemoteURL remoteURL: URL) -> Double? {
        guard let record = records[remoteURL.absoluteString] else { return nil }
        guard !record.isCompleted else { return nil }

        let lastPosition = max(record.lastPositionSeconds, 0)
        guard lastPosition >= resumeThresholdSeconds else { return nil }

        if let durationSeconds = record.durationSeconds,
           durationSeconds > 0,
           lastPosition >= durationSeconds - completionThresholdSeconds {
            return nil
        }

        return lastPosition
    }

    func saveProgress(
        for item: VideoRailItem,
        positionSeconds: Double,
        durationSeconds: Double?,
        watchedIncrement: Double
    ) {
        let key = item.remoteURL.absoluteString
        let boundedPosition = max(positionSeconds, 0)
        let normalizedDuration = normalized(durationSeconds)

        var record = records[key] ?? VideoPlaybackRecord(
            id: key,
            title: item.title,
            lastPositionSeconds: 0,
            watchedSeconds: 0,
            durationSeconds: normalizedDuration,
            lastWatchedAt: Date(),
            isCompleted: false
        )

        record.title = item.title
        record.durationSeconds = normalizedDuration ?? record.durationSeconds
        record.watchedSeconds += max(watchedIncrement, 0)
        record.lastWatchedAt = Date()

        if shouldMarkCompleted(positionSeconds: boundedPosition, durationSeconds: record.durationSeconds) {
            record.lastPositionSeconds = 0
            record.isCompleted = true
        } else {
            record.lastPositionSeconds = boundedPosition
            record.isCompleted = false
        }

        records[key] = record
        persist()
    }

    func markCompleted(for item: VideoRailItem, durationSeconds: Double?) {
        let key = item.remoteURL.absoluteString
        let normalizedDuration = normalized(durationSeconds)

        var record = records[key] ?? VideoPlaybackRecord(
            id: key,
            title: item.title,
            lastPositionSeconds: 0,
            watchedSeconds: 0,
            durationSeconds: normalizedDuration,
            lastWatchedAt: Date(),
            isCompleted: true
        )

        record.title = item.title
        record.durationSeconds = normalizedDuration ?? record.durationSeconds
        record.lastPositionSeconds = 0
        record.isCompleted = true
        record.lastWatchedAt = Date()

        if let normalizedDuration {
            record.watchedSeconds = max(record.watchedSeconds, normalizedDuration)
        }

        records[key] = record
        persist()
    }

    private func shouldMarkCompleted(positionSeconds: Double, durationSeconds: Double?) -> Bool {
        guard let durationSeconds, durationSeconds > 0 else { return false }
        return positionSeconds >= durationSeconds - completionThresholdSeconds
    }

    private func normalized(_ durationSeconds: Double?) -> Double? {
        guard let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        return durationSeconds
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
