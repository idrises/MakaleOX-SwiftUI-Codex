import Foundation

enum RepositoryError: LocalizedError {
    case invalidCredentials
    case activationLimitReached
    case inaccessibleContent

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Activation information could not be verified. Please check your e-mail and serial."
        case .activationLimitReached:
            return "This serial has reached its activation limit."
        case .inaccessibleContent:
            return "You are not allowed to view this content."
        }
    }
}

final class LegacyRepository {
    private let gateway = SQLGateway()

    func persistArticleOpen(_ payload: PendingArticleOpenPayload) async throws {
        let parameters: [Any?] = [
            payload.author,
            payload.title,
            payload.journalName,
            payload.year,
            Date(),
            payload.email,
            payload.volume,
            "Mac SwiftUI",
            payload.issueTitle,
            payload.folder,
            payload.pdfLink
        ]

        do {
            try await gateway.execute(
                """
                INSERT INTO usersOpenedArticle (
                    author,
                    Article,
                    Journal,
                    year,
                    date,
                    usermail,
                    volume,
                    platform,
                    issueTitle,
                    folder,
                    pdfLink
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: parameters,
                timeout: 30
            )
        } catch {
            try await gateway.execute(
                "INSERT INTO usersOpenedArticle (author, Article, Journal, year, date, usermail, volume, platform) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                parameters: Array(parameters.prefix(8)),
                timeout: 30
            )
        }
    }

    func resolveHistoryReference(for entry: HistoryEntry) async throws -> HistoryReference? {
        switch entry.kind {
        case .article:
            let rows = try await gateway.query(
                """
                SELECT TOP 1 dergi, KLASOR, LINK
                FROM MAKALE
                WHERE MAKALE = ? AND dergi = ?
                ORDER BY createDate DESC, YIL DESC, VOLUME DESC
                """,
                parameters: [entry.title, entry.subtitle],
                timeout: 60
            )
            guard let row = rows.first else { return nil }
            let journal = row.string("dergi")
            let folder = row.string("KLASOR")
            let pdfLink = row.string("LINK")
            guard !journal.isEmpty, !folder.isEmpty, !pdfLink.isEmpty else { return nil }
            return .article(journal: journal, folder: folder, pdfLink: pdfLink)

        case .chapter:
            let rows = try await gateway.query(
                """
                SELECT TOP 1 isbn, link
                FROM newchaptern
                WHERE name = ? AND book = ?
                ORDER BY createDate DESC, year DESC
                """,
                parameters: [entry.title, entry.subtitle],
                timeout: 60
            )
            guard let row = rows.first else { return nil }
            let isbn = row.string("isbn")
            let pdfLink = row.string("link")
            guard !isbn.isEmpty, !pdfLink.isEmpty else { return nil }
            return .chapter(isbn: isbn, pdfLink: pdfLink)

        case .video:
            let rows = try await gateway.query(
                """
                SELECT TOP 1 bookJournal, link2
                FROM videos
                WHERE title = ? AND bookJournal = ?
                ORDER BY createDate DESC
                """,
                parameters: [entry.title, entry.subtitle],
                timeout: 60
            )
            guard let row = rows.first else { return nil }
            let bookJournal = row.string("bookJournal")
            let link = row.string("link2")
            guard !bookJournal.isEmpty, !link.isEmpty else { return nil }
            return .video(bookJournal: bookJournal, link: link)

        case .videoSet:
            let rows = try await gateway.query(
                """
                SELECT TOP 1 setName, link
                FROM newVideoSetDetay
                WHERE title = ? AND setName = ?
                ORDER BY createDate DESC
                """,
                parameters: [entry.title, entry.subtitle],
                timeout: 60
            )
            guard let row = rows.first else { return nil }
            let setName = row.string("setName")
            let link = row.string("link")
            guard !setName.isEmpty, !link.isEmpty else { return nil }
            return .videoSet(setName: setName, link: link)
        }
    }

    func fetchSession(email: String, serial: String) async throws -> SessionInfo {
        let userRows = try await gateway.query(
            "SELECT TOP 1 * FROM newUsers WHERE cdkey = ? AND Kulmail = ?",
            parameters: [serial, email],
            timeout: 90
        )

        guard let row = userRows.first else {
            throw RepositoryError.invalidCredentials
        }

        return SessionInfo(
            email: email,
            userID: row.string("userID", "userid", "ID", "id"),
            subject: row.string("subject"),
            expireDate: row.string("expireDate"),
            serial: serial,
            firstName: row.string("FirstName"),
            lastName: row.string("LastName")
        )
    }

    func activate(email: String, keyPart1: String, keyPart2: String, keyPart3: String) async throws -> SessionInfo {
        let serial = [keyPart1, keyPart2, keyPart3].joined(separator: "-").uppercased()
        let session = try await fetchSession(email: email, serial: serial)
        let userRows = try await gateway.query(
            "SELECT TOP 1 * FROM newUsers WHERE cdkey = ? AND Kulmail = ?",
            parameters: [serial, email],
            timeout: 90
        )
        guard let row = userRows.first else { throw RepositoryError.invalidCredentials }

        let activationLimit = Int(row.string("activate")) ?? 0
        let activationRows = try await gateway.query(
            "SELECT COUNT(*) AS activationCount FROM activation WHERE cdkey = ? AND Kulmail = ?",
            parameters: [serial, email],
            timeout: 90
        )

        let activationCount = Int(activationRows.first?.string("activationCount") ?? "0") ?? 0
        if activationLimit > 0, activationCount >= activationLimit {
            throw RepositoryError.activationLimitReached
        }

        try await gateway.execute(
            "INSERT INTO activation (cdkey, KulMacAdres, Kulmail, ip, Date, CpuId) VALUES (?, ?, ?, ?, GETDATE(), ?)",
            parameters: [serial, "swiftui", email, "swiftui", "swiftui"],
            timeout: 90
        )

        return session
    }

    func fetchDashboard(subject: String) async throws -> DashboardSnapshot {
        let predicate = subjectPredicate(subject)
        let journalCountRows = try await gateway.query(
            "SELECT COUNT(*) AS itemCount FROM dergi WHERE \(predicate.sql)",
            parameters: predicate.parameters,
            timeout: 90
        )
        let articleCountRows = try await gateway.query(
            "SELECT COUNT(*) AS itemCount FROM MAKALE WHERE \(predicate.sql)",
            parameters: predicate.parameters,
            timeout: 90
        )
        let bookCountRows = try await gateway.query(
            "SELECT COUNT(*) AS itemCount FROM newbooks WHERE (\(predicate.sql))",
            parameters: predicate.parameters,
            timeout: 90
        )
        let videoCountRows = try await gateway.query(
            "SELECT COUNT(*) AS itemCount FROM videos WHERE (\(predicate.sql))",
            parameters: predicate.parameters,
            timeout: 90
        )
        let videoSetCountRows = try await gateway.query(
            "SELECT COUNT(*) AS itemCount FROM newVideoSet WHERE \(predicate.sql)",
            parameters: predicate.parameters,
            timeout: 90
        )
        let issueRows = try await gateway.query(
            "SELECT DISTINCT TOP 8 DONEM, dergi, YIL, VOLUME, SAYI, createDate FROM MAKALE WHERE \(predicate.sql) ORDER BY createDate DESC",
            parameters: predicate.parameters,
            timeout: 90
        )
        let bookRows = try await gateway.query(
            "SELECT TOP 8 * FROM newbooks WHERE (\(predicate.sql)) ORDER BY createDate DESC",
            parameters: predicate.parameters,
            timeout: 90
        )
        let videoRows = try await gateway.query(
            "SELECT TOP 8 * FROM videos WHERE (\(predicate.sql)) ORDER BY createDate DESC",
            parameters: predicate.parameters,
            timeout: 90
        )
        let videoSetRows = try await gateway.query(
            "SELECT TOP 8 * FROM newVideoSet WHERE \(predicate.sql) ORDER BY createDate DESC",
            parameters: predicate.parameters,
            timeout: 90
        )

        return DashboardSnapshot(
            journalCount: countValue(from: journalCountRows),
            articleCount: countValue(from: articleCountRows),
            bookCount: countValue(from: bookCountRows),
            videoCount: countValue(from: videoCountRows),
            videoSetCount: countValue(from: videoSetCountRows),
            recentIssues: issueRows.map(JournalIssue.init),
            recentBooks: bookRows.map(Book.init),
            recentVideos: videoRows.map(Video.init),
            recentVideoSets: videoSetRows.map(VideoSet.init)
        )
    }

    func fetchJournals(subject: String, search: String = "") async throws -> [Journal] {
        let predicate = subjectPredicate(subject)
        var query = "SELECT * FROM dergi WHERE \(predicate.sql)"
        var parameters = predicate.parameters
        let searchText = search.trimmingCharacters(in: .whitespacesAndNewlines)

        if !searchText.isEmpty {
            let searchFilter = containsAllTerms(searchText, columns: ["dergi", "ISSNELECTRONIC", "subject"])
            query = "SELECT TOP 120 * FROM dergi WHERE \(predicate.sql) AND \(searchFilter.sql)"
            parameters += searchFilter.parameters
        }

        query += " ORDER BY dergi ASC"

        let rows = try await gateway.query(query, parameters: parameters, timeout: 90)
        return rows.map(Journal.init)
    }

    func fetchJournalIssues(for journal: String) async throws -> [JournalIssue] {
        let rows = try await gateway.query(
            "SELECT DISTINCT dergi, DONEM, YIL, VOLUME, (CASE WHEN ISNUMERIC(SAYI) = 1 THEN TRY_CAST(SAYI AS INT) ELSE '' END) AS IsNum FROM MAKALE WHERE dergi = ? ORDER BY YIL DESC, VOLUME DESC, IsNum DESC",
            parameters: [journal],
            timeout: 90
        )
        return rows.map(JournalIssue.init)
    }

    func fetchArticles(for issue: JournalIssue) async throws -> [Article] {
        var filters = ["dergi = ?", "DONEM = ?"]
        var parameters: [Any?] = [issue.journalName, issue.title]
        if !issue.year.isEmpty {
            filters.append("YIL = ?")
            parameters.append(issue.year)
        }
        if !issue.volume.isEmpty {
            filters.append("VOLUME = ?")
            parameters.append(issue.volume)
        }

        let rows = try await gateway.query(
            "SELECT * FROM MAKALE WHERE \(filters.joined(separator: " AND ")) ORDER BY YIL DESC, VOLUME DESC, SAYI DESC, ARTICLE ASC",
            parameters: parameters,
            timeout: 90
        )
        return rows.map(Article.init)
    }

    func fetchBooks(subject: String, search: String = "") async throws -> [Book] {
        let subjectFilter = subjectPredicate(subject)
        var query = "SELECT TOP 150 * FROM newbooks WHERE (\(subjectFilter.sql))"
        var parameters = subjectFilter.parameters
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = ["name", "editors", "subject", "isbnPrint", "isbnOnline", "company", "year"]
            let searchFilter = containsAllTerms(search, columns: columns)
            query += " AND \(searchFilter.sql)"
            parameters += searchFilter.parameters
        }
        query += " ORDER BY createDate DESC"

        let rows = try await gateway.query(query, parameters: parameters, timeout: 90)
        return rows.map(Book.init)
    }

    func fetchChapters(isbn: String) async throws -> [Chapter] {
        let rows = try await gateway.query(
            "SELECT * FROM newchaptern WHERE isbn = ?",
            parameters: [isbn],
            timeout: 90
        )
        return rows.map(Chapter.init)
    }

    func fetchVideos(subject: String, search: String = "") async throws -> [Video] {
        let subjectFilter = subjectPredicate(subject)
        var query = "SELECT TOP 180 * FROM videos WHERE (\(subjectFilter.sql))"
        var parameters = subjectFilter.parameters
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let columns = ["title", "author", "editor", "subject", "isbn", "bookJournal"]
            let searchFilter = containsAllTerms(search, columns: columns)
            query += " AND \(searchFilter.sql)"
            parameters += searchFilter.parameters
        }
        query += " ORDER BY createDate DESC"

        let rows = try await gateway.query(query, parameters: parameters, timeout: 90)
        return rows.map(Video.init)
    }

    func fetchVideos(bookJournal: String, subject: String) async throws -> [Video] {
        let sourceName = bookJournal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceName.isEmpty else { return [] }

        let subjectFilter = subjectPredicate(subject)
        let rows = try await gateway.query(
            """
            SELECT TOP 120 *
            FROM videos
            WHERE bookJournal = ? AND (\(subjectFilter.sql))
            ORDER BY createDate DESC
            """,
            parameters: [sourceName] + subjectFilter.parameters,
            timeout: 90
        )
        return rows.map(Video.init)
    }

    func fetchVideoSets(subject: String, search: String = "") async throws -> [VideoSet] {
        let predicate = subjectPredicate(subject)
        var query = "SELECT TOP 120 * FROM newVideoSet WHERE \(predicate.sql)"
        var parameters = predicate.parameters
        let searchText = search.trimmingCharacters(in: .whitespacesAndNewlines)

        if !searchText.isEmpty {
            let searchFilter = containsAllTerms(searchText, columns: ["setName", "editors", "subject"])
            query += " AND \(searchFilter.sql)"
            parameters += searchFilter.parameters
        }

        query += " ORDER BY createDate DESC"

        let rows = try await gateway.query(query, parameters: parameters, timeout: 90)
        return rows.map(VideoSet.init)
    }

    func fetchVideoSet(named setName: String, subject: String) async throws -> VideoSet? {
        let predicate = subjectPredicate(subject)
        let rows = try await gateway.query(
            "SELECT TOP 1 * FROM newVideoSet WHERE setName = ? AND (\(predicate.sql)) ORDER BY createDate DESC",
            parameters: [setName] + predicate.parameters,
            timeout: 90
        )
        return rows.first.map(VideoSet.init)
    }

    func fetchVideoSetEntries(setName: String) async throws -> [VideoSetEntry] {
        let rows = try await gateway.query(
            """
            SELECT
                newVideoSetDetay.setName AS setName,
                newVideoSetDetay.title AS title,
                newVideoSetDetay.author AS author,
                newVideoSet.editors AS editors,
                newVideoSetDetay.link AS link,
                newVideoSetDetay.imageLink AS imageLink,
                newVideoSetDetay.createDate AS createDate
            FROM newVideoSetDetay
            LEFT JOIN newVideoSet ON newVideoSet.setName = newVideoSetDetay.setName
            WHERE newVideoSetDetay.setName = ?
            ORDER BY newVideoSetDetay.createDate DESC
            """,
            parameters: [setName],
            timeout: 90
        )
        return rows.map(VideoSetEntry.init)
    }

    func search(text: String, subject: String) async throws -> SearchResults {
        let searchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return SearchResults() }
        let subjectFilter = subjectPredicate(subject)
        let articleColumns = ["MAKALE", "YAZAR", "dergi", "DONEM"]
        let chapterColumns = ["name", "book", "editors", "isbn"]
        let videoColumns = ["title", "author", "editor", "bookJournal", "isbn"]
        let videoSetColumns = [
            "newVideoSetDetay.title",
            "newVideoSetDetay.author",
            "newVideoSet.editors",
            "newVideoSetDetay.setName"
        ]
        let articleFilter = containsAllTerms(searchText, columns: articleColumns)
        let chapterFilter = containsAllTerms(searchText, columns: chapterColumns)
        let videoFilter = containsAllTerms(searchText, columns: videoColumns)
        let videoSetFilter = containsAllTerms(searchText, columns: videoSetColumns)

        let articleRows = try await gateway.query(
            "SELECT TOP 80 * FROM MAKALE WHERE (\(subjectFilter.sql)) AND \(articleFilter.sql) ORDER BY YIL DESC, VOLUME DESC, SAYI DESC, ARTICLE ASC",
            parameters: subjectFilter.parameters + articleFilter.parameters,
            timeout: 90
        )
        let chapterRows = try await gateway.query(
            "SELECT TOP 80 * FROM newchaptern WHERE \(chapterFilter.sql)",
            parameters: chapterFilter.parameters,
            timeout: 90
        )
        let videoRows = try await gateway.query(
            "SELECT TOP 80 * FROM videos WHERE (\(subjectFilter.sql)) AND \(videoFilter.sql) ORDER BY createDate DESC",
            parameters: subjectFilter.parameters + videoFilter.parameters,
            timeout: 90
        )
        let videoSetRows = try await gateway.query(
            "SELECT TOP 80 * FROM newVideoSetDetay INNER JOIN newVideoSet ON newVideoSet.setName = newVideoSetDetay.setName WHERE (\(subjectFilter.sql)) AND \(videoSetFilter.sql) ORDER BY newVideoSetDetay.createDate DESC",
            parameters: subjectFilter.parameters + videoSetFilter.parameters,
            timeout: 90
        )

        return SearchResults(
            articles: articleRows.map(Article.init),
            chapters: chapterRows.map(Chapter.init),
            videos: videoRows.map(Video.init),
            videoSetEntries: videoSetRows.map(VideoSetEntry.init)
        )
    }

    func fetchProfile(session: SessionInfo, favorites: FavoritesStore) async throws -> ProfileSummary {
        let userRows = try await gateway.query(
            "SELECT TOP 1 * FROM newUsers WHERE Kulmail = ?",
            parameters: [session.email],
            timeout: 90
        )
        let userRow = userRows.first ?? SQLRow()

        let articleCount = try await count(
            "SELECT COUNT(usermail) AS total FROM usersOpenedArticle WHERE usermail = ?",
            parameters: [session.email]
        )
        let chapterCount = try await count(
            "SELECT COUNT(usermail) AS total FROM usersOpenedChapter WHERE usermail = ?",
            parameters: [session.email]
        )
        let videoCount = try await count(
            "SELECT COUNT(usermail) AS total FROM videoOpened WHERE usermail = ?",
            parameters: [session.email]
        )
        let videoSetCount = try await count(
            "SELECT COUNT(usermail) AS total FROM videoSetOpened WHERE usermail = ?",
            parameters: [session.email]
        )
        let favoriteCounts = await MainActor.run {
            (
                journal: favorites.favoriteJournalIDs.count,
                book: favorites.favoriteBookIDs.count,
                videoSet: favorites.favoriteVideoSetIDs.count
            )
        }

        return ProfileSummary(
            fullName: [userRow.string("FirstName"), userRow.string("LastName")]
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            email: session.email,
            userID: userRow.string("userID", "userid", "ID", "id", "userId").isEmpty
                ? session.userID
                : userRow.string("userID", "userid", "ID", "id", "userId"),
            expireDate: session.expireDate,
            serial: session.serial,
            subject: session.subject,
            articleCount: articleCount,
            chapterCount: chapterCount,
            videoCount: videoCount,
            videoSetCount: videoSetCount,
            favoriteJournalCount: favoriteCounts.journal,
            favoriteBookCount: favoriteCounts.book,
            favoriteVideoSetCount: favoriteCounts.videoSet
        )
    }

    func fetchHistory(email: String, kind: HistoryKind? = nil) async throws -> [HistoryEntry] {
        let historyLimit = kind == nil ? 24 : 40

        let articleRows: [SQLRow]
        if kind == nil || kind == .article {
            articleRows = try await fetchArticleHistory(email: email, limit: historyLimit)
        } else {
            articleRows = []
        }

        let chapterRows: [SQLRow]
        if kind == nil || kind == .chapter {
            chapterRows = try await gateway.query(
                """
                WITH recentChapterHistory AS (
                    SELECT TOP \(historyLimit) chapter, book, [date]
                    FROM usersOpenedChapter
                    WHERE usermail = ?
                    ORDER BY [date] DESC
                )
                SELECT
                    resolved.name AS currentTitle,
                    resolved.book AS currentBook,
                    resolved.editors AS currentEditors,
                    CONVERT(varchar(33), recentChapterHistory.[date], 126) AS openedAtText,
                    resolved.isbn AS isbn,
                    resolved.link AS pdfLink,
                    resolved.year AS chapterYear
                FROM recentChapterHistory
                CROSS APPLY (
                    SELECT TOP 1 name, book, editors, isbn, link, year
                    FROM newchaptern
                    WHERE name = recentChapterHistory.chapter
                        AND book = recentChapterHistory.book
                    ORDER BY year DESC
                ) AS resolved
                ORDER BY recentChapterHistory.[date] DESC
                """,
                parameters: [email],
                timeout: 90
            )
        } else {
            chapterRows = []
        }

        let videoRows: [SQLRow]
        if kind == nil || kind == .video {
            videoRows = try await gateway.query(
                """
                WITH recentVideoHistory AS (
                    SELECT TOP \(historyLimit) bookJournal, title, link, openedDate
                    FROM videoOpened
                    WHERE usermail = ?
                    ORDER BY openedDate DESC
                )
                SELECT
                    resolved.title AS currentTitle,
                    resolved.bookJournal AS currentBookJournal,
                    resolved.author AS currentAuthor,
                    resolved.editor AS currentEditor,
                    resolved.link2 AS remoteLink,
                    resolved.imageLink AS imageLink,
                    CONVERT(varchar(33), recentVideoHistory.openedDate, 126) AS openedAtText
                FROM recentVideoHistory
                CROSS APPLY (
                    SELECT TOP 1 title, bookJournal, author, editor, link2, imageLink
                    FROM videos
                    WHERE link2 = recentVideoHistory.link
                        AND (recentVideoHistory.bookJournal = '' OR bookJournal = recentVideoHistory.bookJournal)
                        AND (recentVideoHistory.title = '' OR title = recentVideoHistory.title)
                    ORDER BY createDate DESC
                ) AS resolved
                ORDER BY recentVideoHistory.openedDate DESC
                """,
                parameters: [email],
                timeout: 90
            )
        } else {
            videoRows = []
        }

        let videoSetRows: [SQLRow]
        if kind == nil || kind == .videoSet {
            videoSetRows = try await gateway.query(
                """
                WITH recentVideoSetHistory AS (
                    SELECT TOP \(historyLimit) title, setName, author, openedDate
                    FROM videoSetOpened
                    WHERE usermail = ?
                    ORDER BY openedDate DESC
                )
                SELECT
                    resolved.title AS currentTitle,
                    resolved.setName AS currentSetName,
                    resolved.author AS currentAuthor,
                    CONVERT(varchar(33), recentVideoSetHistory.openedDate, 126) AS openedAtText,
                    resolved.imageLink AS imageLink,
                    resolved.link AS remoteLink
                FROM recentVideoSetHistory
                CROSS APPLY (
                    SELECT TOP 1
                        title,
                        setName,
                        author,
                        link,
                        imageLink
                    FROM newVideoSetDetay
                    WHERE setName = recentVideoSetHistory.setName
                        AND title = recentVideoSetHistory.title
                        AND (
                            recentVideoSetHistory.author = ''
                            OR author = recentVideoSetHistory.author
                        )
                    ORDER BY createDate DESC
                ) AS resolved
                ORDER BY recentVideoSetHistory.openedDate DESC
                """,
                parameters: [email],
                timeout: 90
            )
        } else {
            videoSetRows = []
        }

        let articleEntries = articleRows.compactMap { row -> HistoryEntry? in
            let journal = row.string("currentJournal")
            let title = row.string("currentTitle")
            let issueTitle = row.string("issueTitle")
            let folder = row.string("folder")
            let pdfLink = row.string("pdfLink")
            guard !journal.isEmpty, !title.isEmpty, !folder.isEmpty, !pdfLink.isEmpty else { return nil }

            let detail = issueTitle.isEmpty
                ? [row.string("currentYear"), row.string("currentVolume")].filter { !$0.isEmpty }.joined(separator: " • ")
                : issueTitle

            return HistoryEntry(
                kind: .article,
                title: title,
                subtitle: journal,
                detail: detail,
                urlString: "",
                coverURLString: LegacyConfig.issueCoverCandidates(journal: journal, issue: issueTitle).first?.absoluteString
                    ?? LegacyConfig.coverCandidates(for: journal).first?.absoluteString
                    ?? "",
                reference: .article(journal: journal, folder: folder, pdfLink: pdfLink),
                openedAt: LegacyDate.serverDate(from: row.string("openedAtText")) ?? Date()
            )
        }

        let chapterEntries = chapterRows.compactMap { row -> HistoryEntry? in
            let isbn = row.string("isbn")
            let pdfLink = row.string("pdfLink")
            let year = row.string("chapterYear")
            let title = row.string("currentTitle")
            let book = row.string("currentBook")
            guard !isbn.isEmpty, !pdfLink.isEmpty, !title.isEmpty, !book.isEmpty else { return nil }

            return HistoryEntry(
                kind: .chapter,
                title: title,
                subtitle: book,
                detail: [row.string("currentEditors"), year].filter { !$0.isEmpty }.joined(separator: " • "),
                urlString: "",
                coverURLString: LegacyConfig.bookCoverCandidates(isbn: isbn).first?.absoluteString ?? "",
                reference: .chapter(isbn: isbn, pdfLink: pdfLink),
                openedAt: LegacyDate.serverDate(from: row.string("openedAtText")) ?? Date()
            )
        }

        let videoEntries = videoRows.compactMap { row -> HistoryEntry? in
            let title = row.string("currentTitle")
            let bookJournal = row.string("currentBookJournal")
            let remoteLink = row.string("remoteLink")
            guard !title.isEmpty, !bookJournal.isEmpty, !remoteLink.isEmpty else { return nil }
            let remoteURL = LegacyConfig.videoRemoteURL(bookJournal: bookJournal, link: remoteLink)
            guard let remoteURL else { return nil }

            return HistoryEntry(
                kind: .video,
                title: title,
                subtitle: bookJournal,
                detail: row.string("currentAuthor"),
                urlString: remoteURL.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: row.string("imageLink")).first?.absoluteString ?? "",
                reference: .video(bookJournal: bookJournal, link: remoteLink),
                openedAt: LegacyDate.serverDate(from: row.string("openedAtText")) ?? Date()
            )
        }

        let videoSetEntries = videoSetRows.compactMap { row -> HistoryEntry? in
            let title = row.string("currentTitle")
            let setName = row.string("currentSetName")
            let remoteLink = row.string("remoteLink")
            guard !title.isEmpty, !setName.isEmpty, !remoteLink.isEmpty else { return nil }
            let remoteURL = LegacyConfig.videoSetRemoteURL(setName: setName, link: remoteLink)
            guard let remoteURL else { return nil }
            let imageName = row.string("imageLink").isEmpty ? setName : row.string("imageLink")

            return HistoryEntry(
                kind: .videoSet,
                title: title,
                subtitle: setName,
                detail: row.string("currentAuthor"),
                urlString: remoteURL.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: imageName).first?.absoluteString ?? "",
                reference: .videoSet(setName: setName, link: remoteLink),
                openedAt: LegacyDate.serverDate(from: row.string("openedAtText")) ?? Date()
            )
        }

        return (articleEntries + chapterEntries + videoEntries + videoSetEntries)
            .sorted { $0.openedAt > $1.openedAt }
    }

    func clearHistory(email: String) async throws {
        try await gateway.execute(
            "DELETE FROM usersOpenedArticle WHERE usermail = ?",
            parameters: [email],
            timeout: 60
        )
        try await gateway.execute(
            "DELETE FROM usersOpenedChapter WHERE usermail = ?",
            parameters: [email],
            timeout: 60
        )
        try await gateway.execute(
            "DELETE FROM videoOpened WHERE usermail = ?",
            parameters: [email],
            timeout: 60
        )
        try await gateway.execute(
            "DELETE FROM videoSetOpened WHERE usermail = ?",
            parameters: [email],
            timeout: 60
        )
    }

    private func countValue(from rows: [SQLRow]) -> Int {
        Int(rows.first?.string("itemCount") ?? "0") ?? 0
    }

    func recordArticleOpen(_ article: Article, email: String) async {
        _ = try? await persistArticleOpen(PendingArticleOpenPayload(article: article, email: email))
    }

    func recordChapterOpen(_ chapter: Chapter, email: String) async {
        _ = try? await gateway.execute(
            "INSERT INTO usersOpenedChapter (usermail, chapter, date, editors, book) VALUES (?, ?, ?, ?, ?)",
            parameters: [email, chapter.title, Date(), chapter.editors, chapter.bookTitle],
            timeout: 30
        )
    }

    func recordVideoOpen(_ video: Video, email: String) async {
        _ = try? await gateway.execute(
            "INSERT INTO videoOpened (usermail, bookJournal, editor, title, openedDate, link, likes, author, imageLink) VALUES (?, ?, ?, ?, GETDATE(), ?, ?, ?, ?)",
            parameters: [email, video.bookJournal, video.editor, video.title, video.remoteLink, video.likes, video.author, video.imageLink],
            timeout: 30
        )
    }

    func recordVideoSetOpen(setName: String, entry: VideoSetEntry, email: String) async {
        _ = try? await gateway.execute(
            "INSERT INTO videoSetOpened (usermail, title, setName, author, editor, openedDate) VALUES (?, ?, ?, ?, ?, GETDATE())",
            parameters: [email, entry.title, setName, entry.author, entry.editor],
            timeout: 30
        )
    }

    private func fetchArticleHistory(email: String, limit: Int) async throws -> [SQLRow] {
        do {
            return try await gateway.query(
                articleHistoryQueryWithStoredReference(limit: limit),
                parameters: [email],
                timeout: 90
            )
        } catch {
            return try await gateway.query(
                legacyArticleHistoryQuery(limit: limit),
                parameters: [email],
                timeout: 90
            )
        }
    }

    private func articleHistoryQueryWithStoredReference(limit: Int) -> String {
        """
        WITH recentArticleHistory AS (
            SELECT TOP \(limit)
                Article,
                Journal,
                year,
                volume,
                [date],
                COALESCE(author, '') AS historyAuthor,
                COALESCE(issueTitle, '') AS historyIssueTitle,
                COALESCE(folder, '') AS historyFolder,
                COALESCE(pdfLink, '') AS historyPdfLink
            FROM usersOpenedArticle
            WHERE usermail = ?
            ORDER BY [date] DESC
        )
        SELECT
            COALESCE(NULLIF(resolved.MAKALE, ''), recentArticleHistory.Article) AS currentTitle,
            COALESCE(NULLIF(resolved.YAZAR, ''), recentArticleHistory.historyAuthor) AS currentAuthor,
            COALESCE(NULLIF(resolved.dergi, ''), recentArticleHistory.Journal) AS currentJournal,
            CONVERT(varchar(33), recentArticleHistory.[date], 126) AS openedAtText,
            COALESCE(NULLIF(resolved.DONEM, ''), recentArticleHistory.historyIssueTitle) AS issueTitle,
            COALESCE(NULLIF(resolved.YIL, ''), recentArticleHistory.year) AS currentYear,
            COALESCE(NULLIF(resolved.VOLUME, ''), recentArticleHistory.volume) AS currentVolume,
            COALESCE(NULLIF(resolved.KLASOR, ''), recentArticleHistory.historyFolder) AS folder,
            COALESCE(NULLIF(resolved.LINK, ''), recentArticleHistory.historyPdfLink) AS pdfLink
        FROM recentArticleHistory
        OUTER APPLY (
            SELECT TOP 1 MAKALE, YAZAR, dergi, DONEM, YIL, VOLUME, KLASOR, LINK
            FROM MAKALE
            WHERE MAKALE = recentArticleHistory.Article
                AND dergi = recentArticleHistory.Journal
            ORDER BY
                CASE
                    WHEN recentArticleHistory.year <> ''
                        AND YIL = recentArticleHistory.year
                    THEN 0
                    ELSE 1
                END,
                CASE
                    WHEN recentArticleHistory.volume <> ''
                        AND VOLUME = recentArticleHistory.volume
                    THEN 0
                    ELSE 1
                END,
                createDate DESC,
                YIL DESC,
                VOLUME DESC
        ) AS resolved
        ORDER BY recentArticleHistory.[date] DESC
        """
    }

    private func legacyArticleHistoryQuery(limit: Int) -> String {
        """
        WITH recentArticleHistory AS (
            SELECT TOP \(limit) Article, Journal, year, volume, [date]
            FROM usersOpenedArticle
            WHERE usermail = ?
            ORDER BY [date] DESC
        )
        SELECT
            resolved.MAKALE AS currentTitle,
            resolved.YAZAR AS currentAuthor,
            resolved.dergi AS currentJournal,
            CONVERT(varchar(33), recentArticleHistory.[date], 126) AS openedAtText,
            resolved.DONEM AS issueTitle,
            resolved.YIL AS currentYear,
            resolved.VOLUME AS currentVolume,
            resolved.KLASOR AS folder,
            resolved.LINK AS pdfLink
        FROM recentArticleHistory
        CROSS APPLY (
            SELECT TOP 1 MAKALE, YAZAR, dergi, DONEM, YIL, VOLUME, KLASOR, LINK
            FROM MAKALE
            WHERE MAKALE = recentArticleHistory.Article
                AND dergi = recentArticleHistory.Journal
            ORDER BY
                CASE
                    WHEN recentArticleHistory.year <> ''
                        AND YIL = recentArticleHistory.year
                    THEN 0
                    ELSE 1
                END,
                CASE
                    WHEN recentArticleHistory.volume <> ''
                        AND VOLUME = recentArticleHistory.volume
                    THEN 0
                    ELSE 1
                END,
                createDate DESC,
                YIL DESC,
                VOLUME DESC
        ) AS resolved
        ORDER BY recentArticleHistory.[date] DESC
        """
    }

    private func count(_ sql: String, parameters: [Any?] = []) async throws -> Int {
        let rows = try await gateway.query(sql, parameters: parameters, timeout: 60)
        return Int(rows.first?.string("total") ?? "0") ?? 0
    }

    private func subjectPredicate(_ subject: String, column: String = "subject") -> SQLFilter {
        let parts = subject
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return .matchAll }
        return SQLFilter(
            sql: parts.map { _ in "\(column) LIKE ?" }.joined(separator: " OR "),
            parameters: parts.map { "%\($0)%" }
        )
    }

    private func containsAllTerms(_ text: String, columns: [String]) -> SQLFilter {
        let parts = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return .matchAll }
        var clauses: [String] = []
        var parameters: [Any?] = []

        for part in parts {
            let variants = part.searchVariants()
            let effectiveVariants = variants.isEmpty ? [part] : variants

            let clause = columns
                .map { column in
                    "(" + effectiveVariants.map { _ in "\(column) LIKE ?" }.joined(separator: " OR ") + ")"
                }
                .joined(separator: " OR ")

            clauses.append("(\(clause))")
            for _ in columns {
                parameters.append(contentsOf: effectiveVariants.map { "%\($0)%" })
            }
        }

        return SQLFilter(
            sql: clauses.joined(separator: " AND "),
            parameters: parameters
        )
    }
}

private struct SQLFilter {
    let sql: String
    let parameters: [Any?]

    static let matchAll = SQLFilter(sql: "1=1", parameters: [])
}
