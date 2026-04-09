import SwiftUI

struct DashboardScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoDownloadManager: VideoDownloadManager
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(
                    eyebrow: "Overview",
                    title: dashboardHeaderTitle,
                    subtitle: dashboardHeaderSubtitle
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

                if usesRefreshedIOSDashboard {
                    contentStrip(
                        title: "Activities",
                        subtitle: "Your last 50 opened items in one place."
                    ) {
                        if activityEntries.isEmpty {
                            EmptyStateView(
                                title: "No activity yet",
                                message: "Articles, chapters, videos, and sets you open will appear here.",
                                symbolName: "clock.arrow.circlepath"
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHGrid(rows: activityGridRows, alignment: .top, spacing: 10) {
                                    ForEach(activityEntries) { entry in
                                        Button {
                                            let visibleEntries = activityEntries
                                            Task { await appState.reopenHistoryEntry(entry, historyContext: visibleEntries) }
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
                                                    Text(LegacyDate.relativeFormatter.localizedString(for: entry.openedAt, relativeTo: Date()))
                                                        .font(.custom("Avenir Next Regular", size: 11))
                                                        .foregroundStyle(Palette.muted)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(width: activityCardWidth, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(height: activityGridHeight)
                        }
                    }
                }

                contentStrip(
                    title: "New Issues",
                    subtitle: usesRefreshedIOSDashboard
                        ? "Latest journal issues ready to open."
                        : "Fresh journal issues that match your legacy subject settings."
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

                if usesRefreshedIOSDashboard {
                    contentStrip(
                        title: "Downloaded Content",
                        subtitle: "Videos saved on this device for offline playback."
                    ) {
                        if downloadedShelfItems.isEmpty {
                            EmptyStateView(
                                title: "No downloads yet",
                                message: "Saved videos and set entries will appear here once downloaded.",
                                symbolName: "arrow.down.circle"
                            )
                        } else {
                            LazyVGrid(columns: compactDashboardColumns, spacing: 10) {
                                ForEach(downloadedShelfItems, id: \.id) { item in
                                    if let downloadedItem = item.downloadedItem {
                                        Button {
                                            appState.playDownloadedVideo(
                                                downloadedItem,
                                                context: playableDownloadedItems,
                                                railTitle: "Downloaded content",
                                                railSubtitle: "Available offline"
                                            )
                                        } label: {
                                            CompactMediaRowCard(
                                                artworkURLs: downloadedItem.record.artworkURLs,
                                                title: downloadedItem.record.title,
                                                playbackRecord: playbackRecord(for: downloadedItem),
                                                artworkWidth: 84,
                                                artworkHeight: 108
                                            ) {
                                                Text(downloadedItem.record.sourceName)
                                                    .font(.custom("Avenir Next Regular", size: 11))
                                                    .foregroundStyle(Palette.muted)
                                                    .lineLimit(2)

                                                Text(item.sourceDescriptor)
                                                    .font(.custom("Avenir Next Medium", size: 10))
                                                    .foregroundStyle(Palette.highlight)
                                                    .lineLimit(2)
                                            } footer: {
                                                HStack(spacing: 8) {
                                                    StatusPill(text: "Offline", tint: Palette.accent)
                                                    Spacer()
                                                    Text("Tap to play")
                                                        .font(.custom("Avenir Next Demi Bold", size: 10))
                                                        .foregroundStyle(Palette.accent)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        CompactMediaRowCard(
                                            artworkURLs: item.record.artworkURLs,
                                            title: item.record.title,
                                            artworkWidth: 84,
                                            artworkHeight: 108
                                        ) {
                                            Text(item.record.sourceName)
                                                .font(.custom("Avenir Next Regular", size: 11))
                                                .foregroundStyle(Palette.muted)
                                                .lineLimit(2)

                                            Text(item.sourceDescriptor)
                                                .font(.custom("Avenir Next Medium", size: 10))
                                                .foregroundStyle(Palette.highlight)
                                                .lineLimit(2)

                                            DashboardDownloadStateSummary(state: item.state)
                                        } footer: {
                                            HStack(spacing: 8) {
                                                StatusPill(text: item.statusTitle, tint: downloadTint(for: item.state))
                                                Spacer()
                                                if let actionTitle = downloadActionTitle(for: item.state),
                                                   let action = downloadAction(for: item) {
                                                    Button(actionTitle, action: action)
                                                        .buttonStyle(.bordered)
                                                        .tint(Palette.accent)
                                                        .controlSize(.small)
                                                }
                                            }
                                        }
                                        .opacity(0.76)
                                    }
                                }
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

    private var activityGridRows: [GridItem] {
        Array(repeating: GridItem(.fixed(activityRowHeight), spacing: 10, alignment: .top), count: 3)
    }

    private var activityRowHeight: CGFloat {
        172
    }

    private var activityGridHeight: CGFloat {
        (activityRowHeight * 3) + 20
    }

    private var activityCardWidth: CGFloat {
#if os(iOS)
        horizontalSizeClass == .regular ? 336 : 260
#else
        312
#endif
    }

    private var dashboardHeaderTitle: String {
        usesRefreshedIOSDashboard
            ? "Your Library, Medical Research Library Entrance Gate"
            : AppBranding.title
    }

    private var dashboardHeaderSubtitle: String {
        usesRefreshedIOSDashboard
            ? "A centralized platform providing access to trusted medical articles, research papers, and academic resources."
            : "Journals, articles, books, and videos organized for focused medical study."
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

    private var usesRefreshedIOSDashboard: Bool {
#if os(iOS)
        horizontalSizeClass == .regular
#else
        true
#endif
    }

    private var activityEntries: [HistoryEntry] {
        Array(appState.historyStore.entries.prefix(50))
    }

    private var downloadedShelfItems: [DownloadShelfItem] {
        Array(videoDownloadManager.downloadShelfItems().prefix(10))
    }

    private var playableDownloadedItems: [DownloadedVideoItem] {
        downloadedShelfItems.compactMap(\.downloadedItem)
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
                title: video.title,
                playbackRecord: playbackRecord(for: video)
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
            VStack(alignment: .leading, spacing: 8) {
                StatusPill(
                    text: isAccessible ? "Available" : "Restricted",
                    tint: isAccessible ? Palette.accent : Palette.danger
                )

                Button("Open Set") {
                    Task { await openVideoSetFromDashboard(set) }
                }
                .buttonStyle(.bordered)
                .tint(Palette.accent)
                .controlSize(.small)
                .disabled(!isAccessible)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openVideoSetFromDashboard(_ set: VideoSet) async {
        await appState.showVideoSetCollection(set)
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

    @MainActor
    private func playbackRecord(for video: Video) -> VideoPlaybackRecord? {
        guard let remoteURL = LegacyConfig.videoRemoteURL(bookJournal: video.bookJournal, link: video.remoteLink) else {
            return nil
        }
        return videoPlaybackStore.record(forRemoteURL: remoteURL)
    }

    @MainActor
    private func playbackRecord(for item: DownloadedVideoItem) -> VideoPlaybackRecord? {
        guard let remoteURL = item.record.remoteURL else { return nil }
        return videoPlaybackStore.record(forRemoteURL: remoteURL)
    }

    private func downloadTint(for state: VideoDownloadState) -> Color {
        switch state {
        case .downloaded:
            return Palette.accent
        case .queued, .downloading:
            return Palette.highlight
        case .paused:
            return Palette.gold
        case .failed:
            return Palette.danger
        case .notDownloaded:
            return Palette.muted
        }
    }

    private func downloadActionTitle(for state: VideoDownloadState) -> String? {
        switch state {
        case .queued, .downloading:
            return "Pause"
        case .paused:
            return "Resume"
        case .downloaded, .failed, .notDownloaded:
            return nil
        }
    }

    private func downloadAction(for item: DownloadShelfItem) -> (() -> Void)? {
        guard let remoteURL = item.record.remoteURL else { return nil }

        switch item.state {
        case .queued, .downloading:
            return { videoDownloadManager.pauseDownload(forRemoteURL: remoteURL) }
        case .paused:
            return { videoDownloadManager.resumeDownload(forRemoteURL: remoteURL) }
        case .downloaded, .failed, .notDownloaded:
            return nil
        }
    }

}

private struct DashboardDownloadStateSummary: View {
    let state: VideoDownloadState

    private var status: DownloadStatus? {
        switch state {
        case .queued(let status), .paused(let status):
            return status
        case .downloading(let status):
            return status
        case .downloaded, .failed, .notDownloaded:
            return nil
        }
    }

    private var detailText: String {
        switch state {
        case .queued(let status):
            return status?.detailText ?? "Waiting to start download"
        case .downloading(let status):
            return status.detailText
        case .paused(let status):
            return status?.detailText ?? "Download paused"
        case .downloaded:
            return "Saved on this device"
        case .failed(let message):
            return message
        case .notDownloaded:
            return "Not downloaded"
        }
    }

    private var progressFraction: Double? {
        switch state {
        case .queued(let status), .paused(let status):
            return status?.fractionCompleted
        case .downloading(let status):
            return status.fractionCompleted
        case .downloaded:
            return 1
        case .failed, .notDownloaded:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let progressFraction {
                ProgressView(value: progressFraction)
                    .tint(Palette.accent)
                    .controlSize(.small)
            }

            Text(detailText)
                .font(.custom("Avenir Next Medium", size: 10))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
        }
    }
}
