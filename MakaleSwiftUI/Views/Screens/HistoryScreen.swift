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
    @AppStorage("history.page") private var selectedPageRawValue = HistoryPage.all.rawValue
    @State private var searchText = ""

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
                                        Task { await appState.refreshHistory(kind: selectedPage.historyKind) }
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

                        if appState.isRefreshingHistory && pageEntries.isEmpty {
                            Label("Syncing the latest history from the server...", systemImage: "arrow.triangle.2.circlepath")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }

                if appState.isRefreshingHistory && pageEntries.isEmpty {
                    EmptyStateView(
                        title: "Loading history",
                        message: "Your recent items are being refreshed from the server.",
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
                        ForEach(filteredEntries) { entry in
                            Button {
                                Task { await appState.reopenHistoryEntry(entry) }
                            } label: {
                                CompactMediaRowCard(
                                    artworkURLs: coverURLs(for: entry),
                                    title: entry.title,
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
                                        Text(LegacyDate.relativeFormatter.localizedString(for: entry.openedAt, relativeTo: Date()))
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .foregroundStyle(Palette.muted)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func coverURLs(for entry: HistoryEntry) -> [URL] {
        guard let url = URL(string: entry.coverURLString) else { return [] }
        return [url]
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
}
