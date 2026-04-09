import SwiftUI

private enum VideosLayoutMode: String {
    case list
    case gallery
}

struct VideosScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoDownloadManager: VideoDownloadManager
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("videos.layout.mode") private var layoutModeRawValue = VideosLayoutMode.list.rawValue
    @State private var searchText = ""
    @State private var showDownloadedOnly = false

    var body: some View {
        videoPane
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var videoPane: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    ScreenHeader(
                        eyebrow: "Videos",
                        title: "Browse titles",
                        subtitle: "A cleaner video library with quick filtering, calmer cards, and direct playback."
                    )

                    Spacer(minLength: 12)

#if os(macOS)
                    Button(showDownloadedOnly ? "Show All" : "Downloaded Videos") {
                        showDownloadedOnly.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(showDownloadedOnly ? Palette.highlight : Palette.accent)
#endif

                    Picker("Layout", selection: $layoutModeRawValue) {
                        Text("List").tag(VideosLayoutMode.list.rawValue)
                        Text("Gallery").tag(VideosLayoutMode.gallery.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    SearchInputField(
                        placeholder: "Filter title, author, journal…",
                        text: $searchText
                    )
                    Button("Refresh Search") {
                        Task { await appState.loadVideos(search: searchText) }
                    }
                    .buttonStyle(.bordered)
                }

                if visibleDownloadItems.isEmpty && showDownloadedOnly {
                    EmptyStateView(
                        title: "No downloaded videos yet",
                        message: "Downloaded videos will appear here and stay playable offline.",
                        symbolName: "arrow.down.circle"
                    )
                } else if filteredVideos.isEmpty && !showDownloadedOnly {
                    EmptyStateView(
                        title: appState.videos.isEmpty ? "No videos loaded" : "No videos matched",
                        message: appState.videos.isEmpty
                            ? "Refresh the library to pull videos from the legacy server."
                            : "Try a different title, author, or journal filter.",
                        symbolName: "video"
                    )
                } else {
                    if layoutMode == .list {
                        listContent
                    } else {
                        galleryContent
                    }
                }
            }
        }
    }

    private var layoutMode: VideosLayoutMode {
        VideosLayoutMode(rawValue: layoutModeRawValue) ?? .list
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if showDownloadedOnly {
                    ForEach(visibleDownloadItems, id: \.id) { item in
                        downloadedVideoCard(item)
                    }
                } else {
                    ForEach(filteredVideos, id: \.id) { video in
                        videoCard(video)
                    }
                }
            }
        }
    }

    private var galleryContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: galleryCardMinimumWidth, maximum: galleryCardMaximumWidth), spacing: 10, alignment: .top)],
                spacing: 10
            ) {
                if showDownloadedOnly {
                    ForEach(visibleDownloadItems, id: \.id) { item in
                        downloadedVideoCard(item)
                    }
                } else {
                    ForEach(filteredVideos, id: \.id) { video in
                        videoCard(video)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func videoCard(_ video: Video) -> some View {
        Button {
            Task { await appState.playVideo(video) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
                title: video.title,
                playbackRecord: playbackRecord(for: video),
                artworkAspectRatio: 0.82,
                artworkWidth: 84,
                artworkHeight: 104,
                titleSize: 12,
                titleLineLimit: 2,
                contentSpacing: 4
            ) {
                Text(video.author.isEmpty ? "Author unavailable" : video.author)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                Text(video.bookJournal.isEmpty ? "Journal unavailable" : video.bookJournal)
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)
            } footer: {
                HStack(alignment: .center, spacing: 8) {
                    StatusPill(text: "Video", tint: Palette.accent)

                    Spacer(minLength: 0)

                    Text(video.editor.isEmpty ? "Tap to play" : video.editor)
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func downloadedVideoCard(_ item: DownloadedVideoItem) -> some View {
        Button {
            appState.playDownloadedVideo(
                item,
                context: visibleDownloadItems,
                railTitle: "Downloaded videos",
                railSubtitle: "Available offline"
            )
        } label: {
            CompactMediaRowCard(
                artworkURLs: item.record.artworkURLs,
                title: item.record.title,
                playbackRecord: playbackRecord(for: item),
                artworkAspectRatio: 0.82,
                artworkWidth: 84,
                artworkHeight: 104,
                titleSize: 12,
                titleLineLimit: 2,
                contentSpacing: 4
            ) {
                Text(item.record.sourceDetail.isEmpty ? item.record.detail : item.record.sourceDetail)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                Text(item.record.sourceName)
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)
            } footer: {
                HStack(alignment: .center, spacing: 8) {
                    StatusPill(text: "Offline", tint: Palette.accent)

                    Spacer(minLength: 0)

                    Text("Play downloaded")
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
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

    private var filteredVideos: [Video] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.videos }
        return appState.videos.filter {
            [$0.title, $0.author, $0.bookJournal, $0.editor]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var visibleDownloadItems: [DownloadedVideoItem] {
        let downloadedItems = videoDownloadManager.downloadedItems(kind: .library)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return downloadedItems }
        return downloadedItems.filter {
            [
                $0.record.title,
                $0.record.sourceName,
                $0.record.sourceDetail,
                $0.record.detail
            ]
            .joined(separator: " ")
            .matchesNormalizedSearch(query)
        }
    }

    private var galleryCardMinimumWidth: CGFloat {
#if os(iOS)
        horizontalSizeClass == .regular ? 224 : 280
#else
        304
#endif
    }

    private var galleryCardMaximumWidth: CGFloat {
#if os(iOS)
        horizontalSizeClass == .regular ? 260 : 332
#else
        354
#endif
    }
}
