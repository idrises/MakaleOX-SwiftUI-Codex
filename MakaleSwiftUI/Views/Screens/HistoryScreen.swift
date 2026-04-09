import SwiftUI

private enum HistoryPage: String, CaseIterable, Identifiable {
    case all
    case articles
    case books
    case videos
    case videoSets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .articles: return "Article"
        case .books: return "Book"
        case .videos: return "Video"
        case .videoSets: return "Video Set"
        }
    }

    var historyKind: HistoryKind? {
        switch self {
        case .all: return nil
        case .articles: return .article
        case .books: return .chapter
        case .videos: return .video
        case .videoSets: return .videoSet
        }
    }
}

struct HistoryScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @AppStorage("history.page") private var selectedPageRawValue = HistoryPage.all.rawValue
    @State private var searchText = ""
    @State private var visibleItemCount = 50
    @State private var requestedFetchCount = 50

    private let pageSize = 50

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            ScreenHeader(
                                eyebrow: "History",
                                title: "Recently opened",
                                subtitle: "A lightweight local history so you can quickly jump back into what you already opened."
                            )
                            Spacer()
                            HStack(spacing: 10) {
                                if appState.session != nil {
                                    Button {
                                        appState.prepareHistoryInBackgroundIfNeeded(
                                            kind: selectedPage.historyKind,
                                            minimumCount: requestedFetchCount,
                                            force: true
                                        )
                                    } label: {
                                        HStack(spacing: 6) {
                                            if appState.isRefreshingHistory {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }
                                            Text(appState.isRefreshingHistory ? "Refreshing" : "Refresh")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(appState.isRefreshingHistory)
                                }

                                if !appState.historyStore.entries.isEmpty {
                                    Button("Clear History", role: .destructive) {
                                        Task { await appState.clearHistory() }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(appState.isRefreshingHistory)
                                }
                            }
                        }

                        Picker("History Category", selection: selectedPageBinding) {
                            ForEach(HistoryPage.allCases) { page in
                                Text(page.title).tag(page)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 440)
                        .controlSize(.small)

                        TextField("Filter title, source, author…", text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        if let historyPreparationMessage = appState.historyPreparationMessage {
                            Label(historyPreparationMessage, systemImage: "arrow.triangle.2.circlepath")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }

                if appState.isRefreshingHistory && pageEntries.isEmpty {
                    EmptyStateView(
                        title: "Preparing history",
                        message: "Recent records are loading in the background. You can stay on this page while they arrive.",
                        symbolName: "clock.arrow.circlepath"
                    )
                } else if filteredEntries.isEmpty {
                    EmptyStateView(
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        symbolName: "clock.badge.questionmark"
                    )
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(visibleEntries) { entry in
                            Button {
                                let historyContext = visibleEntries
                                Task { await appState.reopenHistoryEntry(entry, historyContext: historyContext) }
                            } label: {
                                CompactMediaRowCard(
                                    artworkURLs: coverURLs(for: entry),
                                    title: entry.title,
                                    playbackRecord: playbackRecord(for: entry),
                                    artworkAspectRatio: 1,
                                    artworkWidth: 84,
                                    artworkHeight: 84,
                                    cornerRadius: 16,
                                    cardPadding: 10,
                                    titleSize: 15,
                                    titleLineLimit: 2,
                                    contentSpacing: 5
                                ) {
                                    Text(entry.subtitle)
                                        .font(.custom("Avenir Next Regular", size: 12))
                                        .foregroundStyle(Palette.muted)
                                        .lineLimit(1)

                                    Text(entry.detail)
                                        .font(.custom("Avenir Next Medium", size: 11))
                                        .foregroundStyle(Palette.highlight)
                                        .lineLimit(2)
                                } footer: {
                                    HStack(spacing: 10) {
                                        StatusPill(text: entry.kind.title, tint: Palette.accent)
                                        Spacer()
                                        Text(LegacyDate.historyListFormatter.string(from: entry.openedAt))
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .foregroundStyle(Palette.muted)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                loadMoreIfNeeded(currentEntry: entry)
                            }
                        }

                        if appState.isRefreshingHistory {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .task {
            applyPreferredPageSelection()
            resetPaginationAndPrepareHistory()
        }
        .onChange(of: appState.historyNavigationToken) { _ in
            applyPreferredPageSelection()
            resetPaginationAndPrepareHistory()
        }
        .onChange(of: selectedPageRawValue) { _ in
            resetPaginationAndPrepareHistory()
        }
        .onChange(of: searchText) { _ in
            visibleItemCount = pageSize
        }
    }

    private func coverURLs(for entry: HistoryEntry) -> [URL] {
        guard let url = URL(string: entry.coverURLString) else { return [] }
        return [url]
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

    private var selectedPageBinding: Binding<HistoryPage> {
        Binding(
            get: { selectedPage },
            set: { selectedPageRawValue = $0.rawValue }
        )
    }

    private var selectedPage: HistoryPage {
        HistoryPage(rawValue: selectedPageRawValue) ?? .all
    }

    private var pageEntries: [HistoryEntry] {
        switch selectedPage {
        case .all:
            return appState.historyStore.entries
        case .articles:
            return appState.historyStore.entries.filter { $0.kind == .article }
        case .books:
            return appState.historyStore.entries.filter { $0.kind == .chapter }
        case .videos:
            return appState.historyStore.entries.filter { $0.kind == .video }
        case .videoSets:
            return appState.historyStore.entries.filter { $0.kind == .videoSet }
        }
    }

    private var filteredEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return pageEntries }

        return pageEntries.filter {
            [$0.title, $0.subtitle, $0.detail, $0.kind.title]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var visibleEntries: [HistoryEntry] {
        Array(filteredEntries.prefix(visibleItemCount))
    }

    private var emptyStateTitle: String {
        if hasActiveSearch {
            return "No history matched"
        }

        if appState.historyStore.entries.isEmpty {
            return "History is still empty"
        }

        return "No entries in this category"
    }

    private var emptyStateMessage: String {
        if hasActiveSearch {
            return "Try a different title, source, author, or category filter."
        }

        if appState.historyStore.entries.isEmpty {
            return "Open a PDF or play a video to start building your recent list."
        }

        return "Switch to another category or refresh to load a different slice of history."
    }

    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyPreferredPageSelection() {
        guard HistoryPage(rawValue: appState.preferredHistoryPageRawValue) != nil else { return }
        selectedPageRawValue = appState.preferredHistoryPageRawValue
        searchText = ""
    }

    private func resetPaginationAndPrepareHistory() {
        visibleItemCount = pageSize
        requestedFetchCount = pageSize
        appState.prepareHistoryInBackgroundIfNeeded(
            kind: selectedPage.historyKind,
            minimumCount: requestedFetchCount,
            force: false
        )
    }

    private func loadMoreIfNeeded(currentEntry entry: HistoryEntry) {
        guard visibleEntries.last?.id == entry.id else { return }

        if visibleItemCount < filteredEntries.count {
            visibleItemCount = min(visibleItemCount + pageSize, filteredEntries.count)
        }

        let nextFetchCount = max(visibleItemCount + pageSize, requestedFetchCount)
        guard nextFetchCount > requestedFetchCount else { return }

        requestedFetchCount = nextFetchCount
        appState.prepareHistoryInBackgroundIfNeeded(
            kind: selectedPage.historyKind,
            minimumCount: nextFetchCount,
            force: false
        )
    }
}
