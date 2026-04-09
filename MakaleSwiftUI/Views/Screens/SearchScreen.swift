import SwiftUI

private enum SearchLibraryPage: String, CaseIterable, Identifiable {
    case all
    case journals
    case books
    case videos
    case videoSets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .journals: return "Journal"
        case .books: return "Book"
        case .videos: return "Video"
        case .videoSets: return "Video Set"
        }
    }

    var sectionTitle: String {
        switch self {
        case .all: return "All Results"
        case .journals: return "Journal Results"
        case .books: return "Book Results"
        case .videos: return "Video Results"
        case .videoSets: return "Video Set Results"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "No results across libraries"
        case .journals: return "No journals matched"
        case .books: return "No books matched"
        case .videos: return "No videos matched"
        case .videoSets: return "No video sets matched"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "Try another phrase or jump into a specific library page."
        case .journals: return "Try another keyword or jump to a different library page."
        case .books: return "Use a broader title, editor, or ISBN phrase."
        case .videos: return "Try a title, author, or journal keyword."
        case .videoSets: return "Use a broader collection or editor term."
        }
    }
}

private enum CombinedSearchResultItem: Identifiable {
    case article(Article)
    case chapter(Chapter)
    case video(Video)
    case videoSet(VideoSetEntry)

    var id: String {
        switch self {
        case .article(let article):
            return "article-\(article.id)"
        case .chapter(let chapter):
            return "chapter-\(chapter.id)"
        case .video(let video):
            return "video-\(video.id)"
        case .videoSet(let entry):
            return "videoSet-\(entry.id)"
        }
    }

    var sortDate: Date {
        switch self {
        case .article(let article):
            return article.sortDate ?? .distantPast
        case .chapter(let chapter):
            return chapter.sortDate ?? .distantPast
        case .video(let video):
            return video.sortDate ?? .distantPast
        case .videoSet(let entry):
            return entry.sortDate ?? .distantPast
        }
    }
}

struct SearchScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("search.library.page") private var selectedPageRawValue = SearchLibraryPage.all.rawValue
    @State private var query = ""
    @State private var lastSubmittedQuery = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionCard {
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenHeader(
                            eyebrow: "Search",
                            title: "Cross-library lookup",
                            subtitle: "Search journal articles, book chapters, videos, and video set entries from a single entry point."
                        )

                        HStack(spacing: 10) {
                            SearchInputField(
                                placeholder: "Search title, editor, author, ISBN, or subject",
                                text: $query,
                                onSubmitAction: submitSearch
                            )
                            Button("Search") {
                                submitSearch()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.accent)
                        }

                        HStack(alignment: .center, spacing: 14) {
                            Picker("Library", selection: selectedPageBinding) {
                                ForEach(SearchLibraryPage.allCases) { page in
                                    Text(page.title).tag(page)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 440)

                            Spacer()

                            StatusPill(
                                text: "\(resultsCount(for: selectedPage)) result\(resultsCount(for: selectedPage) == 1 ? "" : "s")",
                                tint: Palette.accent
                            )
                        }
                    }
                }

                if appState.searchResults.isEmpty {
                    EmptyStateView(
                        title: lastSubmittedQuery.isEmpty ? "Start with a keyword" : "No matches found",
                        message: lastSubmittedQuery.isEmpty
                            ? "Use the field above, then switch between All, Journal, Book, Video, and Video Set pages."
                            : "Try another phrase or browse a different library page.",
                        symbolName: lastSubmittedQuery.isEmpty ? "magnifyingglass.circle" : "doc.text.magnifyingglass"
                    )
                } else {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(selectedPage.sectionTitle)
                                    .font(.custom("Avenir Next Bold", size: 20))
                                Spacer()
                                Text(lastSubmittedQuery)
                                    .font(.custom("Avenir Next Medium", size: 12))
                                    .foregroundStyle(Palette.muted)
                            }

                            if resultsCount(for: selectedPage) == 0 {
                                EmptyStateView(
                                    title: selectedPage.emptyTitle,
                                    message: selectedPage.emptyMessage,
                                    symbolName: "rectangle.on.rectangle"
                                )
                            } else {
                                LazyVStack(spacing: 12) {
                                    currentPageContent
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedPageBinding: Binding<SearchLibraryPage> {
        Binding(
            get: { selectedPage },
            set: { selectedPageRawValue = $0.rawValue }
        )
    }

    private var selectedPage: SearchLibraryPage {
        SearchLibraryPage(rawValue: selectedPageRawValue) ?? .all
    }

    @ViewBuilder
    private var currentPageContent: some View {
        switch selectedPage {
        case .all:
            combinedPageContent
        case .journals:
            articleResults
        case .books:
            chapterResults
        case .videos:
            videoResults
        case .videoSets:
            videoSetResults
        }
    }

    @ViewBuilder
    private var combinedPageContent: some View {
        ForEach(combinedResults) { item in
            switch item {
            case .article(let article):
                articleCard(article)
            case .chapter(let chapter):
                chapterCard(chapter)
            case .video(let video):
                videoCard(video)
            case .videoSet(let entry):
                videoSetCard(entry)
            }
        }
    }

    @ViewBuilder
    private var articleResults: some View {
        ForEach(appState.searchResults.articles, id: \.id) { article in
            articleCard(article)
        }
    }

    @ViewBuilder
    private var chapterResults: some View {
        ForEach(appState.searchResults.chapters, id: \.id) { chapter in
            chapterCard(chapter)
        }
    }

    @ViewBuilder
    private var videoResults: some View {
        ForEach(appState.searchResults.videos, id: \.id) { video in
            videoCard(video)
        }
    }

    @ViewBuilder
    private var videoSetResults: some View {
        ForEach(appState.searchResults.videoSetEntries, id: \.id) { entry in
            videoSetCard(entry)
        }
    }

    private func resultsCount(for page: SearchLibraryPage) -> Int {
        switch page {
        case .all:
            return appState.searchResults.articles.count
                + appState.searchResults.chapters.count
                + appState.searchResults.videos.count
                + appState.searchResults.videoSetEntries.count
        case .journals:
            return appState.searchResults.articles.count
        case .books:
            return appState.searchResults.chapters.count
        case .videos:
            return appState.searchResults.videos.count
        case .videoSets:
            return appState.searchResults.videoSetEntries.count
        }
    }

    private func submitSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSubmittedQuery = trimmedQuery
        Task { @MainActor in
            await appState.runSearch(trimmedQuery)
            selectBestPageAfterSearch()
        }
    }

    private func selectBestPageAfterSearch() {
        guard resultsCount(for: selectedPage) == 0 else { return }

        if let firstAvailablePage = SearchLibraryPage.allCases.first(where: { resultsCount(for: $0) > 0 }) {
            selectedPageRawValue = firstAvailablePage.rawValue
        }
    }

    private var combinedResults: [CombinedSearchResultItem] {
        (
            appState.searchResults.articles.map(CombinedSearchResultItem.article)
            + appState.searchResults.chapters.map(CombinedSearchResultItem.chapter)
            + appState.searchResults.videos.map(CombinedSearchResultItem.video)
            + appState.searchResults.videoSetEntries.map(CombinedSearchResultItem.videoSet)
        )
        .sorted { $0.sortDate > $1.sortDate }
    }

    private func articleCard(_ article: Article) -> some View {
        CompactMediaRowCard(
            artworkURLs: LegacyConfig.issueCoverCandidates(
                journal: article.journalName,
                issue: article.issueTitle
            ),
            title: article.title,
            artworkAspectRatio: 0.78,
            artworkWidth: 72,
            artworkHeight: 96,
            titleSize: 14,
            titleLineLimit: 2
        ) {
            Text(article.author.isEmpty ? "Author unavailable" : article.author)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)

            Text([article.journalName, article.issueTitle].filter { !$0.isEmpty }.joined(separator: " • "))
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.highlight)
                .lineLimit(2)
        } footer: {
            cardActionRow(
                leadingText: prefixedMetadata(
                    type: "Article",
                    details: [article.year, article.volume].filter { !$0.isEmpty }
                ),
                buttonTitle: "Open Article"
            ) {
                Task { await appState.openArticle(article) }
            }
        }
    }

    private func chapterCard(_ chapter: Chapter) -> some View {
        CompactMediaRowCard(
            artworkURLs: LegacyConfig.bookCoverCandidates(isbn: chapter.isbn),
            title: chapter.title,
            artworkAspectRatio: 0.82,
            artworkWidth: 74,
            artworkHeight: 98,
            titleSize: 14,
            titleLineLimit: 2
        ) {
            Text(chapter.editors.isEmpty ? "Editor unavailable" : chapter.editors)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)

            Text(chapter.bookTitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.highlight)
                .lineLimit(2)
        } footer: {
            cardActionRow(
                leadingText: prefixedMetadata(
                    type: "Book",
                    details: [chapter.year, chapter.isbn].filter { !$0.isEmpty }
                ),
                buttonTitle: "Open Chapter"
            ) {
                Task { await appState.openChapter(chapter) }
            }
        }
    }

    private func videoCard(_ video: Video) -> some View {
        CompactMediaRowCard(
            artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
            title: video.title,
            artworkAspectRatio: 0.82,
            artworkWidth: 78,
            artworkHeight: 102,
            titleSize: 14,
            titleLineLimit: 2
        ) {
            Text(video.author.isEmpty ? "Author unavailable" : video.author)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

            Text(video.bookJournal)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.highlight)
                .lineLimit(1)
        } footer: {
            cardActionRow(
                leadingText: prefixedMetadata(
                    type: "Video",
                    details: [video.editor].filter { !$0.isEmpty }
                ),
                buttonTitle: "Play Video"
            ) {
                Task { await appState.playVideoFromSearch(video) }
            }
        }
    }

    private func videoSetCard(_ entry: VideoSetEntry) -> some View {
        CompactMediaRowCard(
            artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
            title: entry.title,
            artworkAspectRatio: 0.82,
            artworkWidth: 78,
            artworkHeight: 102,
            titleSize: 14,
            titleLineLimit: 2
        ) {
            Text(entry.author.isEmpty ? "Author unavailable" : entry.author)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)

            Text(entry.setName)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.highlight)
                .lineLimit(1)
        } footer: {
            HStack(spacing: 10) {
                Text(
                    prefixedMetadata(
                        type: "Video Set",
                        details: [entry.editor].filter { !$0.isEmpty }
                    )
                )
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

                Spacer()

                Button("Open Set") {
                    Task { await appState.openVideoSetEntryFromSearch(entry) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.accent)
            }
        }
    }

    private func cardActionRow(
        leadingText: String = "",
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            if !leadingText.isEmpty {
                Text(leadingText)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }

            Spacer()

            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.accent)
        }
    }

    private func prefixedMetadata(type: String, details: [String]) -> String {
        ([type] + details.filter { !$0.isEmpty }).joined(separator: " • ")
    }
}
