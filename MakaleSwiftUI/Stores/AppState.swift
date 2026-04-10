import Foundation
import OSLog

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

private enum VideoRailContext {
    case source
    case search(SearchVideoRailScope)
}

private enum SearchVideoRailCandidate {
    case video(Video)
    case videoSet(VideoSetEntry)

    var sortDate: Date {
        switch self {
        case .video(let video):
            return video.sortDate ?? .distantPast
        case .videoSet(let entry):
            return entry.sortDate ?? .distantPast
        }
    }
}

private actor OpenEventSyncService {
    private var isSyncing = false
    private let logger = Logger(subsystem: "com.codex.MakaleSwiftUI", category: "OpenEventSync")

    func flushPendingEvents(
        email: String,
        store: OpenEventStore,
        repository: LegacyRepository
    ) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        while let candidate = await store.nextSyncCandidate(for: email) {
            guard let event = await store.beginSync(id: candidate.id) else { continue }

            do {
                switch event.kind {
                case .article:
                    guard let payload = event.articlePayload else {
                        await store.markFailed(id: event.id, errorDescription: "Missing article payload.")
                        logger.error("Article open event \(event.id.uuidString, privacy: .public) missing payload.")
                        continue
                    }
                    try await repository.persistArticleOpen(payload)
                    logger.log("Synced article open event \(event.id.uuidString, privacy: .public) for \(payload.email, privacy: .public).")
                }

                await store.markSent(id: event.id)
            } catch {
                await store.markFailed(id: event.id, errorDescription: error.localizedDescription)
                logger.error("Failed article open event \(event.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
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
    @Published var currentSearchQuery = ""
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
    @Published private(set) var historyPreparationMessage: String?
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
    let openEventStore = OpenEventStore()
    let videoDownloadManager = VideoDownloadManager.shared

    private let repository = LegacyRepository()
    private let assetLibrary = AssetLibrary()
    private let openEventSyncService = OpenEventSyncService()
    private var hasLoadedHistory = false
    private var loadedHistoryScopes: Set<String> = []
    private var loadedHistoryCounts: [String: Int] = [:]
    private var lastHistoryRefreshDates: [String: Date] = [:]
    private var historyPreparationTask: Task<Void, Never>?
    private let historyAutoRefreshInterval: TimeInterval = 120

    init() {
        self.session = sessionStore.session
        self.hasLoadedHistory = !historyStore.entries.isEmpty
    }

    func bootstrap() async {
        session = sessionStore.session
        guard session != nil else { return }
        selectedSection = .dashboard
        syncPendingOpenEventsInBackground()
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
            prepareHistoryInBackgroundIfNeeded()
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

    func refreshHistory(kind: HistoryKind? = nil, minimumCount: Int = 50, force: Bool = true) async {
        guard let session else { return }
        guard force || shouldPrepareHistory(kind: kind, minimumCount: minimumCount) || shouldAutoRefreshHistory(kind: kind) else { return }
        guard !isRefreshingHistory else { return }

        isRefreshingHistory = true
        historyPreparationMessage = historyMessage(for: kind, minimumCount: minimumCount)

        do {
            let entries = try await self.repository.fetchHistory(
                email: session.email,
                kind: kind,
                limit: minimumCount
            )
            let mergedEntries = mergeHistoryEntries(entries, kind: kind, email: session.email)
            self.historyStore.replace(with: mergedEntries, for: kind)
            self.hasLoadedHistory = true
            let scopeKey = historyScopeKey(for: kind)
            self.loadedHistoryScopes.insert(scopeKey)
            self.loadedHistoryCounts[scopeKey] = max(
                minimumCount,
                max(loadedHistoryCounts[scopeKey] ?? 0, historyEntryCount(for: kind))
            )
            self.lastHistoryRefreshDates[scopeKey] = Date()
        } catch {
            activeAlert = AppAlert(
                title: "Something Went Wrong",
                message: error.localizedDescription
            )
        }

        historyPreparationMessage = nil
        isRefreshingHistory = false
    }

    func clearHistory() async {
        historyStore.clear()
        hasLoadedHistory = true
        loadedHistoryScopes = []
        loadedHistoryCounts = [:]
        lastHistoryRefreshDates = [:]
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
            currentSearchQuery = ""
            searchResults = SearchResults()
            return
        }

        currentSearchQuery = query
        historyPreparationTask?.cancel()
        historyPreparationTask = nil
        historyPreparationMessage = nil

        await perform("Searching library") { [self] in
            let session = try self.requireSession()
            guard self.validateSession(session) else { return }
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
        var resolvedURL: URL?
        let historyEntry = HistoryEntry(
            kind: .article,
            title: article.title,
            subtitle: article.journalName,
            detail: article.issueTitle,
            urlString: "",
            coverURLString: LegacyConfig.issueCoverCandidates(
                journal: article.journalName,
                issue: article.issueTitle
            ).first?.absoluteString ?? "",
            reference: .article(journal: article.journalName, folder: article.folder, pdfLink: article.pdfLink)
        )

        await perform("Opening article") { [self] in
            let url = try await self.assetLibrary.articleURL(for: article) { progress in
                self.loadingTitle = "Downloading article"
                self.loadingDetail = progress.detailText
                self.loadingProgress = progress.fractionCompleted
            }
            self.historyStore.add(historyEntry.updating(urlString: url.path))
            resolvedURL = url
        }

        if let resolvedURL {
            activeVideo = nil
            activeDocument = DocumentPresentation(title: article.title, url: resolvedURL)
            enqueueArticleOpenEvent(article, historyEntry: historyEntry.updating(urlString: resolvedURL.path), email: session.email)
        }
    }

    func openChapter(_ chapter: Chapter) async {
        guard let session else { return }
        guard validateSession(session) else { return }
        var resolvedURL: URL?
        let historyEntry = HistoryEntry(
            kind: .chapter,
            title: chapter.title,
            subtitle: chapter.bookTitle,
            detail: chapter.editors,
            urlString: "",
            coverURLString: LegacyConfig.bookCoverCandidates(isbn: chapter.isbn).first?.absoluteString ?? "",
            reference: .chapter(isbn: chapter.isbn, pdfLink: chapter.pdfLink)
        )

        await perform("Opening chapter") { [self] in
            let url = try await self.assetLibrary.chapterURL(for: chapter) { progress in
                self.loadingTitle = "Downloading chapter"
                self.loadingDetail = progress.detailText
                self.loadingProgress = progress.fractionCompleted
            }
            self.historyStore.add(historyEntry.updating(urlString: url.path))
            resolvedURL = url
        }

        if let resolvedURL {
            activeVideo = nil
            activeDocument = DocumentPresentation(title: chapter.title, url: resolvedURL)
            recordOpenEvent {
                await self.repository.recordChapterOpen(chapter, email: session.email)
            }
        }
    }

    func playVideo(_ video: Video) async {
        await playVideo(video, railContext: .source)
    }

    func playVideoFromSearch(_ video: Video, scope: SearchVideoRailScope = .all) async {
        await playVideo(video, railContext: .search(scope))
    }

    private func playVideo(_ video: Video, railContext: VideoRailContext) async {
        guard let session else { return }
        guard validateSession(session) else { return }
        guard let remoteURL = LegacyConfig.videoRemoteURL(bookJournal: video.bookJournal, link: video.remoteLink) else {
            activeAlert = AppAlert(title: "Video URL Error", message: "The video link could not be created.")
            return
        }
        let playbackURL = videoDownloadManager.playbackURL(for: remoteURL)

        historyStore.add(
            HistoryEntry(
                kind: .video,
                title: video.title,
                subtitle: video.bookJournal,
                detail: video.author,
                urlString: remoteURL.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: video.imageLink).first?.absoluteString ?? "",
                reference: .video(bookJournal: video.bookJournal, link: video.remoteLink)
            )
        )
        activeDocument = nil
        recordOpenEvent {
            await self.repository.recordVideoOpen(video, email: session.email)
        }
        switch railContext {
        case .source:
            let relatedVideos = await resolveRelatedVideos(for: video, session: session)
            activeVideo = makeVideoPresentation(for: video, url: playbackURL, relatedVideos: relatedVideos)
        case .search(let scope):
            activeVideo = makeSearchVideoPresentation(
                currentItem: makeVideoRailItem(for: video, url: playbackURL),
                scope: scope
            )
        }
    }

    func openVideoSetEntryFromSearch(_ entry: VideoSetEntry, scope: SearchVideoRailScope = .all) async {
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

            await playVideoSetEntry(entry, from: resolvedSet, railContext: .search(scope))
        } catch {
            activeAlert = AppAlert(
                title: "Something Went Wrong",
                message: error.localizedDescription
            )
        }
    }

    func playVideoSetEntry(_ entry: VideoSetEntry, from set: VideoSet) async {
        await playVideoSetEntry(entry, from: set, railContext: .source)
    }

    private func playVideoSetEntry(
        _ entry: VideoSetEntry,
        from set: VideoSet,
        railContext: VideoRailContext
    ) async {
        guard let session else { return }
        guard validateSession(session) else { return }
        guard set.isAccessible(for: session.userID) else {
            activeAlert = AppAlert(title: "Access Limited", message: "Your membership is not allowed to open this video set.")
            return
        }
        guard let remoteURL = LegacyConfig.videoSetRemoteURL(setName: entry.setName, link: entry.remoteLink) else {
            activeAlert = AppAlert(title: "Video URL Error", message: "The video link could not be created.")
            return
        }
        let playbackURL = videoDownloadManager.playbackURL(for: remoteURL)

        historyStore.add(
            HistoryEntry(
                kind: .videoSet,
                title: entry.title,
                subtitle: entry.setName,
                detail: entry.author,
                urlString: remoteURL.absoluteString,
                coverURLString: LegacyConfig.videoCoverCandidates(name: entry.imageLink).first?.absoluteString ?? "",
                reference: .videoSet(setName: entry.setName, link: entry.remoteLink)
            )
        )
        activeDocument = nil
        recordOpenEvent {
            await self.repository.recordVideoSetOpen(setName: set.setName, entry: entry, email: session.email)
        }
        switch railContext {
        case .source:
            let relatedEntries = await resolveRelatedVideoSetEntries(for: entry)
            activeVideo = makeVideoPresentation(for: entry, url: playbackURL, relatedEntries: relatedEntries)
        case .search(let scope):
            activeVideo = makeSearchVideoPresentation(
                currentItem: makeVideoRailItem(for: entry, url: playbackURL),
                scope: scope
            )
        }
    }

    func playDownloadedVideo(
        _ item: DownloadedVideoItem,
        context: [DownloadedVideoItem]? = nil,
        railTitle: String = "Downloaded content",
        railSubtitle: String = "Available offline"
    ) {
        if let session, !validateSession(session) {
            return
        }

        let railItems = (context ?? videoDownloadManager.downloadedItems())
            .map(\.railItem)

        activeDocument = nil
        activeVideo = makeVideoPresentation(
            currentItem: item.railItem,
            railItems: railItems,
            railTitle: railTitle,
            railSubtitle: railSubtitle
        )
    }

    func reopenHistoryEntry(_ entry: HistoryEntry, historyContext: [HistoryEntry]? = nil) async {
        switch entry.kind {
        case .article, .chapter:
            if FileManager.default.fileExists(atPath: entry.urlString) {
                let url = URL(fileURLWithPath: entry.urlString)
                activeVideo = nil
                activeDocument = DocumentPresentation(title: entry.title, url: url)
                return
            }
            var resolvedURL: URL?

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
                resolvedURL = localURL
            }

            if let resolvedURL {
                activeVideo = nil
                activeDocument = DocumentPresentation(title: entry.title, url: resolvedURL)
            }
        case .video, .videoSet:
            if let url = URL(string: entry.urlString), !entry.urlString.isEmpty {
                activeDocument = nil
                if let historyContext, !historyContext.isEmpty {
                    activeVideo = makeHistoryContextVideoPresentation(
                        for: entry,
                        reference: entry.reference,
                        url: url,
                        historyContext: historyContext
                    )
                } else {
                    activeVideo = await makeHistoryVideoPresentation(
                        for: entry,
                        reference: entry.reference,
                        url: url,
                        session: session
                    )
                }
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
                if let historyContext, !historyContext.isEmpty {
                    self.activeVideo = self.makeHistoryContextVideoPresentation(
                        for: entry,
                        reference: reference,
                        url: url,
                        historyContext: historyContext
                    )
                } else {
                    self.activeVideo = await self.makeHistoryVideoPresentation(
                        for: entry,
                        reference: reference,
                        url: url,
                        session: self.session
                    )
                }
            }
        }
    }

    private func makeVideoPresentation(for video: Video, url: URL, relatedVideos: [Video]) -> VideoPresentation {
        let currentItem = makeVideoRailItem(for: video, url: url)
        return makeVideoPresentation(
            currentItem: currentItem,
            railItems: relatedVideos.map { makeVideoRailItem(for: $0) },
            railTitle: "More from this source",
            railSubtitle: video.bookJournal
        )
    }

    private func makeVideoPresentation(
        for entry: VideoSetEntry,
        url: URL,
        relatedEntries: [VideoSetEntry]
    ) -> VideoPresentation {
        let currentItem = makeVideoRailItem(for: entry, url: url)
        return makeVideoPresentation(
            currentItem: currentItem,
            railItems: relatedEntries.map { makeVideoRailItem(for: $0) },
            railTitle: "More in this set",
            railSubtitle: entry.setName
        )
    }

    private func makeHistoryVideoPresentation(
        for entry: HistoryEntry,
        reference: HistoryReference?,
        url: URL,
        session: SessionInfo?
    ) async -> VideoPresentation {
        guard let reference else {
            let fallbackItem = makeVideoRailItem(for: entry, reference: nil, url: url)
            return makeVideoPresentation(
                currentItem: fallbackItem,
                railItems: [fallbackItem],
                railTitle: "More videos",
                railSubtitle: fallbackItem.sourceName
            )
        }

        switch reference.kind {
        case .video:
            let relatedVideos = if let session {
                await resolveRelatedVideos(
                    sourceName: reference.primary,
                    session: session,
                    preferredVideo: nil
                )
            } else {
                localRelatedVideos(sourceName: reference.primary)
            }

            if let matchedVideo = relatedVideos.first(where: { $0.remoteLink == reference.secondary }) {
                return makeVideoPresentation(for: matchedVideo, url: url, relatedVideos: relatedVideos)
            }

            let fallbackItem = makeVideoRailItem(for: entry, reference: reference, url: url)
            return makeVideoPresentation(
                currentItem: fallbackItem,
                railItems: relatedVideos.map { makeVideoRailItem(for: $0) },
                railTitle: "More from this source",
                railSubtitle: fallbackItem.sourceName
            )
        case .videoSet:
            let relatedEntries = await resolveRelatedVideoSetEntries(
                setName: reference.primary,
                preferredEntry: nil
            )

            if let matchedEntry = relatedEntries.first(where: { $0.remoteLink == reference.secondary }) {
                return makeVideoPresentation(for: matchedEntry, url: url, relatedEntries: relatedEntries)
            }

            let fallbackItem = makeVideoRailItem(for: entry, reference: reference, url: url)
            return makeVideoPresentation(
                currentItem: fallbackItem,
                railItems: relatedEntries.map { makeVideoRailItem(for: $0) },
                railTitle: "More in this set",
                railSubtitle: fallbackItem.sourceName
            )
        case .article, .chapter:
            let fallbackItem = makeVideoRailItem(for: entry, reference: reference, url: url)
            return makeVideoPresentation(
                currentItem: fallbackItem,
                railItems: [fallbackItem],
                railTitle: "More videos",
                railSubtitle: fallbackItem.sourceName
            )
        }
    }

    private func makeHistoryContextVideoPresentation(
        for entry: HistoryEntry,
        reference: HistoryReference?,
        url: URL,
        historyContext: [HistoryEntry]
    ) -> VideoPresentation {
        let currentItem = makeVideoRailItem(for: entry, reference: reference, url: url)
        let railItems = historyContext.compactMap { contextEntry -> VideoRailItem? in
            guard contextEntry.kind == .video || contextEntry.kind == .videoSet else { return nil }
            guard let resolved = resolvedHistoryVideoPayload(for: contextEntry) else { return nil }
            return makeVideoRailItem(
                for: contextEntry,
                reference: resolved.reference,
                url: resolved.url
            )
        }

        return makeVideoPresentation(
            currentItem: currentItem,
            railItems: railItems,
            railTitle: "Recently opened videos",
            railSubtitle: "History"
        )
    }

    private func makeVideoPresentation(
        currentItem: VideoRailItem,
        railItems: [VideoRailItem],
        railTitle: String,
        railSubtitle: String
    ) -> VideoPresentation {
        VideoPresentation(
            currentItem: currentItem,
            railTitle: railTitle,
            railSubtitle: railSubtitle,
            railItems: mergeUniqueItems(
                primary: railItems,
                secondary: [],
                preferredItem: currentItem
            )
        )
    }

    private func makeSearchVideoPresentation(
        currentItem: VideoRailItem,
        scope: SearchVideoRailScope
    ) -> VideoPresentation {
        makeVideoPresentation(
            currentItem: currentItem,
            railItems: searchRailItems(for: scope),
            railTitle: "Search results",
            railSubtitle: currentSearchQuery.isEmpty ? "Matching videos" : currentSearchQuery
        )
    }

    private func makeVideoRailItem(for video: Video, url: URL? = nil) -> VideoRailItem {
        let remoteURL = LegacyConfig.videoRemoteURL(bookJournal: video.bookJournal, link: video.remoteLink)
            ?? URL(fileURLWithPath: "/")
        return VideoRailItem(
            id: video.id,
            title: video.title,
            subtitle: video.bookJournal,
            detail: [video.author, video.editor].filter { !$0.isEmpty }.joined(separator: " • "),
            url: url ?? videoDownloadManager.playbackURL(for: remoteURL),
            remoteURL: remoteURL,
            artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
            sourceKind: .library,
            sourceName: video.bookJournal,
            sourceDetail: [video.author, video.editor].filter { !$0.isEmpty }.joined(separator: " • ")
        )
    }

    private func makeVideoRailItem(for entry: VideoSetEntry, url: URL? = nil) -> VideoRailItem {
        let remoteURL = LegacyConfig.videoSetRemoteURL(setName: entry.setName, link: entry.remoteLink)
            ?? URL(fileURLWithPath: "/")
        return VideoRailItem(
            id: entry.id,
            title: entry.title,
            subtitle: entry.setName,
            detail: [entry.author, entry.editor].filter { !$0.isEmpty }.joined(separator: " • "),
            url: url ?? videoDownloadManager.playbackURL(for: remoteURL),
            remoteURL: remoteURL,
            artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
            sourceKind: .set,
            sourceName: entry.setName,
            sourceDetail: [entry.author, entry.editor].filter { !$0.isEmpty }.joined(separator: " • ")
        )
    }

    private func makeVideoRailItem(
        for entry: HistoryEntry,
        reference: HistoryReference?,
        url: URL
    ) -> VideoRailItem {
        let kind: VideoSourceKind
        switch reference?.kind ?? entry.kind {
        case .videoSet:
            kind = .set
        case .video:
            kind = .library
        default:
            kind = .library
        }

        let sourceName = {
            let candidate = reference?.primary ?? entry.subtitle
            return candidate.isEmpty ? "Unknown source" : candidate
        }()

        let artworkURLs = URL(string: entry.coverURLString).map { [$0] } ?? []
        let remoteURL = {
            switch reference?.kind {
            case .video:
                return LegacyConfig.videoRemoteURL(bookJournal: reference?.primary ?? "", link: reference?.secondary ?? "")
            case .videoSet:
                return LegacyConfig.videoSetRemoteURL(setName: reference?.primary ?? "", link: reference?.secondary ?? "")
            default:
                if url.isFileURL {
                    return nil
                }
                return url
            }
        }() ?? url
        let playbackURL = remoteURL.isFileURL ? remoteURL : videoDownloadManager.playbackURL(for: remoteURL)

        return VideoRailItem(
            id: [sourceName, entry.title, remoteURL.absoluteString].joined(separator: "|"),
            title: entry.title,
            subtitle: sourceName,
            detail: entry.detail,
            url: playbackURL,
            remoteURL: remoteURL,
            artworkURLs: artworkURLs,
            sourceKind: kind,
            sourceName: sourceName,
            sourceDetail: entry.detail
        )
    }

    private func resolvedHistoryVideoPayload(
        for entry: HistoryEntry
    ) -> (url: URL, reference: HistoryReference?)? {
        if let directURL = URL(string: entry.urlString), !entry.urlString.isEmpty {
            return (directURL, entry.reference)
        }

        guard let reference = entry.reference else { return nil }
        let resolvedURL: URL?
        switch reference.kind {
        case .video:
            resolvedURL = LegacyConfig.videoRemoteURL(
                bookJournal: reference.primary,
                link: reference.secondary
            )
        case .videoSet:
            resolvedURL = LegacyConfig.videoSetRemoteURL(
                setName: reference.primary,
                link: reference.secondary
            )
        case .article, .chapter:
            resolvedURL = nil
        }

        guard let resolvedURL else { return nil }
        return (resolvedURL, reference)
    }

    private func resolveRelatedVideos(for video: Video, session: SessionInfo) async -> [Video] {
        await resolveRelatedVideos(sourceName: video.bookJournal, session: session, preferredVideo: video)
    }

    private func resolveRelatedVideos(
        sourceName: String,
        session: SessionInfo,
        preferredVideo: Video?
    ) async -> [Video] {
        let localMatches = localRelatedVideos(sourceName: sourceName)
        if localMatches.count > 1 {
            return mergeUniqueItems(primary: localMatches, secondary: [], preferredItem: preferredVideo)
        }

        do {
            let fetchedVideos = try await repository.fetchVideos(bookJournal: sourceName, subject: session.subject)
            return mergeUniqueItems(primary: fetchedVideos, secondary: localMatches, preferredItem: preferredVideo)
        } catch {
            return mergeUniqueItems(primary: localMatches, secondary: [], preferredItem: preferredVideo)
        }
    }

    private func resolveRelatedVideoSetEntries(for entry: VideoSetEntry) async -> [VideoSetEntry] {
        await resolveRelatedVideoSetEntries(setName: entry.setName, preferredEntry: entry)
    }

    private func resolveRelatedVideoSetEntries(
        setName: String,
        preferredEntry: VideoSetEntry?
    ) async -> [VideoSetEntry] {
        let localMatches = localRelatedVideoSetEntries(setName: setName)
        if localMatches.count > 1 {
            return mergeUniqueItems(primary: localMatches, secondary: [], preferredItem: preferredEntry)
        }

        do {
            let fetchedEntries = try await repository.fetchVideoSetEntries(setName: setName)
            return mergeUniqueItems(primary: fetchedEntries, secondary: localMatches, preferredItem: preferredEntry)
        } catch {
            return mergeUniqueItems(primary: localMatches, secondary: [], preferredItem: preferredEntry)
        }
    }

    private func localRelatedVideos(sourceName: String) -> [Video] {
        let normalizedSourceName = sourceName.normalizedSearchKey()
        let combinedVideos = videos + searchResults.videos

        return mergeUniqueItems(
            primary: combinedVideos.filter { $0.bookJournal.normalizedSearchKey() == normalizedSourceName },
            secondary: [],
            preferredItem: nil as Video?
        )
    }

    private func localRelatedVideoSetEntries(setName: String) -> [VideoSetEntry] {
        let normalizedSetName = setName.normalizedSearchKey()
        let combinedEntries = videoSetEntries + searchResults.videoSetEntries

        return mergeUniqueItems(
            primary: combinedEntries.filter { $0.setName.normalizedSearchKey() == normalizedSetName },
            secondary: [],
            preferredItem: nil as VideoSetEntry?
        )
    }

    private func searchRailItems(for scope: SearchVideoRailScope) -> [VideoRailItem] {
        let candidates: [SearchVideoRailCandidate]
        switch scope {
        case .all:
            candidates =
                searchResults.videos.map(SearchVideoRailCandidate.video)
                + searchResults.videoSetEntries.map(SearchVideoRailCandidate.videoSet)
        case .videos:
            candidates = searchResults.videos.map(SearchVideoRailCandidate.video)
        case .videoSets:
            candidates = searchResults.videoSetEntries.map(SearchVideoRailCandidate.videoSet)
        }

        return candidates
            .sorted { $0.sortDate > $1.sortDate }
            .map { candidate in
                switch candidate {
                case .video(let video):
                    return makeVideoRailItem(for: video)
                case .videoSet(let entry):
                    return makeVideoRailItem(for: entry)
                }
            }
    }

    private func mergeUniqueItems<Item: Identifiable>(
        primary: [Item],
        secondary: [Item],
        preferredItem: Item?
    ) -> [Item] where Item.ID: Hashable {
        var seenIDs = Set<Item.ID>()
        var merged: [Item] = []

        for item in primary + secondary {
            if seenIDs.insert(item.id).inserted {
                merged.append(item)
            }
        }

        if let preferredItem, seenIDs.insert(preferredItem.id).inserted {
            merged.insert(preferredItem, at: 0)
        }

        return merged
    }

    func logout() {
        sessionStore.clear()
        session = nil
        historyStore.replace(with: [])
        openEventStore.clear()
        resetRemoteContent()
        selectedSection = .dashboard
    }

    func handleAppDidBecomeActive() {
        syncPendingOpenEventsInBackground()
        if selectedSection == .history {
            prepareHistoryInBackgroundIfNeeded()
        }
    }

    func prepareHistoryInBackgroundIfNeeded(
        kind: HistoryKind? = nil,
        minimumCount: Int = 50,
        force: Bool = false
    ) {
        guard session != nil else { return }
        guard
            force
                || shouldPrepareHistory(kind: kind, minimumCount: minimumCount)
                || shouldAutoRefreshHistory(kind: kind)
        else { return }
        guard !isRefreshingHistory else { return }

        historyPreparationTask?.cancel()
        historyPreparationTask = Task(priority: .utility) {
            await self.refreshHistory(kind: kind, minimumCount: minimumCount, force: true)
        }
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
        historyPreparationTask?.cancel()
        historyPreparationTask = nil
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
        loadedHistoryScopes = []
        loadedHistoryCounts = [:]
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

    private func recordOpenEvent(_ operation: @escaping @MainActor () async -> Void) {
        Task(priority: .utility) {
            await operation()
        }
    }

    private func enqueueArticleOpenEvent(_ article: Article, historyEntry: HistoryEntry, email: String) {
        let payload = PendingArticleOpenPayload(article: article, email: email)
        openEventStore.enqueue(.article(payload: payload, historyEntry: historyEntry))
        syncPendingOpenEventsInBackground()
        schedulePendingOpenEventRetry()
    }

    private func mergeHistoryEntries(_ serverEntries: [HistoryEntry], kind: HistoryKind?, email: String) -> [HistoryEntry] {
        let localPendingEntries = openEventStore.historyEntriesForMerge(email: email, kind: kind)
        let existingLocalEntries: [HistoryEntry]
        if let kind {
            existingLocalEntries = historyStore.entries.filter { $0.kind == kind }
        } else {
            existingLocalEntries = historyStore.entries
        }

        return (serverEntries + localPendingEntries + existingLocalEntries)
            .sorted { $0.openedAt > $1.openedAt }
    }

    private func shouldPrepareHistory(kind: HistoryKind?, minimumCount: Int) -> Bool {
        if !hasLoadedHistory {
            return true
        }
        let scopeKey = historyScopeKey(for: kind)
        let availableCount = historyEntryCount(for: kind)
        let loadedCount = loadedHistoryCounts[scopeKey] ?? 0

        if !loadedHistoryScopes.contains(scopeKey) {
            return true
        }

        return max(availableCount, loadedCount) < minimumCount
    }

    private func historyEntryCount(for kind: HistoryKind?) -> Int {
        guard let kind else { return historyStore.entries.count }
        return historyStore.entries.filter { $0.kind == kind }.count
    }

    private func historyMessage(for kind: HistoryKind?, minimumCount: Int) -> String {
        let scopeTitle = kind?.title ?? "History"
        return "\(scopeTitle) is refreshing in the background. The first \(minimumCount) records appear first, then more arrive as you scroll."
    }

    private func shouldAutoRefreshHistory(kind: HistoryKind?) -> Bool {
        let scopeKey = historyScopeKey(for: kind)
        guard let lastRefreshDate = lastHistoryRefreshDates[scopeKey] else { return true }
        return Date().timeIntervalSince(lastRefreshDate) >= historyAutoRefreshInterval
    }

    private func historyScopeKey(for kind: HistoryKind?) -> String {
        kind?.rawValue ?? "all"
    }

    private func syncPendingOpenEventsInBackground() {
        guard let email = session?.email else { return }
        Task(priority: .utility) {
            await self.openEventSyncService.flushPendingEvents(
                email: email,
                store: self.openEventStore,
                repository: self.repository
            )
        }
    }

    private func schedulePendingOpenEventRetry() {
        Task(priority: .background) { @MainActor in
            try? await Task.sleep(for: .seconds(15))
            self.syncPendingOpenEventsInBackground()
        }
    }
}
