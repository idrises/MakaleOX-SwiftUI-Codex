import Foundation

private enum HistoryReopenError: LocalizedError {
    case unresolved

    var errorDescription: String? {
        switch self {
        case .unresolved:
            return "This history item no longer has enough information to reopen."
        }
    }
}

private enum PreferredHistoryPage: String {
    case all
    case articles
    case books
    case videos
    case videoSets

    init(kind: HistoryKind?) {
        switch kind {
        case .article:
            self = .articles
        case .chapter:
            self = .books
        case .video:
            self = .videos
        case .videoSet:
            self = .videoSets
        case nil:
            self = .all
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var session: SessionInfo?
    @Published var selectedSection: AppSection = .dashboard
    @Published var dashboard = DashboardSnapshot()
    @Published var journals: [Journal] = []
    @Published var selectedJournal: Journal?
    @Published var pendingJournalNavigationID: String?
    @Published var journalIssues: [JournalIssue] = []
    @Published var selectedIssue: JournalIssue?
    @Published var articles: [Article] = []
    @Published var pendingJournalIssueNavigationID: String?
    @Published var journalReturnSection: AppSection?
    @Published var books: [Book] = []
    @Published var selectedBook: Book?
    @Published var chapters: [Chapter] = []
    @Published var pendingBookNavigationID: String?
    @Published var bookReturnSection: AppSection?
    @Published var videos: [Video] = []
    @Published var videoSets: [VideoSet] = []
    @Published var selectedVideoSet: VideoSet?
    @Published var videoSetEntries: [VideoSetEntry] = []
    @Published var pendingVideoSetNavigationID: String?
    @Published var videoSetReturnSection: AppSection?
    @Published var searchResults = SearchResults()
    @Published var profile: ProfileSummary?
    @Published var activeDocument: DocumentPresentation?
    @Published var activeVideo: VideoPresentation?
    @Published var activeAlert: AppAlert?
    @Published var isBusy = false
    @Published var isLoadingJournalIssues = false
    @Published var isLoadingArticles = false
    @Published var isLoadingChapters = false
    @Published var isLoadingVideoSetEntries = false
    @Published var isRefreshingHistory = false
    @Published private(set) var hasLoadedVideoSetCatalog = false
    @Published var preferredHistoryPageRawValue = PreferredHistoryPage.all.rawValue
    @Published var historyNavigationToken = UUID()
    @Published var journalsFavoritesOnly = false
    @Published var booksFavoritesOnly = false
    @Published var videoSetsFavoritesOnly = false
    @Published var loadingTitle = ""
    @Published var loadingDetail = ""
    @Published var loadingProgress: Double?
    @Published var profileSelectedDetailSectionRawValue: String?

    let sessionStore = SessionStore()
    let favoritesStore = FavoritesStore()
    let historyStore = HistoryStore()

    private let repository = LegacyRepository()
    private let assetLibrary = AssetLibrary()
    private var hasLoadedHistory = false

    init() {
        self.session = sessionStore.session
        self.hasLoadedHistory = !historyStore.entries.isEmpty
    }

    func bootstrap() async {
        session = sessionStore.session
        guard session != nil else { return }
        selectedSection = .dashboard
    }

    func activate(email: String, keyPart1: String, keyPart2: String, keyPart3: String) async {
        await perform("Activating membership") { [self] in
            let session = try await self.repository.activate(
                email: email,
                keyPart1: keyPart1,
                keyPart2: keyPart2,
                keyPart3: keyPart3
            )
            self.sessionStore.save(session)
            self.session = session
            self.selectedSection = .dashboard
            self.resetRemoteContent()
        }
    }

    func reloadEverything() async {
        await perform("Refreshing library") { [self] in
            try await self.loadEverything()
        }
    }

    func loadCurrentSectionIfNeeded() async {
        guard session != nil else { return }
        guard shouldLoadSection(selectedSection) else { return }
        await refreshCurrentSection()
    }

    func refreshCurrentSection() async {
        guard session != nil else { return }

        switch selectedSection {
        case .dashboard:
            await perform("Loading dashboard") { [self] in
                let activeSession = try await self.syncSessionFromServer()
                self.dashboard = try await self.repository.fetchDashboard(subject: activeSession.subject)
            }
        case .journals:
            await loadJournals()
        case .books:
            await loadBooks()
        case .videos:
            await loadVideos()
        case .videoSets:
            await perform("Loading video sets") { [self] in
                let activeSession = try await self.syncSessionFromServer()
                self.videoSets = try await self.repository.fetchVideoSets(subject: activeSession.subject)
                self.selectedVideoSet = self.selectedVideoSet.flatMap { previous in
                    self.videoSets.first(where: { $0.id == previous.id })
                }
                self.hasLoadedVideoSetCatalog = true
                self.videoSetEntries = []
            }
        case .search:
            break
        case .history:
            await refreshHistory()
        case .profile:
            await refreshProfile()
        }
    }

    func refreshProfile() async {
        await perform("Refreshing profile") { [self] in
            let session = try await self.syncSessionFromServer()
            self.profile = try await self.repository.fetchProfile(session: session, favorites: self.favoritesStore)
        }
    }

    func refreshHistory(kind: HistoryKind? = nil) async {
        guard let session else { return }
        isRefreshingHistory = true

        do {
            let entries = try await self.repository.fetchHistory(email: session.email, kind: kind)
            self.historyStore.replace(with: entries, for: kind)
            self.hasLoadedHistory = true
        } catch {
            activeAlert = AppAlert(
                title: "Something Went Wrong",
                message: error.localizedDescription
            )
        }

        isRefreshingHistory = false
    }

    func clearHistory() async {
        historyStore.clear()
        hasLoadedHistory = true
    }

    func showProfileHistory(kind: HistoryKind) {
        clearScopedLibraryFilters()
        preferredHistoryPageRawValue = PreferredHistoryPage(kind: kind).rawValue
        historyNavigationToken = UUID()
        selectedSection = .history
    }

    func showFavoriteJournals() {
        clearScopedLibraryFilters()
        journalsFavoritesOnly = true
        selectedSection = .journals
    }

    func showFavoriteBooks() {
        clearScopedLibraryFilters()
        booksFavoritesOnly = true
        selectedSection = .books
    }

    func showFavoriteVideoSets() {
        clearScopedLibraryFilters()
        videoSetsFavoritesOnly = true
        selectedSection = .videoSets
    }

    func dismissActiveContent() {
        activeDocument = nil
        activeVideo = nil
    }

    func loadJournals(search: String = "") async {
        await perform("Loading journals") { [self] in
            let activeSession = try await self.syncSessionFromServer()
            self.journals = try await self.repository.fetchJournals(subject: activeSession.subject, search: search)
            self.selectedJournal = self.selectedJournal.flatMap { previous in
                self.journals.first(where: { $0.id == previous.id })
            } ?? self.journals.first
            self.isLoadingJournalIssues = false
            self.isLoadingArticles = false
            self.journalIssues = []
            self.selectedIssue = nil
            self.articles = []
        }
    }

    func loadBooks(search: String = "") async {
        await perform("Loading books") { [self] in
            let session = try await self.syncSessionFromServer()
            self.books = try await self.repository.fetchBooks(subject: session.subject, search: search)
            self.selectedBook = self.selectedBook.flatMap { previous in
                self.books.first(where: { $0.id == previous.id })
            } ?? self.books.first
            self.isLoadingChapters = false
            self.chapters = []
        }
    }

    func loadVideos(search: String = "") async {
        await perform("Loading videos") { [self] in
            let session = try await self.syncSessionFromServer()
            self.videos = try await self.repository.fetchVideos(subject: session.subject, search: search)
        }
    }

    func loadVideoSetsForProfile() async {
        await perform("Loading video sets") { [self] in
            let activeSession = try await self.syncSessionFromServer()
            self.videoSets = try await self.repository.fetchVideoSets(subject: activeSession.subject)
            self.selectedVideoSet = self.selectedVideoSet.flatMap { previous in
                self.videoSets.first(where: { $0.id == previous.id })
            }
            self.hasLoadedVideoSetCatalog = true
            self.videoSetEntries = []
        }
    }

    func selectJournal(_ journal: Journal) async {
        activeAlert = nil
        selectedJournal = journal
        journalIssues = []
        selectedIssue = nil
        articles = []

        isLoadingJournalIssues = true
        isLoadingArticles = false

        do {
            let issues = try await repository.fetchJournalIssues(for: journal.name)
            if selectedJournal?.id == journal.id {
                journalIssues = issues
            }
        } catch {
            if selectedJournal?.id == journal.id {
                activeAlert = AppAlert(
                    title: "Something Went Wrong",
                    message: error.localizedDescription
                )
            }
        }

        if selectedJournal?.id == journal.id {
            isLoadingJournalIssues = false
        }
    }

    func showProfileJournal(_ journal: Journal) async {
        activeAlert = nil
        profileSelectedDetailSectionRawValue = ProfileDetailSection.favoriteJournals.rawValue

        let resolvedJournal: Journal
        if let existingJournal = journals.first(where: { $0.id == journal.id }) {
            resolvedJournal = existingJournal
        } else {
            journals.insert(journal, at: 0)
            resolvedJournal = journal
        }

        selectedJournal = resolvedJournal
        journalIssues = []
        selectedIssue = nil
        articles = []
        pendingJournalNavigationID = resolvedJournal.id
        pendingJournalIssueNavigationID = nil
        journalReturnSection = .profile
        selectedSection = .journals

        await selectJournal(resolvedJournal)
    }

    func selectIssue(_ issue: JournalIssue, forceReload: Bool = false) async {
        if !forceReload, selectedIssue?.id == issue.id, !articles.isEmpty {
            return
        }

        guard !(isLoadingArticles && selectedIssue?.id == issue.id) else { return }

        activeAlert = nil
        selectedIssue = issue
        articles = []
        isLoadingArticles = true

        do {
            let fetchedArticles = try await repository.fetchArticles(for: issue)
            if selectedIssue?.id == issue.id {
                articles = fetchedArticles
            }
        } catch {
            if selectedIssue?.id == issue.id {
                activeAlert = AppAlert(
                    title: "Something Went Wrong",
                    message: error.localizedDescription
                )
            }
        }

        if selectedIssue?.id == issue.id {
            isLoadingArticles = false
        }
    }

    func selectBook(_ book: Book, forceReload: Bool = false) async {
        if !forceReload, selectedBook?.id == book.id, !chapters.isEmpty {
            return
        }

        guard !(isLoadingChapters && selectedBook?.id == book.id && !forceReload) else { return }

        activeAlert = nil
        selectedBook = book
        chapters = []
        isLoadingChapters = true

        let isbn = book.isbnOnline.isEmpty ? book.isbnPrint : book.isbnOnline
        guard !isbn.isEmpty else {
            if selectedBook?.id == book.id {
                isLoadingChapters = false
            }
            return
        }

        do {
            let fetchedChapters = try await repository.fetchChapters(isbn: isbn)
            if selectedBook?.id == book.id {
                chapters = fetchedChapters
            }
        } catch {
            if selectedBook?.id == book.id {
                activeAlert = AppAlert(
                    title: "Something Went Wrong",
                    message: error.localizedDescription
                )
            }
        }

        if selectedBook?.id == book.id {
            isLoadingChapters = false
        }
    }

    func selectVideoSet(_ set: VideoSet, forceReload: Bool = false) async {
        if !forceReload, selectedVideoSet?.id == set.id, !videoSetEntries.isEmpty {
            return
        }

        guard !(isLoadingVideoSetEntries && selectedVideoSet?.id == set.id) else { return }

        activeAlert = nil
        let wasSameSet = selectedVideoSet?.id == set.id
        let existingEntries = wasSameSet ? videoSetEntries : []
        selectedVideoSet = set
        if !wasSameSet {
            videoSetEntries = []
        }
        isLoadingVideoSetEntries = true

        do {
            let fetchedEntries = try await repository.fetchVideoSetEntries(setName: set.setName)
            if selectedVideoSet?.id == set.id {
                if wasSameSet, fetchedEntries.isEmpty, !existingEntries.isEmpty {
                    videoSetEntries = existingEntries
                } else {
                    videoSetEntries = fetchedEntries
                }
            }
        } catch {
            if selectedVideoSet?.id == set.id {
                if wasSameSet {
                    videoSetEntries = existingEntries
                }
                activeAlert = AppAlert(
                    title: "Something Went Wrong",
                    message: error.localizedDescription
                )
            }
        }

        if selectedVideoSet?.id == set.id {
            isLoadingVideoSetEntries = false
        }
    }

    func showVideoSetCollection(_ set: VideoSet) async {
        activeAlert = nil

        let resolvedSet: VideoSet
        if let existingSet = videoSets.first(where: { $0.id == set.id }) {
            resolvedSet = existingSet
        } else {
            videoSets.insert(set, at: 0)
            if videoSets.count == 1 {
                hasLoadedVideoSetCatalog = false
            }
            resolvedSet = set
        }

        selectedVideoSet = resolvedSet
        videoSetEntries = []
        pendingVideoSetNavigationID = resolvedSet.id
        videoSetReturnSection = .dashboard
        selectedSection = .videoSets

        await selectVideoSet(resolvedSet)
    }

    func showDashboardIssue(_ issue: JournalIssue) async {
        activeAlert = nil

        let resolvedJournal: Journal
        if let existingJournal = journals.first(where: { $0.name == issue.journalName }) {
            resolvedJournal = existingJournal
        } else {
            let seededJournal = Journal(
                name: issue.journalName,
                subject: session?.subject ?? ""
            )
            journals.insert(seededJournal, at: 0)
            resolvedJournal = seededJournal
        }

        selectedJournal = resolvedJournal
        selectedIssue = issue
        journalIssues = []
        articles = []
        pendingJournalIssueNavigationID = issue.id
        journalReturnSection = .dashboard
        selectedSection = .journals

        await selectIssue(issue)
    }

    func showDashboardBook(_ book: Book) async {
        activeAlert = nil

        let resolvedBook: Book
        if let existingBook = books.first(where: { $0.id == book.id }) {
            resolvedBook = existingBook
        } else {
            books.insert(book, at: 0)
            resolvedBook = book
        }

        selectedBook = resolvedBook
        chapters = []
        pendingBookNavigationID = resolvedBook.id
        bookReturnSection = .dashboard
        selectedSection = .books

        await selectBook(resolvedBook)
    }

    func showProfileBook(_ book: Book) async {
        activeAlert = nil
        profileSelectedDetailSectionRawValue = ProfileDetailSection.favoriteBooks.rawValue

        let resolvedBook: Book
        if let existingBook = books.first(where: { $0.id == book.id }) {
            resolvedBook = existingBook
        } else {
            books.insert(book, at: 0)
            resolvedBook = book
        }

        selectedBook = resolvedBook
        chapters = []
        pendingBookNavigationID = resolvedBook.id
        bookReturnSection = .profile
        selectedSection = .books

        await selectBook(resolvedBook)
    }

    func runSearch(_ text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchResults = SearchResults()
            return
        }

        await perform("Searching library") { [self] in
            let session = try await self.syncSessionFromServer()
            self.searchResults = try await self.repository.search(text: query, subject: session.subject)
        }
    }

    func showJournalFromSearch(_ journal: Journal) async {
        selectedSection = .journals
        if let existingJournal = journals.first(where: { $0.id == journal.id }) {
            selectedJournal = existingJournal
        } else {
            journals.insert(journal, at: 0)
            selectedJournal = journal
        }
        journalIssues = []
        selectedIssue = nil
        articles = []
        isLoadingArticles = false
    }

    func showBookFromSearch(_ book: Book) async {
        selectedSection = .books
        if let existingBook = books.first(where: { $0.id == book.id }) {
            selectedBook = existingBook
        } else {
            books.insert(book, at: 0)
            selectedBook = book
        }
        chapters = []
    }

    func showVideoSetFromSearch(_ set: VideoSet) async {
        selectedSection = .videoSets
        if let existingSet = videoSets.first(where: { $0.id == set.id }) {
            selectedVideoSet = existingSet
        } else {
            videoSets.insert(set, at: 0)
            selectedVideoSet = set
        }

        await perform("Loading video set") { [self] in
            self.videoSetEntries = try await self.repository.fetchVideoSetEntries(setName: set.setName)
        }
    }

    func showProfileVideoSet(_ set: VideoSet) async {
        activeAlert = nil
        profileSelectedDetailSectionRawValue = ProfileDetailSection.favoriteVideoSets.rawValue

        let resolvedSet: VideoSet
        if let existingSet = videoSets.first(where: { $0.id == set.id }) {
            resolvedSet = existingSet
        } else {
            videoSets.insert(set, at: 0)
            resolvedSet = set
        }

        selectedVideoSet = resolvedSet
        videoSetEntries = []
        pendingVideoSetNavigationID = resolvedSet.id
        videoSetReturnSection = .profile
        selectedSection = .videoSets

        await selectVideoSet(resolvedSet)
    }

    func openArticle(_ article: Article) async {
        guard let session else { return }
        guard validateSession(session) else { return }

        await perform("Opening article") { [self] in
            let url = try await self.assetLibrary.articleURL(for: article) { progress in
                self.loadingTitle = "Downloading article"
                self.loadingDetail = progress.detailText
                self.loadingProgress = progress.fractionCompleted
            }
            await self.repository.recordArticleOpen(article, email: session.email)
            self.historyStore.add(
                HistoryEntry(
                    kind: .article,
                    title: article.title,
                    subtitle: article.journalName,
                    detail: article.issueTitle,
                    urlString: url.path,
                    coverURLString: LegacyConfig.issueCoverCandidates(
                        journal: article.journalName,
                        issue: article.issueTitle
                    ).first?.absoluteString ?? "",
                    reference: .article(journal: article.journalName, folder: article.folder, pdfLink: article.pdfLink)
                )
            )
            self.activeVideo = nil
            self.activeDocument = DocumentPresentation(title: article.title, url: url)
        }
    }

    func openChapter(_ chapter: Chapter) async {
        guard let session else { return }
        guard validateSession(session) else { return }

        await perform("Opening chapter") { [self] in
            let url = try await self.assetLibrary.chapterURL(for: chapter) { progress in
                self.loadingTitle = "Downloading chapter"
                self.loadingDetail = progress.detailText
                self.loadingProgress = progress.fractionCompleted
            }
            await self.repository.recordChapterOpen(chapter, email: session.email)
            self.historyStore.add(
                HistoryEntry(
                    kind: .chapter,
                    title: chapter.title,
                    subtitle: chapter.bookTitle,
                    detail: chapter.editors,
                    urlString: url.path,
                    coverURLString: LegacyConfig.bookCoverCandidates(isbn: chapter.isbn).first?.absoluteString ?? "",
                    reference: .chapter(isbn: chapter.isbn, pdfLink: chapter.pdfLink)
                )
            )
            self.activeVideo = nil
            self.activeDocument = DocumentPresentation(title: chapter.title, url: url)
        }
    }

    func playVideo(_ video: Video) async {
        guard let session else { return }
        guard validateSession(session) else { return }
        guard let url = LegacyConfig.videoRemoteURL(bookJournal: video.bookJournal, link: video.remoteLink) else {
            activeAlert = AppAlert(title: "Video URL Error", message: "The video link could not be created.")
            return
        }

        await repository.recordVideoOpen(video, email: session.email)
        historyStore.add(
            HistoryEntry(
                kind: .video,
                title: video.title,
                subtitle: video.bookJournal,
                detail: video.author,
                urlString: url.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: video.imageLink).first?.absoluteString ?? "",
                reference: .video(bookJournal: video.bookJournal, link: video.remoteLink)
            )
        )
        activeDocument = nil
        activeVideo = VideoPresentation(title: video.title, url: url)
    }

    func openVideoSetEntryFromSearch(_ entry: VideoSetEntry) async {
        do {
            let activeSession = try await syncSessionFromServer()
            guard validateSession(activeSession) else { return }

            let resolvedSet: VideoSet
            if let cachedSet = videoSets.first(where: { $0.setName == entry.setName }) {
                resolvedSet = cachedSet
            } else if let fetchedSet = try await repository.fetchVideoSet(
                named: entry.setName,
                subject: activeSession.subject
            ) {
                resolvedSet = fetchedSet
                if !videoSets.contains(where: { $0.id == fetchedSet.id }) {
                    videoSets.insert(fetchedSet, at: 0)
                }
            } else {
                activeAlert = AppAlert(
                    title: "Set Not Found",
                    message: "The selected video set could not be loaded from the server."
                )
                return
            }

            await playVideoSetEntry(entry, from: resolvedSet)
        } catch {
            activeAlert = AppAlert(
                title: "Something Went Wrong",
                message: error.localizedDescription
            )
        }
    }

    func playVideoSetEntry(_ entry: VideoSetEntry, from set: VideoSet) async {
        guard let session else { return }
        guard validateSession(session) else { return }
        guard set.isAccessible(for: session.userID) else {
            activeAlert = AppAlert(title: "Access Limited", message: "Your membership is not allowed to open this video set.")
            return
        }
        guard let url = LegacyConfig.videoSetRemoteURL(setName: entry.setName, link: entry.remoteLink) else {
            activeAlert = AppAlert(title: "Video URL Error", message: "The video link could not be created.")
            return
        }

        await repository.recordVideoSetOpen(setName: set.setName, entry: entry, email: session.email)
        historyStore.add(
            HistoryEntry(
                kind: .videoSet,
                title: entry.title,
                subtitle: entry.setName,
                detail: entry.author,
                urlString: url.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: entry.imageLink).first?.absoluteString ?? "",
                reference: .videoSet(setName: entry.setName, link: entry.remoteLink)
            )
        )
        activeDocument = nil
        activeVideo = VideoPresentation(title: entry.title, url: url)
    }

    func reopenHistoryEntry(_ entry: HistoryEntry) async {
        switch entry.kind {
        case .article, .chapter:
            if FileManager.default.fileExists(atPath: entry.urlString) {
                let url = URL(fileURLWithPath: entry.urlString)
                activeVideo = nil
                activeDocument = DocumentPresentation(title: entry.title, url: url)
                return
            }

            await perform("Opening history item") { [self] in
                let reference = try await self.resolveHistoryReference(for: entry)
                let localURL: URL
                switch reference.kind {
                case .article:
                    localURL = try await self.assetLibrary.articleURL(
                        journal: reference.primary,
                        folder: reference.secondary,
                        pdfLink: reference.tertiary
                    ) { progress in
                        self.loadingTitle = "Downloading article"
                        self.loadingDetail = progress.detailText
                        self.loadingProgress = progress.fractionCompleted
                    }
                case .chapter:
                    localURL = try await self.assetLibrary.chapterURL(
                        isbn: reference.primary,
                        pdfLink: reference.secondary
                    ) { progress in
                        self.loadingTitle = "Downloading chapter"
                        self.loadingDetail = progress.detailText
                        self.loadingProgress = progress.fractionCompleted
                    }
                case .video, .videoSet:
                    throw URLError(.badURL)
                }

                self.historyStore.update(entry.updating(urlString: localURL.path, reference: reference))
                self.activeVideo = nil
                self.activeDocument = DocumentPresentation(title: entry.title, url: localURL)
            }
        case .video, .videoSet:
            if let url = URL(string: entry.urlString), !entry.urlString.isEmpty {
                activeDocument = nil
                activeVideo = VideoPresentation(title: entry.title, url: url)
                return
            }

            await perform("Opening history item") { [self] in
                let reference = try await self.resolveHistoryReference(for: entry)

                let url: URL?
                switch reference.kind {
                case .video:
                    url = LegacyConfig.videoRemoteURL(bookJournal: reference.primary, link: reference.secondary)
                case .videoSet:
                    url = LegacyConfig.videoSetRemoteURL(setName: reference.primary, link: reference.secondary)
                case .article, .chapter:
                    url = nil
                }

                guard let url else {
                    throw URLError(.badURL)
                }

                self.historyStore.update(entry.updating(urlString: url.absoluteString, reference: reference))
                self.activeDocument = nil
                self.activeVideo = VideoPresentation(title: entry.title, url: url)
            }
        }
    }

    func logout() {
        sessionStore.clear()
        session = nil
        historyStore.replace(with: [])
        resetRemoteContent()
        selectedSection = .dashboard
    }

    private func loadEverything() async throws {
        let session = try await syncSessionFromServer()

        dashboard = try await repository.fetchDashboard(subject: session.subject)
        journals = try await repository.fetchJournals(subject: session.subject)
        selectedJournal = selectedJournal.flatMap { previous in
            journals.first(where: { $0.id == previous.id })
        } ?? journals.first
        pendingJournalNavigationID = nil
        journalIssues = []
        selectedIssue = nil
        articles = []
        pendingJournalIssueNavigationID = nil
        journalReturnSection = nil

        books = try await repository.fetchBooks(subject: session.subject)
        pendingBookNavigationID = nil
        bookReturnSection = nil
        selectedBook = selectedBook.flatMap { previous in
            books.first(where: { $0.id == previous.id })
        } ?? books.first
        isLoadingChapters = false
        chapters = []

        videos = try await repository.fetchVideos(subject: session.subject)
        videoSets = try await repository.fetchVideoSets(subject: session.subject)
        hasLoadedVideoSetCatalog = true
        selectedVideoSet = selectedVideoSet.flatMap { previous in
            videoSets.first(where: { $0.id == previous.id })
        } ?? videoSets.first
        if let selectedVideoSet {
            videoSetEntries = try await repository.fetchVideoSetEntries(setName: selectedVideoSet.setName)
        } else {
            videoSetEntries = []
        }

        profile = try await repository.fetchProfile(session: session, favorites: favoritesStore)
    }

    private func validateSession(_ session: SessionInfo) -> Bool {
        guard !session.isExpired else {
            activeAlert = AppAlert(
                title: "Membership Expired",
                message: "Your access period appears to be over. Please renew your membership to keep opening content."
            )
            return false
        }
        return true
    }

    private func shouldLoadSection(_ section: AppSection) -> Bool {
        switch section {
        case .dashboard:
            return dashboard.recentIssues.isEmpty
                && dashboard.recentBooks.isEmpty
                && dashboard.recentVideos.isEmpty
                && dashboard.recentVideoSets.isEmpty
        case .journals:
            return journals.isEmpty
        case .books:
            return books.isEmpty
        case .videos:
            return videos.isEmpty
        case .videoSets:
            return videoSets.isEmpty
        case .search:
            return false
        case .history:
            return !hasLoadedHistory
        case .profile:
            return profile == nil
        }
    }

    private func resetRemoteContent() {
        dashboard = DashboardSnapshot()
        journals = []
        selectedJournal = nil
        pendingJournalNavigationID = nil
        journalIssues = []
        selectedIssue = nil
        articles = []
        pendingJournalIssueNavigationID = nil
        journalReturnSection = nil
        books = []
        selectedBook = nil
        chapters = []
        pendingBookNavigationID = nil
        bookReturnSection = nil
        videos = []
        videoSets = []
        selectedVideoSet = nil
        videoSetEntries = []
        pendingVideoSetNavigationID = nil
        videoSetReturnSection = nil
        searchResults = SearchResults()
        profile = nil
        activeDocument = nil
        activeVideo = nil
        isLoadingJournalIssues = false
        isLoadingArticles = false
        isLoadingChapters = false
        isLoadingVideoSetEntries = false
        hasLoadedVideoSetCatalog = false
        isRefreshingHistory = false
        hasLoadedHistory = false
        clearScopedLibraryFilters()
        preferredHistoryPageRawValue = PreferredHistoryPage.all.rawValue
        historyNavigationToken = UUID()
        profileSelectedDetailSectionRawValue = nil
    }

    private func clearScopedLibraryFilters() {
        journalsFavoritesOnly = false
        booksFavoritesOnly = false
        videoSetsFavoritesOnly = false
    }

    private func requireSession() throws -> SessionInfo {
        guard let session else {
            throw RepositoryError.invalidCredentials
        }
        return session
    }

    private func syncSessionFromServer() async throws -> SessionInfo {
        let currentSession = try requireSession()
        let refreshedSession = try await repository.fetchSession(
            email: currentSession.email,
            serial: currentSession.serial
        )
        sessionStore.save(refreshedSession)
        session = refreshedSession
        return refreshedSession
    }

    private func resolveHistoryReference(for entry: HistoryEntry) async throws -> HistoryReference {
        if let reference = entry.reference {
            return reference
        }

        if let resolved = try await repository.resolveHistoryReference(for: entry) {
            return resolved
        }

        throw HistoryReopenError.unresolved
    }

    private func perform(_ loadingTitle: String, operation: @escaping () async throws -> Void) async {
        isBusy = true
        self.loadingTitle = loadingTitle
        self.loadingDetail = ""
        self.loadingProgress = nil

        do {
            try await operation()
        } catch {
            activeAlert = AppAlert(
                title: "Something Went Wrong",
                message: error.localizedDescription
            )
        }

        self.loadingTitle = ""
        self.loadingDetail = ""
        self.loadingProgress = nil
        isBusy = false
    }
}
