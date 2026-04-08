import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var activeFavoriteBook: Book?
    @State private var activeFavoriteVideoSet: VideoSet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionCard {
                    HStack {
                        ScreenHeader(
                            eyebrow: "Profile",
                            title: "Usage & Favorites",
                            subtitle: "Remote usage counts from the legacy server, plus the new local favorites summary."
                        )
                        Spacer()
                        Button("Refresh Stats") {
                            Task { await appState.refreshProfile() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                    }
                }

                if let profile = appState.profile {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 14) {
                                metricButton(label: "Articles Opened", value: profile.articleCount, tint: Palette.accent) {
                                    toggleDetail(.articleHistory)
                                }
                                metricButton(label: "Chapters Opened", value: profile.chapterCount, tint: Palette.highlight) {
                                    toggleDetail(.chapterHistory)
                                }
                                metricButton(label: "Videos Opened", value: profile.videoCount, tint: Palette.gold) {
                                    toggleDetail(.videoHistory)
                                }
                                metricButton(label: "Set Videos Opened", value: profile.videoSetCount, tint: Palette.accent) {
                                    toggleDetail(.videoSetHistory)
                                }
                            }

                            HStack(spacing: 14) {
                                metricButton(label: "Favorite Journals", value: profile.favoriteJournalCount, tint: Palette.accent) {
                                    toggleDetail(.favoriteJournals)
                                }
                                metricButton(label: "Favorite Books", value: profile.favoriteBookCount, tint: Palette.highlight) {
                                    toggleDetail(.favoriteBooks)
                                }
                                metricButton(label: "Favorite Sets", value: profile.favoriteVideoSetCount, tint: Palette.gold) {
                                    toggleDetail(.favoriteVideoSets)
                                }
                            }
                        }
                    }

                    if let activeFavoriteBook {
                        SectionCard {
                            BookChaptersPage(
                                book: activeFavoriteBook,
                                backTitle: "Back To Favorite Books",
                                onBack: {
                                    self.activeFavoriteBook = nil
                                }
                            )
                            .environmentObject(appState)
                        }
                    } else if let activeFavoriteVideoSet {
                        SectionCard {
                            VideoSetDetailPage(
                                set: activeFavoriteVideoSet,
                                backTitle: "Back To Favorite Sets",
                                onBack: {
                                    self.activeFavoriteVideoSet = nil
                                }
                            )
                            .environmentObject(appState)
                        }
                    } else if let selectedDetailSection {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(selectedDetailSection.title)
                                            .font(.custom("Avenir Next Demi Bold", size: 24))
                                        Text(selectedDetailSection.subtitle)
                                            .font(.custom("Avenir Next Regular", size: 14))
                                            .foregroundStyle(Palette.muted)
                                    }

                                    Spacer()

                                    StatusPill(
                                        text: "\(detailItemCount(for: selectedDetailSection)) items",
                                        tint: Palette.accent
                                    )

                                    Button("Hide") {
                                        appState.profileSelectedDetailSectionRawValue = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Palette.accent)
                                }

                                detailContent(for: selectedDetailSection)
                            }
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(label: "E-mail", value: profile.email)
                            infoRow(label: "User ID", value: profile.userID)
                            infoRow(label: "Subject", value: profile.subject)
                            infoRow(label: "Access Until", value: profile.expireDate)
                            infoRow(label: "Serial", value: profile.serial)
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Profile is not ready yet",
                        message: "Refresh the stats to pull your account information from the legacy server.",
                        symbolName: "person.text.rectangle"
                    )
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .frame(width: 120, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.custom("Avenir Next Regular", size: 14))
                .foregroundStyle(Palette.muted)
        }
    }

    private func metricButton(label: String, value: Int, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MetricChip(label: label, value: value, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func toggleDetail(_ section: ProfileDetailSection) {
        if selectedDetailSection == section {
            activeFavoriteBook = nil
            activeFavoriteVideoSet = nil
            appState.profileSelectedDetailSectionRawValue = nil
            return
        }

        activeFavoriteBook = nil
        activeFavoriteVideoSet = nil
        appState.profileSelectedDetailSectionRawValue = section.rawValue

        Task {
            await prepareDetail(section)
        }
    }

    private var selectedDetailSection: ProfileDetailSection? {
        appState.profileSelectedDetailSectionRawValue.flatMap(ProfileDetailSection.init(rawValue:))
    }

    private func prepareDetail(_ section: ProfileDetailSection) async {
        switch section {
        case .articleHistory:
            if articleHistoryEntries.isEmpty {
                await appState.refreshHistory(kind: .article)
            }
        case .chapterHistory:
            if chapterHistoryEntries.isEmpty {
                await appState.refreshHistory(kind: .chapter)
            }
        case .videoHistory:
            if videoHistoryEntries.isEmpty {
                await appState.refreshHistory(kind: .video)
            }
        case .videoSetHistory:
            if videoSetHistoryEntries.isEmpty {
                await appState.refreshHistory(kind: .videoSet)
            }
        case .favoriteJournals:
            if favoriteJournals.isEmpty {
                await appState.loadJournals()
            }
        case .favoriteBooks:
            if favoriteBooks.isEmpty {
                await appState.loadBooks()
            }
        case .favoriteVideoSets:
            if favoriteVideoSets.isEmpty {
                await appState.loadVideoSetsForProfile()
            }
        }
    }

    @ViewBuilder
    private func detailContent(for section: ProfileDetailSection) -> some View {
        switch section {
        case .articleHistory:
            historyList(entries: articleHistoryEntries, emptyTitle: "No article history yet")
        case .chapterHistory:
            historyList(entries: chapterHistoryEntries, emptyTitle: "No chapter history yet")
        case .videoHistory:
            historyList(entries: videoHistoryEntries, emptyTitle: "No video history yet")
        case .videoSetHistory:
            historyList(entries: videoSetHistoryEntries, emptyTitle: "No video set history yet")
        case .favoriteJournals:
            favoritesJournalList
        case .favoriteBooks:
            favoritesBookList
        case .favoriteVideoSets:
            favoritesVideoSetList
        }
    }

    private func detailItemCount(for section: ProfileDetailSection) -> Int {
        switch section {
        case .articleHistory:
            return articleHistoryEntries.count
        case .chapterHistory:
            return chapterHistoryEntries.count
        case .videoHistory:
            return videoHistoryEntries.count
        case .videoSetHistory:
            return videoSetHistoryEntries.count
        case .favoriteJournals:
            return favoriteJournals.count
        case .favoriteBooks:
            return favoriteBooks.count
        case .favoriteVideoSets:
            return favoriteVideoSets.count
        }
    }

    private var articleHistoryEntries: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .article }
    }

    private var chapterHistoryEntries: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .chapter }
    }

    private var videoHistoryEntries: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .video }
    }

    private var videoSetHistoryEntries: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .videoSet }
    }

    private var favoriteJournals: [Journal] {
        appState.journals.filter { appState.favoritesStore.isFavorite(journal: $0) }
    }

    private var favoriteBooks: [Book] {
        appState.books.filter { appState.favoritesStore.isFavorite(book: $0) }
    }

    private var favoriteVideoSets: [VideoSet] {
        appState.videoSets.filter { appState.favoritesStore.isFavorite(videoSet: $0) }
    }

    @ViewBuilder
    private func historyList(entries: [HistoryEntry], emptyTitle: String) -> some View {
        if entries.isEmpty {
            EmptyStateView(
                title: emptyTitle,
                message: "Tap the matching metric after opening content to surface recent items here.",
                symbolName: "clock.arrow.circlepath"
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(entries, id: \.id) { entry in
                    Button {
                        Task { await appState.reopenHistoryEntry(entry) }
                    } label: {
                        CompactMediaRowCard(
                            artworkURLs: historyArtworkURLs(for: entry),
                            title: entry.title,
                            playbackRecord: playbackRecord(for: entry)
                        ) {
                            Text(entry.subtitle)
                                .font(.custom("Avenir Next Medium", size: 11))
                                .foregroundStyle(Palette.muted)
                                .lineLimit(1)

                            if !entry.detail.isEmpty {
                                Text(entry.detail)
                                    .font(.custom("Avenir Next Regular", size: 10))
                                    .foregroundStyle(Palette.highlight)
                                    .lineLimit(2)
                            }
                        } footer: {
                            HStack(spacing: 8) {
                                StatusPill(text: entry.kind.title, tint: Palette.accent)
                                Spacer()
                                Text(LegacyDate.relativeFormatter.localizedString(for: entry.openedAt, relativeTo: Date()))
                                    .font(.custom("Avenir Next Regular", size: 11))
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func playbackRecord(for entry: HistoryEntry) -> VideoPlaybackRecord? {
        switch entry.kind {
        case .video, .videoSet:
            break
        case .article, .chapter:
            return nil
        }

        if let directURL = URL(string: entry.urlString),
           directURL.scheme != nil,
           !directURL.isFileURL {
            return videoPlaybackStore.record(forRemoteURL: directURL)
        }

        guard let reference = entry.reference else { return nil }
        let remoteURL: URL?
        switch reference.kind {
        case .video:
            remoteURL = LegacyConfig.videoRemoteURL(bookJournal: reference.primary, link: reference.secondary)
        case .videoSet:
            remoteURL = LegacyConfig.videoSetRemoteURL(setName: reference.primary, link: reference.secondary)
        case .article, .chapter:
            remoteURL = nil
        }

        guard let remoteURL else { return nil }
        return videoPlaybackStore.record(forRemoteURL: remoteURL)
    }

    @ViewBuilder
    private var favoritesJournalList: some View {
        if favoriteJournals.isEmpty {
            EmptyStateView(
                title: "No favorite journals yet",
                message: "Star journals in the library and they will appear here.",
                symbolName: "star"
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(favoriteJournals, id: \.id) { journal in
                    CompactMediaRowCard(
                        artworkURLs: LegacyConfig.coverCandidates(for: journal.name),
                        title: journal.name,
                        favoriteSelected: appState.favoritesStore.isFavorite(journal: journal),
                        favoriteAction: { appState.favoritesStore.toggleJournal(journal) }
                    ) {
                        Text(journal.issn.isEmpty ? "ISSN unavailable" : journal.issn)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)

                        if !journal.subject.isEmpty {
                            Text(journal.subject)
                                .font(.custom("Avenir Next Medium", size: 10))
                                .foregroundStyle(Palette.highlight)
                                .lineLimit(2)
                        }
                    } footer: {
                        HStack(spacing: 10) {
                            StatusPill(text: "Favorite Journal", tint: Palette.accent)
                            Spacer()
                            Button("Open Journal") {
                                Task { await appState.showProfileJournal(journal) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Palette.accent)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var favoritesBookList: some View {
        if favoriteBooks.isEmpty {
            EmptyStateView(
                title: "No favorite books yet",
                message: "Star books in the library and they will appear here.",
                symbolName: "star"
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(favoriteBooks, id: \.id) { book in
                    CompactMediaRowCard(
                        artworkURLs: bookArtworkURLs(for: book),
                        title: book.title,
                        favoriteSelected: appState.favoritesStore.isFavorite(book: book),
                        favoriteAction: { appState.favoritesStore.toggleBook(book) }
                    ) {
                        Text(book.editors)
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)

                        Text([book.year, book.company].filter { !$0.isEmpty }.joined(separator: " • "))
                            .font(.custom("Avenir Next Regular", size: 10))
                            .foregroundStyle(Palette.highlight)
                            .lineLimit(1)
                    } footer: {
                        HStack(spacing: 10) {
                            StatusPill(text: "Favorite Book", tint: Palette.highlight)
                            Spacer()
                            Button("Open Book") {
                                activeFavoriteVideoSet = nil
                                activeFavoriteBook = book
                                Task { await appState.selectBook(book) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Palette.highlight)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var favoritesVideoSetList: some View {
        if favoriteVideoSets.isEmpty {
            EmptyStateView(
                title: "No favorite sets yet",
                message: "Star video sets in the library and they will appear here.",
                symbolName: "star"
            )
        } else {
            LazyVStack(spacing: 14) {
                ForEach(favoriteVideoSets, id: \.id) { set in
                    CompactMediaRowCard(
                        artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
                        title: set.setName,
                        favoriteSelected: appState.favoritesStore.isFavorite(videoSet: set),
                        favoriteAction: { appState.favoritesStore.toggleVideoSet(set) }
                    ) {
                        Text(set.editors.isEmpty ? "Editors unavailable" : set.editors)
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)

                        if !set.subject.isEmpty {
                            Text(set.subject)
                                .font(.custom("Avenir Next Regular", size: 10))
                                .foregroundStyle(Palette.highlight)
                                .lineLimit(1)
                        }
                    } footer: {
                        HStack(spacing: 10) {
                            StatusPill(text: "Favorite Set", tint: Palette.gold)
                            Spacer()
                            Button("Open Set") {
                                activeFavoriteBook = nil
                                activeFavoriteVideoSet = set
                                Task { await appState.selectVideoSet(set) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Palette.gold)
                        }
                    }
                }
            }
        }
    }

    private func historyArtworkURLs(for entry: HistoryEntry) -> [URL] {
        guard let url = URL(string: entry.coverURLString), !entry.coverURLString.isEmpty else { return [] }
        return [url]
    }

    private func bookArtworkURLs(for book: Book) -> [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }
}
