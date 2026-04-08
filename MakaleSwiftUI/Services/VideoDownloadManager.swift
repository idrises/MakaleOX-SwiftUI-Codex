import Combine
import CryptoKit
import Foundation

final class VideoDownloadManager: NSObject, ObservableObject {
    static let shared = VideoDownloadManager()

    @Published private(set) var records: [String: VideoDownloadRecord] = [:]
    @Published private(set) var activeProgress: [String: DownloadStatus] = [:]
    @Published private(set) var queuedIDs: Set<String> = []

    private let fileManager = FileManager.default
    private var activeTasksByDownloadID: [String: URLSessionDownloadTask] = [:]
    private var backgroundCompletionHandler: (() -> Void)?
    private var hasRestoredTasks = false

    private lazy var downloadsRootDirectory: URL = {
        let root = (try? LegacyConfig.applicationSupportDirectory()) ?? fileManager.temporaryDirectory
        let directory = root.appendingPathComponent("video-downloads", isDirectory: true)
        let filesDirectory = directory.appendingPathComponent("files", isDirectory: true)
        let resumeDirectory = directory.appendingPathComponent("resume", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
        return directory
    }()

    private lazy var filesDirectory: URL = {
        downloadsRootDirectory.appendingPathComponent("files", isDirectory: true)
    }()

    private lazy var resumeDirectory: URL = {
        downloadsRootDirectory.appendingPathComponent("resume", isDirectory: true)
    }()

    private lazy var metadataURL: URL = {
        downloadsRootDirectory.appendingPathComponent("records.json")
    }()

    private lazy var session: URLSession = {
        let configuration: URLSessionConfiguration
#if os(iOS)
        let identifier = "\(Bundle.main.bundleIdentifier ?? "com.codex.MakaleSwiftUI").video-downloads"
        configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
#else
        configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
#endif
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 6
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    override private init() {
        super.init()
        loadPersistedRecords()
        _ = session
        restorePendingTasksIfNeeded()
    }

    func restorePendingTasksIfNeeded() {
        guard !hasRestoredTasks else { return }
        hasRestoredTasks = true

        session.getAllTasks { [weak self] tasks in
            guard let self else { return }

            let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }
            var attachedIDs = Set<String>()

            for task in downloadTasks {
                guard let downloadID = self.downloadID(for: task) else { continue }
                attachedIDs.insert(downloadID)
                self.activeTasksByDownloadID[downloadID] = task
                self.queuedIDs.insert(downloadID)
            }

            self.resumeDetachedPendingDownloads(excluding: attachedIDs)
        }
    }

    func handleBackgroundEvents(identifier: String, completionHandler: @escaping () -> Void) {
#if os(iOS)
        guard session.configuration.identifier == identifier else {
            completionHandler()
            return
        }

        backgroundCompletionHandler = completionHandler
        restorePendingTasksIfNeeded()
#else
        completionHandler()
#endif
    }

    func downloadState(for item: VideoRailItem) -> VideoDownloadState {
        downloadState(forRemoteURL: item.remoteURL)
    }

    func downloadState(forRemoteURL remoteURL: URL) -> VideoDownloadState {
        let downloadID = remoteURL.absoluteString

        if let localURL = localFileURL(forDownloadID: downloadID) {
            return .downloaded(localURL)
        }

        if let progress = activeProgress[downloadID] {
            return .downloading(progress)
        }

        if activeTasksByDownloadID[downloadID] != nil || queuedIDs.contains(downloadID) {
            return .queued
        }

        if let error = records[downloadID]?.lastErrorMessage, !error.isEmpty {
            return .failed(error)
        }

        return .notDownloaded
    }

    func playbackURL(for remoteURL: URL) -> URL {
        localFileURL(forDownloadID: remoteURL.absoluteString) ?? remoteURL
    }

    func downloadedItems(kind: VideoSourceKind? = nil) -> [DownloadedVideoItem] {
        records.values
            .compactMap { record -> DownloadedVideoItem? in
                guard kind == nil || record.sourceKind == kind else { return nil }
                guard let localURL = localFileURL(for: record) else { return nil }
                return DownloadedVideoItem(record: record, localURL: localURL)
            }
            .sorted { lhs, rhs in
                (lhs.downloadedAt ?? .distantPast) > (rhs.downloadedAt ?? .distantPast)
            }
    }

    func startDownload(for item: VideoRailItem) {
        let downloadID = item.remoteURL.absoluteString

        if localFileURL(forDownloadID: downloadID) != nil {
            upsertRecord(VideoDownloadRecord(item: item))
            return
        }

        if activeTasksByDownloadID[downloadID] != nil {
            return
        }

        var record = records[downloadID] ?? VideoDownloadRecord(item: item)
        record.title = item.title
        record.subtitle = item.subtitle
        record.detail = item.detail
        record.remoteURLString = item.remoteURL.absoluteString
        record.artworkURLStrings = item.artworkURLs.map(\.absoluteString)
        record.sourceKind = item.sourceKind
        record.sourceName = item.sourceName
        record.sourceDetail = item.sourceDetail
        record.lastErrorMessage = nil
        upsertRecord(record)

        guard let remoteURL = record.remoteURL, !remoteURL.isFileURL else {
            updateRecord(downloadID: downloadID) { draft in
                draft.lastErrorMessage = "The video URL could not be resolved."
            }
            return
        }

        let task: URLSessionDownloadTask
        if let resumeData = loadResumeData(forDownloadID: downloadID) {
            task = session.downloadTask(withResumeData: resumeData)
            removeResumeData(forDownloadID: downloadID)
        } else {
            task = session.downloadTask(with: remoteURL)
        }

        task.taskDescription = downloadID
        activeTasksByDownloadID[downloadID] = task
        queuedIDs.insert(downloadID)
        activeProgress.removeValue(forKey: downloadID)
        persistRecords()
        task.resume()
    }

    private func upsertRecord(_ record: VideoDownloadRecord) {
        var normalized = record
        if let existing = records[record.id] {
            normalized.localRelativePath = normalized.localRelativePath ?? existing.localRelativePath
            normalized.downloadedAt = normalized.downloadedAt ?? existing.downloadedAt
        }
        records[record.id] = normalized
        persistRecords()
    }

    private func updateRecord(downloadID: String, _ mutate: (inout VideoDownloadRecord) -> Void) {
        guard var record = records[downloadID] else { return }
        mutate(&record)
        records[downloadID] = record
        persistRecords()
    }

    private func loadPersistedRecords() {
        guard let data = try? Data(contentsOf: metadataURL) else {
            records = [:]
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let decoded = try? decoder.decode([VideoDownloadRecord].self, from: data) else {
            records = [:]
            return
        }

        var loaded: [String: VideoDownloadRecord] = [:]
        for var record in decoded {
            if record.localRelativePath != nil, localFileURL(for: record) == nil {
                record.localRelativePath = nil
                record.downloadedAt = nil
            }
            loaded[record.id] = record
        }
        records = loaded
    }

    private func persistRecords() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let ordered = records.values.sorted { lhs, rhs in
            (lhs.downloadedAt ?? .distantPast) > (rhs.downloadedAt ?? .distantPast)
        }

        guard let data = try? encoder.encode(ordered) else { return }
        try? data.write(to: metadataURL, options: [.atomic])
    }

    private func resumeDetachedPendingDownloads(excluding attachedIDs: Set<String>) {
        let pendingRecords = records.values.filter { record in
            guard record.localRelativePath == nil else { return false }
            guard !attachedIDs.contains(record.id) else { return false }
            return true
        }

        for record in pendingRecords where activeTasksByDownloadID[record.id] == nil {
            if record.lastErrorMessage == nil || loadResumeData(forDownloadID: record.id) != nil {
                let item = VideoRailItem(
                    id: record.id,
                    title: record.title,
                    subtitle: record.subtitle,
                    detail: record.detail,
                    url: record.remoteURL ?? URL(fileURLWithPath: "/"),
                    remoteURL: record.remoteURL ?? URL(fileURLWithPath: "/"),
                    artworkURLs: record.artworkURLs,
                    sourceKind: record.sourceKind,
                    sourceName: record.sourceName,
                    sourceDetail: record.sourceDetail
                )
                startDownload(for: item)
            }
        }
    }

    private func downloadID(for task: URLSessionTask) -> String? {
        if let taskDescription = task.taskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        if let url = task.originalRequest?.url {
            return url.absoluteString
        }
        if let url = task.currentRequest?.url {
            return url.absoluteString
        }
        return nil
    }

    private func localFileURL(for record: VideoDownloadRecord) -> URL? {
        guard let relativePath = record.localRelativePath else { return nil }
        let candidate = downloadsRootDirectory.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private func localFileURL(forDownloadID downloadID: String) -> URL? {
        guard let record = records[downloadID] else { return nil }
        return localFileURL(for: record)
    }

    private func moveDownloadedFile(from location: URL, for record: VideoDownloadRecord, response: URLResponse?) throws -> URL {
        try fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)

        let pathExtension = preferredFileExtension(for: record, response: response)
        let filename = fileName(forDownloadID: record.id, pathExtension: pathExtension)
        let destinationURL = filesDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: location, to: destinationURL)
        return destinationURL
    }

    private func preferredFileExtension(for record: VideoDownloadRecord, response: URLResponse?) -> String {
        if let suggestedFilename = response?.suggestedFilename {
            let pathExtension = URL(fileURLWithPath: suggestedFilename).pathExtension
            if !pathExtension.isEmpty {
                return pathExtension
            }
        }

        if let pathExtension = record.remoteURL?.pathExtension, !pathExtension.isEmpty {
            return pathExtension
        }

        return "mp4"
    }

    private func fileName(forDownloadID downloadID: String, pathExtension: String) -> String {
        let digest = SHA256.hash(data: Data(downloadID.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex).\(pathExtension)"
    }

    private func relativePath(for localURL: URL) -> String {
        localURL.path.replacingOccurrences(of: downloadsRootDirectory.path + "/", with: "")
    }

    private func resumeDataURL(forDownloadID downloadID: String) -> URL {
        let digest = SHA256.hash(data: Data(downloadID.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return resumeDirectory.appendingPathComponent("\(hex).resume")
    }

    private func loadResumeData(forDownloadID downloadID: String) -> Data? {
        let url = resumeDataURL(forDownloadID: downloadID)
        return try? Data(contentsOf: url)
    }

    private func saveResumeData(_ data: Data, forDownloadID downloadID: String) {
        let url = resumeDataURL(forDownloadID: downloadID)
        try? data.write(to: url, options: [.atomic])
    }

    private func removeResumeData(forDownloadID downloadID: String) {
        let url = resumeDataURL(forDownloadID: downloadID)
        try? fileManager.removeItem(at: url)
    }
}

extension VideoDownloadManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let downloadID = downloadID(for: downloadTask) else { return }
        activeProgress[downloadID] = DownloadStatus(
            downloadedBytes: totalBytesWritten,
            expectedBytes: totalBytesExpectedToWrite
        )
        queuedIDs.insert(downloadID)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let downloadID = downloadID(for: downloadTask),
              let record = records[downloadID]
        else { return }

        do {
            let finalURL = try moveDownloadedFile(from: location, for: record, response: downloadTask.response)
            activeTasksByDownloadID.removeValue(forKey: downloadID)
            activeProgress.removeValue(forKey: downloadID)
            queuedIDs.remove(downloadID)
            removeResumeData(forDownloadID: downloadID)
            updateRecord(downloadID: downloadID) { draft in
                draft.localRelativePath = relativePath(for: finalURL)
                draft.downloadedAt = Date()
                draft.lastErrorMessage = nil
            }
        } catch {
            activeTasksByDownloadID.removeValue(forKey: downloadID)
            activeProgress.removeValue(forKey: downloadID)
            queuedIDs.remove(downloadID)
            updateRecord(downloadID: downloadID) { draft in
                draft.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadID = downloadID(for: task) else { return }
        guard let error else { return }

        activeTasksByDownloadID.removeValue(forKey: downloadID)
        activeProgress.removeValue(forKey: downloadID)
        queuedIDs.remove(downloadID)

        let nsError = error as NSError
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            saveResumeData(resumeData, forDownloadID: downloadID)
        }

        updateRecord(downloadID: downloadID) { draft in
            if nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data != nil {
                draft.lastErrorMessage = nil
            } else {
                draft.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}
