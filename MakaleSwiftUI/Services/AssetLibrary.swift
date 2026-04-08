import Foundation

struct DownloadStatus: Equatable {
    let downloadedBytes: Int64
    let expectedBytes: Int64

    var fractionCompleted: Double? {
        guard expectedBytes > 0 else { return nil }
        return min(max(Double(downloadedBytes) / Double(expectedBytes), 0), 1)
    }

    var detailText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file

        let downloaded = formatter.string(fromByteCount: downloadedBytes)
        guard expectedBytes > 0 else {
            return "\(downloaded) downloaded"
        }

        let expected = formatter.string(fromByteCount: expectedBytes)
        let percent = Int(((fractionCompleted ?? 0) * 100).rounded())
        return "\(percent)% • \(downloaded) / \(expected)"
    }
}

final class AssetLibrary {
    private let fileManager = FileManager.default

    private lazy var baseDirectory: URL = {
        do {
            return try LegacyConfig.applicationSupportDirectory()
        } catch {
#if os(macOS)
            return fileManager.homeDirectoryForCurrentUser.appendingPathComponent("MakaleSwiftUIData", isDirectory: true)
#else
            let fallbackBase =
                fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
                fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ??
                fileManager.temporaryDirectory
            return fallbackBase.appendingPathComponent("MakaleSwiftUIData", isDirectory: true)
#endif
        }
    }()

    func articleURL(
        for article: Article,
        onProgress: (@MainActor (DownloadStatus) -> Void)? = nil
    ) async throws -> URL {
        try await articleURL(
            journal: article.journalName,
            folder: article.folder,
            pdfLink: article.pdfLink,
            onProgress: onProgress
        )
    }

    func articleURL(
        journal: String,
        folder: String,
        pdfLink: String,
        onProgress: (@MainActor (DownloadStatus) -> Void)? = nil
    ) async throws -> URL {
        let directory = baseDirectory
            .appendingPathComponent("pdf", isDirectory: true)
            .appendingPathComponent("journals", isDirectory: true)
            .appendingPathComponent(safe(journal), isDirectory: true)
            .appendingPathComponent(safe(folder), isDirectory: true)
        let localURL = directory.appendingPathComponent("\(safe(pdfLink)).pdf")
        guard let remoteURL = LegacyConfig.articleRemoteURL(
            journal: journal,
            folder: folder,
            pdfLink: pdfLink
        ) else {
            throw URLError(.badURL)
        }
        return try await fetchIfNeeded(remoteURL: remoteURL, localURL: localURL, onProgress: onProgress)
    }

    func chapterURL(
        for chapter: Chapter,
        onProgress: (@MainActor (DownloadStatus) -> Void)? = nil
    ) async throws -> URL {
        try await chapterURL(isbn: chapter.isbn, pdfLink: chapter.pdfLink, onProgress: onProgress)
    }

    func chapterURL(
        isbn: String,
        pdfLink: String,
        onProgress: (@MainActor (DownloadStatus) -> Void)? = nil
    ) async throws -> URL {
        let directory = baseDirectory
            .appendingPathComponent("pdf", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(safe(isbn), isDirectory: true)
        let localURL = directory.appendingPathComponent("\(safe(pdfLink)).pdf")
        guard let remoteURL = LegacyConfig.chapterRemoteURL(isbn: isbn, pdfLink: pdfLink) else {
            throw URLError(.badURL)
        }
        return try await fetchIfNeeded(remoteURL: remoteURL, localURL: localURL, onProgress: onProgress)
    }

    private func fetchIfNeeded(
        remoteURL: URL,
        localURL: URL,
        onProgress: (@MainActor (DownloadStatus) -> Void)? = nil
    ) async throws -> URL {
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        try fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let download = DownloadSession(url: remoteURL, onProgress: onProgress)
        let (temporaryURL, _) = try await download.run()

        if fileManager.fileExists(atPath: localURL.path) {
            try? fileManager.removeItem(at: localURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: localURL)
        return localURL
    }

    private func safe(_ raw: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\\n\r\t")
        let sanitizedScalars = raw.unicodeScalars.map { scalar -> Character in
            invalidCharacters.contains(scalar) ? "-" : Character(scalar)
        }
        let sanitized = String(sanitizedScalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        return sanitized.isEmpty ? "untitled" : sanitized
    }
}

private final class DownloadSession: NSObject, URLSessionDownloadDelegate {
    private let url: URL
    private let onProgress: (@MainActor (DownloadStatus) -> Void)?

    private var session: URLSession?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var didResume = false

    init(url: URL, onProgress: (@MainActor (DownloadStatus) -> Void)?) {
        self.url = url
        self.onProgress = onProgress
    }

    func run() async throws -> (URL, URLResponse) {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 180

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let onProgress else { return }
        let status = DownloadStatus(
            downloadedBytes: totalBytesWritten,
            expectedBytes: totalBytesExpectedToWrite
        )

        Task { @MainActor in
            onProgress(status)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard !didResume else { return }
        guard let response = downloadTask.response else {
            finish(with: .failure(URLError(.badServerResponse)))
            return
        }

        do {
            let stagedURL = try stageDownloadedFile(from: location, response: response)
            finish(with: .success((stagedURL, response)))
        } catch {
            finish(with: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, !didResume else { return }
        finish(with: .failure(error))
    }

    private func finish(with result: Result<(URL, URLResponse), Error>) {
        guard !didResume else { return }
        didResume = true
        session?.finishTasksAndInvalidate()

        switch result {
        case .success(let value):
            continuation?.resume(returning: value)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }

        continuation = nil
    }

    private func stageDownloadedFile(from location: URL, response: URLResponse) throws -> URL {
        let fileManager = FileManager.default
        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MakaleSwiftUIDownloads", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        let suggestedName = response.suggestedFilename ?? url.lastPathComponent
        let fileExtension = URL(fileURLWithPath: suggestedName).pathExtension
        let stagedURL = stagingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension.isEmpty ? "tmp" : fileExtension)

        if fileManager.fileExists(atPath: stagedURL.path) {
            try? fileManager.removeItem(at: stagedURL)
        }

        try fileManager.moveItem(at: location, to: stagedURL)
        return stagedURL
    }
}
