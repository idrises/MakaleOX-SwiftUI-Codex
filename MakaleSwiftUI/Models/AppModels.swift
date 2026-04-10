import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct SessionInfo: Codable, Equatable {
    let email: String
    let userID: String
    let subject: String
    let expireDate: String
    let serial: String
    let firstName: String
    let lastName: String

    var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? email : fullName
    }

    var isExpired: Bool {
        guard !expireDate.isEmpty else { return false }
        return LegacyDate.todayStamp > expireDate
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case journals
    case books
    case videos
    case videoSets
    case search
    case history
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .journals: return "Journals"
        case .books: return "Books"
        case .videos: return "Videos"
        case .videoSets: return "Video Sets"
        case .search: return "Search"
        case .history: return "History"
        case .profile: return "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2.fill"
        case .journals: return "newspaper.fill"
        case .books: return "books.vertical.fill"
        case .videos: return "play.tv.fill"
        case .videoSets: return "square.stack.3d.up.fill"
        case .search: return "magnifyingglass"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

enum ProfileDetailSection: String, Equatable, Identifiable {
    case articleHistory
    case chapterHistory
    case videoHistory
    case videoSetHistory
    case favoriteJournals
    case favoriteBooks
    case favoriteVideoSets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .articleHistory:
            return "Article History"
        case .chapterHistory:
            return "Chapter History"
        case .videoHistory:
            return "Video History"
        case .videoSetHistory:
            return "Video Set History"
        case .favoriteJournals:
            return "Favorite Journals"
        case .favoriteBooks:
            return "Favorite Books"
        case .favoriteVideoSets:
            return "Favorite Video Sets"
        }
    }

    var subtitle: String {
        switch self {
        case .articleHistory:
            return "Recently opened articles are surfaced here without leaving the profile page."
        case .chapterHistory:
            return "Recently opened chapters are grouped here for quick return access."
        case .videoHistory:
            return "Recently watched videos stay visible here for fast replay."
        case .videoSetHistory:
            return "Recently watched set videos are grouped here for quick access."
        case .favoriteJournals:
            return "Pinned journals collected from your local favorites."
        case .favoriteBooks:
            return "Pinned books collected from your local favorites."
        case .favoriteVideoSets:
            return "Pinned video sets collected from your local favorites."
        }
    }
}

struct DashboardSnapshot {
    var journalCount: Int = 0
    var articleCount: Int = 0
    var bookCount: Int = 0
    var videoCount: Int = 0
    var videoSetCount: Int = 0
    var recentIssues: [JournalIssue] = []
    var recentBooks: [Book] = []
    var recentVideos: [Video] = []
    var recentVideoSets: [VideoSet] = []
}

struct Journal: Identifiable, Hashable {
    let id: String
    let name: String
    let issn: String
    let subject: String

    init(name: String, issn: String = "", subject: String = "") {
        self.name = name
        self.issn = issn
        self.subject = subject
        self.id = issn.isEmpty ? name : issn
    }

    init(row: SQLRow) {
        self.name = row.string("dergi")
        self.issn = row.string("ISSNELECTRONIC")
        self.subject = row.string("subject")
        self.id = issn.isEmpty ? name : issn
    }
}

struct JournalIssue: Identifiable, Hashable {
    let id: String
    let journalName: String
    let title: String
    let year: String
    let volume: String
    let number: String

    init(row: SQLRow) {
        self.journalName = row.string("dergi")
        self.title = row.string("DONEM")
        self.year = row.string("YIL")
        self.volume = row.string("VOLUME")
        self.number = row.string("SAYI", "IsNum")
        self.id = [journalName, title, year, volume, number].joined(separator: "|")
    }
}

struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let journalName: String
    let issueTitle: String
    let year: String
    let volume: String
    let folder: String
    let pdfLink: String
    let size: String
    let sortDate: Date?

    init(row: SQLRow) {
        self.title = row.string("MAKALE")
        self.author = row.string("YAZAR")
        self.journalName = row.string("dergi")
        self.issueTitle = row.string("DONEM")
        self.year = row.string("YIL")
        self.volume = row.string("VOLUME")
        self.folder = row.string("KLASOR")
        self.pdfLink = row.string("LINK")
        self.size = row.string("size")
        self.sortDate = row.date("createDate", "CreateDate") ?? LegacyDate.yearDate(from: year)
        self.id = [journalName, folder, pdfLink, title].joined(separator: "|")
    }
}

struct Book: Identifiable, Hashable {
    let id: String
    let title: String
    let editors: String
    let isbnOnline: String
    let isbnPrint: String
    let company: String
    let year: String
    let subject: String

    init(row: SQLRow) {
        self.title = row.string("name")
        self.editors = row.string("editors")
        self.isbnOnline = row.string("isbnOnline")
        self.isbnPrint = row.string("isbnPrint")
        self.company = row.string("company")
        self.year = row.string("year")
        self.subject = row.string("subject")
        self.id = isbnOnline.isEmpty ? title : isbnOnline
    }
}

struct Chapter: Identifiable, Hashable {
    let id: String
    let title: String
    let bookTitle: String
    let editors: String
    let year: String
    let isbn: String
    let pdfLink: String
    let size: String
    let sortDate: Date?

    init(row: SQLRow) {
        self.title = row.string("name")
        self.bookTitle = row.string("book")
        self.editors = row.string("editors")
        self.year = row.string("year")
        self.isbn = row.string("isbn")
        self.pdfLink = row.string("link")
        self.size = row.string("size")
        self.sortDate = row.date("createDate", "CreateDate") ?? LegacyDate.yearDate(from: year)
        self.id = [isbn, pdfLink, title].joined(separator: "|")
    }
}

struct Video: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let editor: String
    let bookJournal: String
    let isbn: String
    let imageLink: String
    let remoteLink: String
    let likes: String
    let sortDate: Date?

    init(row: SQLRow) {
        self.title = row.string("title")
        self.author = row.string("author")
        self.editor = row.string("editor")
        self.bookJournal = row.string("bookJournal")
        self.isbn = row.string("isbn")
        self.imageLink = row.string("imageLink")
        self.remoteLink = row.string("link2")
        self.likes = row.string("likes")
        self.sortDate = row.date("createDate", "CreateDate", "openedDate", "Date")
        self.id = [bookJournal, remoteLink, title].joined(separator: "|")
    }
}

struct VideoSet: Identifiable, Hashable {
    let id: String
    let setName: String
    let editors: String
    let subject: String
    let allowedUsers: String

    init(row: SQLRow) {
        self.setName = row.string("setName")
        self.editors = row.string("editors")
        self.subject = row.string("subject")
        self.allowedUsers = row.string("userID", "users")
        self.id = setName
    }

    func isAccessible(for userID: String) -> Bool {
        guard !allowedUsers.isEmpty else { return true }
        return allowedUsers
            .components(separatedBy: .whitespacesAndNewlines)
            .contains { $0 == userID }
    }
}

struct VideoSetEntry: Identifiable, Hashable {
    let id: String
    let setName: String
    let title: String
    let author: String
    let editor: String
    let remoteLink: String
    let imageLink: String
    let sortDate: Date?

    init(row: SQLRow) {
        self.setName = row.string("setName")
        self.title = row.string("title")
        self.author = row.string("author", "authors")
        self.editor = row.string("editor", "editors")
        self.remoteLink = row.string("link", "link2")
        self.imageLink = row.string("imageLink", "setName")
        self.sortDate = row.date("createDate", "CreateDate", "openedDate", "Date")
        self.id = [setName, remoteLink, title].joined(separator: "|")
    }
}

struct SearchResults {
    var articles: [Article] = []
    var chapters: [Chapter] = []
    var videos: [Video] = []
    var videoSetEntries: [VideoSetEntry] = []

    var isEmpty: Bool {
        articles.isEmpty && chapters.isEmpty && videos.isEmpty && videoSetEntries.isEmpty
    }
}

enum SearchVideoRailScope {
    case all
    case videos
    case videoSets
}

struct ProfileSummary {
    let fullName: String
    let email: String
    let userID: String
    let expireDate: String
    let serial: String
    let subject: String
    let articleCount: Int
    let chapterCount: Int
    let videoCount: Int
    let videoSetCount: Int
    let favoriteJournalCount: Int
    let favoriteBookCount: Int
    let favoriteVideoSetCount: Int
}

extension String {
    func normalizedSearchKey() -> String {
        let locale = Locale(identifier: "tr_TR")
        let replacements: [(String, String)] = [
            ("ç", "c"), ("Ç", "c"),
            ("ğ", "g"), ("Ğ", "g"),
            ("ı", "i"), ("İ", "i"), ("I", "i"),
            ("ö", "o"), ("Ö", "o"),
            ("ş", "s"), ("Ş", "s"),
            ("ü", "u"), ("Ü", "u")
        ]

        var value = folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: locale
        )

        for (source, target) in replacements {
            value = value.replacingOccurrences(of: source, with: target)
        }

        return value
            .lowercased(with: locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matchesNormalizedSearch(_ query: String) -> Bool {
        let normalizedQuery = query.normalizedSearchKey()
        guard !normalizedQuery.isEmpty else { return true }
        return normalizedSearchKey().contains(normalizedQuery)
    }

    func searchVariants(maxCount: Int = 16) -> [String] {
        let locale = Locale(identifier: "tr_TR")
        let source = trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: locale)
        guard !source.isEmpty else { return [] }

        let variantMap: [Character: [String]] = [
            "c": ["c", "ç"], "ç": ["ç", "c"],
            "g": ["g", "ğ"], "ğ": ["ğ", "g"],
            "i": ["i", "ı"], "ı": ["ı", "i"],
            "o": ["o", "ö"], "ö": ["ö", "o"],
            "s": ["s", "ş"], "ş": ["ş", "s"],
            "u": ["u", "ü"], "ü": ["ü", "u"]
        ]

        var variants = [""]

        for character in source {
            let options = variantMap[character] ?? [String(character)]
            var next: [String] = []

            for prefix in variants {
                for option in options {
                    let candidate = prefix + option
                    if !next.contains(candidate) {
                        next.append(candidate)
                    }
                    if next.count >= maxCount {
                        break
                    }
                }
                if next.count >= maxCount {
                    break
                }
            }

            variants = next
            if variants.isEmpty {
                break
            }
        }

        if let index = variants.firstIndex(of: source), index != 0 {
            variants.remove(at: index)
            variants.insert(source, at: 0)
        } else if !variants.contains(source) {
            variants.insert(source, at: 0)
        }

        return Array(variants.prefix(maxCount))
    }
}

enum HistoryKind: String, Codable, CaseIterable {
    case article
    case chapter
    case video
    case videoSet

    var title: String {
        switch self {
        case .article: return "Article"
        case .chapter: return "Chapter"
        case .video: return "Video"
        case .videoSet: return "Video Set"
        }
    }
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: HistoryKind
    let title: String
    let subtitle: String
    let detail: String
    let urlString: String
    let coverURLString: String
    let reference: HistoryReference?
    let openedAt: Date

    init(
        id: UUID = UUID(),
        kind: HistoryKind,
        title: String,
        subtitle: String,
        detail: String,
        urlString: String,
        coverURLString: String,
        reference: HistoryReference? = nil,
        openedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.urlString = urlString
        self.coverURLString = coverURLString
        self.reference = reference
        self.openedAt = openedAt
    }

    func updating(urlString: String? = nil, reference: HistoryReference? = nil) -> HistoryEntry {
        HistoryEntry(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            detail: detail,
            urlString: urlString ?? self.urlString,
            coverURLString: coverURLString,
            reference: reference ?? self.reference,
            openedAt: openedAt
        )
    }

    var deduplicationKey: String {
        if let reference {
            return [
                kind.rawValue,
                reference.primary,
                reference.secondary,
                reference.tertiary,
                title,
                subtitle
            ].joined(separator: "|")
        }

        return [kind.rawValue, title, subtitle, detail, urlString].joined(separator: "|")
    }
}

struct HistoryReference: Codable, Hashable {
    let kind: HistoryKind
    let primary: String
    let secondary: String
    let tertiary: String

    static func article(journal: String, folder: String, pdfLink: String) -> HistoryReference {
        HistoryReference(kind: .article, primary: journal, secondary: folder, tertiary: pdfLink)
    }

    static func chapter(isbn: String, pdfLink: String) -> HistoryReference {
        HistoryReference(kind: .chapter, primary: isbn, secondary: pdfLink, tertiary: "")
    }

    static func video(bookJournal: String, link: String) -> HistoryReference {
        HistoryReference(kind: .video, primary: bookJournal, secondary: link, tertiary: "")
    }

    static func videoSet(setName: String, link: String) -> HistoryReference {
        HistoryReference(kind: .videoSet, primary: setName, secondary: link, tertiary: "")
    }
}

enum OpenEventKind: String, Codable, Hashable {
    case article
}

enum OpenEventSyncStatus: String, Codable, Hashable {
    case pending
    case syncing
    case sent
    case failed
}

struct PendingArticleOpenPayload: Codable, Hashable {
    let email: String
    let author: String
    let title: String
    let journalName: String
    let issueTitle: String
    let year: String
    let volume: String
    let folder: String
    let pdfLink: String
    let platform: String

    init(article: Article, email: String) {
        self.email = email
        self.author = article.author
        self.title = article.title
        self.journalName = article.journalName
        self.issueTitle = article.issueTitle
        self.year = article.year
        self.volume = article.volume
        self.folder = article.folder
        self.pdfLink = article.pdfLink
        self.platform = Self.currentPlatform
    }

    private static var currentPlatform: String {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return "iPad SwiftUI"
        default:
            return "iPhone SwiftUI"
        }
        #elseif os(macOS)
        return "Mac SwiftUI"
        #else
        return "SwiftUI"
        #endif
    }
}

struct OpenEventRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: OpenEventKind
    let createdAt: Date
    let historyEntry: HistoryEntry
    let articlePayload: PendingArticleOpenPayload?
    var status: OpenEventSyncStatus
    var retryCount: Int
    var lastAttemptAt: Date?
    var syncedAt: Date?
    var lastError: String?

    static func article(
        payload: PendingArticleOpenPayload,
        historyEntry: HistoryEntry
    ) -> OpenEventRecord {
        OpenEventRecord(
            id: UUID(),
            kind: .article,
            createdAt: historyEntry.openedAt,
            historyEntry: historyEntry,
            articlePayload: payload,
            status: .pending,
            retryCount: 0,
            lastAttemptAt: nil,
            syncedAt: nil,
            lastError: nil
        )
    }

    func shouldMergeIntoHistory(now: Date = Date(), sentGracePeriod: TimeInterval = 120) -> Bool {
        switch status {
        case .pending, .syncing, .failed:
            return true
        case .sent:
            guard let syncedAt else { return false }
            return now.timeIntervalSince(syncedAt) <= sentGracePeriod
        }
    }
}

struct DocumentPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

enum VideoSourceKind: String, Codable, Equatable {
    case library
    case set

    var cardTitle: String {
        switch self {
        case .library:
            return "Book / Journal"
        case .set:
            return "Video Set"
        }
    }

    var systemImage: String {
        switch self {
        case .library:
            return "books.vertical"
        case .set:
            return "square.stack.3d.up"
        }
    }

    var summaryPrefix: String {
        switch self {
        case .library:
            return "Connected source"
        case .set:
            return "Connected set"
        }
    }
}

struct VideoRailItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let url: URL
    let remoteURL: URL
    let artworkURLs: [URL]
    let sourceKind: VideoSourceKind
    let sourceName: String
    let sourceDetail: String
}

struct VideoDownloadRecord: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var detail: String
    var remoteURLString: String
    var artworkURLStrings: [String]
    var sourceKind: VideoSourceKind
    var sourceName: String
    var sourceDetail: String
    var localRelativePath: String?
    var downloadedAt: Date?
    var lastErrorMessage: String?
    var requestedAt: Date?
    var lastKnownStatus: DownloadStatus?
    var isPaused: Bool

    var remoteURL: URL? {
        URL(string: remoteURLString)
    }

    var artworkURLs: [URL] {
        artworkURLStrings.compactMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case detail
        case remoteURLString
        case artworkURLStrings
        case sourceKind
        case sourceName
        case sourceDetail
        case localRelativePath
        case downloadedAt
        case lastErrorMessage
        case requestedAt
        case lastKnownStatus
        case isPaused
    }

    init(item: VideoRailItem) {
        self.id = item.remoteURL.absoluteString
        self.title = item.title
        self.subtitle = item.subtitle
        self.detail = item.detail
        self.remoteURLString = item.remoteURL.absoluteString
        self.artworkURLStrings = item.artworkURLs.map(\.absoluteString)
        self.sourceKind = item.sourceKind
        self.sourceName = item.sourceName
        self.sourceDetail = item.sourceDetail
        self.localRelativePath = nil
        self.downloadedAt = nil
        self.lastErrorMessage = nil
        self.requestedAt = Date()
        self.lastKnownStatus = nil
        self.isPaused = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        detail = try container.decode(String.self, forKey: .detail)
        remoteURLString = try container.decode(String.self, forKey: .remoteURLString)
        artworkURLStrings = try container.decode([String].self, forKey: .artworkURLStrings)
        sourceKind = try container.decode(VideoSourceKind.self, forKey: .sourceKind)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceDetail = try container.decode(String.self, forKey: .sourceDetail)
        localRelativePath = try container.decodeIfPresent(String.self, forKey: .localRelativePath)
        downloadedAt = try container.decodeIfPresent(Date.self, forKey: .downloadedAt)
        lastErrorMessage = try container.decodeIfPresent(String.self, forKey: .lastErrorMessage)
        requestedAt = try container.decodeIfPresent(Date.self, forKey: .requestedAt)
        lastKnownStatus = try container.decodeIfPresent(DownloadStatus.self, forKey: .lastKnownStatus)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
    }
}

struct DownloadedVideoItem: Identifiable, Equatable {
    let record: VideoDownloadRecord
    let localURL: URL

    var id: String { record.id }

    var railItem: VideoRailItem {
        VideoRailItem(
            id: record.id,
            title: record.title,
            subtitle: record.subtitle,
            detail: record.detail,
            url: localURL,
            remoteURL: record.remoteURL ?? localURL,
            artworkURLs: record.artworkURLs,
            sourceKind: record.sourceKind,
            sourceName: record.sourceName,
            sourceDetail: record.sourceDetail
        )
    }

    var downloadedAt: Date? { record.downloadedAt }
}

struct DownloadShelfItem: Identifiable, Equatable {
    let record: VideoDownloadRecord
    let state: VideoDownloadState
    let localURL: URL?

    var id: String { record.id }

    var downloadedItem: DownloadedVideoItem? {
        guard let localURL else { return nil }
        return DownloadedVideoItem(record: record, localURL: localURL)
    }

    var isPlayable: Bool {
        downloadedItem != nil
    }

    var downloadStatus: DownloadStatus? {
        switch state {
        case .queued(let status), .paused(let status):
            return status
        case .downloading(let status):
            return status
        case .downloaded, .failed, .notDownloaded:
            return nil
        }
    }

    var statusTitle: String {
        switch state {
        case .downloaded(_):
            return "Offline"
        case .queued(_):
            return "Queued"
        case .downloading(_):
            return "Downloading"
        case .paused(_):
            return "Paused"
        case .failed(_):
            return "Failed"
        case .notDownloaded:
            return "Not downloaded"
        }
    }

    var sourceDescriptor: String {
        let prefix = record.sourceKind == .set ? "Video Set" : "Library Video"
        return "\(prefix) • \(statusTitle)"
    }
}

enum VideoDownloadState: Equatable {
    case notDownloaded
    case queued(DownloadStatus?)
    case downloading(DownloadStatus)
    case paused(DownloadStatus?)
    case downloaded(URL)
    case failed(String)
}

struct VideoPresentation: Identifiable, Equatable {
    let id = UUID()
    let currentItem: VideoRailItem
    let railTitle: String
    let railSubtitle: String
    let railItems: [VideoRailItem]

    var title: String { currentItem.title }
    var url: URL { currentItem.url }
    var sourceKind: VideoSourceKind { currentItem.sourceKind }
    var sourceName: String { currentItem.sourceName }
    var sourceDetail: String { currentItem.sourceDetail }
}

struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

typealias SQLRow = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func string(_ keys: String...) -> String {
        for key in keys {
            guard let value = self[key] else { continue }
            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else if let number = value as? NSNumber {
                return number.stringValue
            } else {
                let description = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                if !description.isEmpty, description != "<null>" {
                    return description
                }
            }
        }
        return ""
    }

    func date(_ keys: String...) -> Date? {
        for key in keys {
            guard let value = self[key] else { continue }
            if let date = value as? Date {
                return date
            }
            if let text = value as? String, let parsedDate = LegacyDate.flexibleDate(from: text) {
                return parsedDate
            }

            let description = String(describing: value)
            if let parsedDate = LegacyDate.flexibleDate(from: description) {
                return parsedDate
            }
        }
        return nil
    }
}

enum LegacyDate {
    static var todayStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static var historyListFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }

    static var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    static func serverDate(from value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmedValue) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmedValue) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let normalizedValue = normalizeServerTimestamp(trimmedValue)
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
            "yyyy-MM-dd HH:mm:ss.SSSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalizedValue) {
                return date
            }
        }

        return nil
    }

    private static func normalizeServerTimestamp(_ value: String) -> String {
        guard let fractionalRange = value.range(of: #"([T\s]\d{2}:\d{2}:\d{2})\.(\d+)"#, options: .regularExpression) else {
            return value
        }

        let matched = String(value[fractionalRange])
        guard let dotIndex = matched.firstIndex(of: ".") else {
            return value
        }

        let prefix = String(matched[..<dotIndex])
        let fraction = String(matched[matched.index(after: dotIndex)...])
        let trimmedFraction = String(fraction.prefix(7))
        return value.replacingOccurrences(of: matched, with: "\(prefix).\(trimmedFraction)")
    }

    static func flexibleDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedWhitespace = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        if let date = serverDate(from: trimmed) {
            return date
        }

        if normalizedWhitespace != trimmed, let date = serverDate(from: normalizedWhitespace) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let posixFormats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss +0000",
            "yyyy-MM-dd HH:mm:ss 'UTC'",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy",
            "MMM d yyyy h:mma",
            "MMM d yyyy hh:mma",
            "EEEE, MMMM d, yyyy",
            "EEEE, MMMM d, yyyy h:mma",
            "EEEE, MMMM d, yyyy hh:mma"
        ]

        for format in posixFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalizedWhitespace) {
                return date
            }
        }

        formatter.locale = Locale(identifier: "tr_TR")
        let turkishFormats = [
            "dd.MM.yyyy EEEE HH:mm:ss",
            "dd.MM.yyyy EEEE",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy"
        ]

        for format in turkishFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalizedWhitespace) {
                return date
            }
        }

        return nil
    }

    static func yearDate(from year: String) -> Date? {
        let trimmed = year.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4 else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter.date(from: trimmed)
    }
}
