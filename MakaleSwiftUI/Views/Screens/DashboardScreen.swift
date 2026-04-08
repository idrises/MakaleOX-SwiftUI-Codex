import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject private var appState: AppState
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    eyebrow: "Overview",
                    title: "Medical Academic Library",
                    subtitle: "Journals, articles, books, and videos organized for focused medical study."
                )

                if appState.session != nil {
                    SectionCard {
                        HStack(alignment: .top, spacing: 10) {
                            MetricChip(label: "Journals", value: appState.dashboard.journalCount, tint: Palette.accent)
                            MetricChip(label: "Articles", value: appState.dashboard.articleCount, tint: Palette.highlight)
                            MetricChip(label: "Books", value: appState.dashboard.bookCount, tint: Palette.highlight)
                            MetricChip(label: "Videos", value: appState.dashboard.videoCount, tint: Palette.gold)
                            MetricChip(label: "Video Sets", value: appState.dashboard.videoSetCount, tint: Palette.accent)
                        }
                    }
                }

                contentStrip(
                    title: "Recent Issues",
                    subtitle: "Fresh journal issues that match your legacy subject settings."
                ) {
                    if appState.dashboard.recentIssues.isEmpty {
                        EmptyStateView(
                            title: "No issue highlights yet",
                            message: "After the first successful refresh, the newest issues will appear here.",
                            symbolName: "newspaper"
                        )
                    } else {
                        LazyVGrid(columns: compactDashboardColumns, spacing: 10) {
                            ForEach(appState.dashboard.recentIssues, id: \.id) { issue in
                                dashboardIssueCard(issue)
                            }
                        }
                    }
                }

                contentStrip(
                    title: "Books",
                    subtitle: "Long-form reading surfaced from the same membership subject."
                ) {
                    LazyVGrid(columns: compactDashboardColumns, spacing: 10) {
                        ForEach(appState.dashboard.recentBooks, id: \.id) { book in
                            dashboardBookCard(book)
                        }
                    }
                }

                contentStrip(
                    title: "Videos",
                    subtitle: "Jump back into the latest video material without digging through the old interface."
                ) {
                    LazyVGrid(columns: compactDashboardColumns, spacing: 10) {
                        ForEach(appState.dashboard.recentVideos, id: \.id) { video in
                            dashboardVideoCard(video)
                        }
                    }
                }

                contentStrip(
                    title: "Video Sets",
                    subtitle: "Curated collections surfaced on the dashboard so you can jump into grouped training faster."
                ) {
                    if appState.dashboard.recentVideoSets.isEmpty {
                        EmptyStateView(
                            title: "No video set highlights yet",
                            message: "When eligible sets are available for this subject, they will appear here.",
                            symbolName: "square.stack.3d.up"
                        )
                    } else {
                        LazyVGrid(columns: compactDashboardColumns, spacing: 10) {
                            ForEach(appState.dashboard.recentVideoSets, id: \.id) { set in
                                dashboardVideoSetCard(set)
                            }
                        }
                    }
                }
            }
        }
    }

    private func contentStrip<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.custom("Avenir Next Bold", size: 22))
                Text(subtitle)
                    .font(.custom("Avenir Next Regular", size: 14))
                    .foregroundStyle(Palette.muted)
                content()
            }
        }
    }

    private var compactDashboardColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dashboardCardMinimumWidth, maximum: dashboardCardMaximumWidth), spacing: 10, alignment: .top)]
    }

    private var dashboardCardMinimumWidth: CGFloat {
#if os(iOS)
        horizontalSizeClass == .regular ? 224 : 280
#else
        304
#endif
    }

    private var dashboardCardMaximumWidth: CGFloat {
#if os(iOS)
        horizontalSizeClass == .regular ? 260 : 332
#else
        354
#endif
    }

    @ViewBuilder
    private func dashboardIssueCard(_ issue: JournalIssue) -> some View {
        Button {
            Task { await appState.showDashboardIssue(issue) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.issueCoverCandidates(
                    journal: issue.journalName,
                    issue: issue.title
                ),
                title: issue.title
            ) {
                Text(issue.journalName)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                if !issue.number.isEmpty {
                    Text("Issue \(issue.number)")
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.highlight)
                        .lineLimit(1)
                }
            } footer: {
                HStack(alignment: .center, spacing: 6) {
                    Text(
                        [issue.year, issue.volume]
                            .filter { !$0.isEmpty }
                            .joined(separator: " • ")
                    )
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dashboardBookCard(_ book: Book) -> some View {
        Button {
            Task { await appState.showDashboardBook(book) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline),
                title: book.title,
                favoriteSelected: appState.favoritesStore.isFavorite(book: book),
                favoriteAction: { appState.favoritesStore.toggleBook(book) }
            ) {
                Text(book.editors)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                if !book.company.isEmpty {
                    Text(book.company)
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.highlight)
                        .lineLimit(1)
                }
            } footer: {
                HStack(alignment: .center, spacing: 6) {
                    if !book.year.isEmpty {
                        Text(book.year)
                            .font(.custom("Avenir Next Medium", size: 8))
                            .foregroundStyle(Palette.highlight)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dashboardVideoCard(_ video: Video) -> some View {
        Button {
            Task { await appState.playVideo(video) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
                title: video.title
            ) {
                Text(video.author.isEmpty ? video.editor : video.author)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                if !video.bookJournal.isEmpty {
                    Text(video.bookJournal)
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.highlight)
                        .lineLimit(1)
                }
            } footer: {
                HStack(alignment: .center, spacing: 6) {
                    Spacer(minLength: 0)

                    Text("Tap to play")
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dashboardVideoSetCard(_ set: VideoSet) -> some View {
        let isAccessible = set.isAccessible(for: appState.session?.userID ?? "")

        CompactMediaRowCard(
            artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
            title: set.setName,
            favoriteSelected: appState.favoritesStore.isFavorite(videoSet: set),
            favoriteAction: { appState.favoritesStore.toggleVideoSet(set) }
        ) {
            Text(set.editors.isEmpty ? set.subject : set.editors)
                .font(.custom("Avenir Next Regular", size: 9))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)

            if !set.subject.isEmpty, set.subject != set.editors {
                Text(set.subject)
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)
            }
        } footer: {
            HStack(alignment: .center, spacing: 5) {
                StatusPill(
                    text: isAccessible ? "Available" : "Restricted",
                    tint: isAccessible ? Palette.accent : Palette.danger
                )

                Spacer(minLength: 0)

                Button("Open Set") {
                    Task { await openVideoSetFromDashboard(set) }
                }
                .buttonStyle(.bordered)
                .tint(Palette.accent)
                .controlSize(.small)
                .disabled(!isAccessible)
            }
        }
    }

    private func openVideoSetFromDashboard(_ set: VideoSet) async {
        await appState.showVideoSetCollection(set)
    }
}
