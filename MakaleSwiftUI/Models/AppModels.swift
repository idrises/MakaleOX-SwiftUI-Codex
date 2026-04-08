import Foundation

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

struct DocumentPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

struct VideoPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
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

    static var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    static func serverDate(from value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }

    static func flexibleDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = serverDate(from: trimmed) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss +0000",
            "yyyy-MM-dd HH:mm:ss 'UTC'"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
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
