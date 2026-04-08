import SwiftUI

private enum VideoSetsLayoutMode: String {
    case list
    case gallery
}

struct VideoSetsScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoDownloadManager: VideoDownloadManager
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("videoSets.layout.mode") private var layoutModeRawValue = VideoSetsLayoutMode.list.rawValue
    @State private var searchText = ""
    @State private var activeSet: VideoSet?
    @State private var showDownloadedOnly = false

    var body: some View {
        videoSetPane
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                consumePendingNavigation()
            }
            .onChange(of: appState.pendingVideoSetNavigationID) { _ in
                consumePendingNavigation()
            }
            .onChange(of: appState.videoSetsFavoritesOnly) { isActive in
                if isActive {
                    searchText = ""
                }
            }
    }

    private var videoSetPane: some View {
        SectionCard {
            if let activeSet {
                VideoSetDetailPage(
                    set: activeSet,
                    backTitle: videoSetBackTitle,
                    onBack: {
                        self.activeSet = nil
                        if appState.videoSetReturnSection == .dashboard {
                            appState.videoSetReturnSection = nil
                            appState.selectedSection = .dashboard
                            return
                        } else if appState.videoSetReturnSection == .profile {
                            appState.videoSetReturnSection = nil
                            appState.pendingVideoSetNavigationID = nil
                            appState.selectedSection = .profile
                            return
                        }
                        guard !appState.hasLoadedVideoSetCatalog else { return }
                        Task { await appState.refreshCurrentSection() }
                    }
                )
                .environmentObject(appState)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        ScreenHeader(
                            eyebrow: "Video Sets",
                            title: "Browse collections",
                            subtitle: "A cleaner set shelf focused on covers, editors, access state, and quick open actions."
                        )

                        Spacer(minLength: 12)

#if os(macOS)
                        Button(showDownloadedOnly ? "Show Sets" : "Downloaded Videos") {
                            showDownloadedOnly.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(showDownloadedOnly ? Palette.highlight : Palette.accent)
#endif

                        Picker("Layout", selection: $layoutModeRawValue) {
                            Text("List").tag(VideoSetsLayoutMode.list.rawValue)
                            Text("Gallery").tag(VideoSetsLayoutMode.gallery.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .controlSize(.small)
                    }

                    HStack(spacing: 10) {
                        TextField("Filter set name, editor, subject…", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Button("Refresh") {
                            Task { await appState.refreshCurrentSection() }
                        }
                        .buttonStyle(.bordered)
                    }

                    if appState.videoSetsFavoritesOnly {
                        HStack(spacing: 10) {
                            StatusPill(text: "Favorites only", tint: Palette.accent)
                            Button("Show All") {
                                appState.videoSetsFavoritesOnly = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if visibleDownloadItems.isEmpty && showDownloadedOnly {
                        EmptyStateView(
                            title: "No downloaded set videos yet",
                            message: "Saved set entries will appear here once they are downloaded for offline playback.",
                            symbolName: "arrow.down.circle"
                        )
                    } else if filteredVideoSets.isEmpty && !showDownloadedOnly {
                        EmptyStateView(
                            title: appState.videoSets.isEmpty ? "No video sets loaded" : "No video sets matched",
                            message: appState.videoSets.isEmpty
                                ? "Refresh the library to pull collections from the legacy server."
                                : "Try a different set name, editor, or subject filter.",
                            symbolName: "square.stack.3d.up"
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
    }

    private var layoutMode: VideoSetsLayoutMode {
        VideoSetsLayoutMode(rawValue: layoutModeRawValue) ?? .list
    }

    private var videoSetBackTitle: String {
        switch appState.videoSetReturnSection {
        case .dashboard:
            return "Back To Dashboard"
        case .profile:
            if appState.profileSelectedDetailSectionRawValue == ProfileDetailSection.favoriteVideoSets.rawValue {
                return "Back To Favorite Sets"
            }
            return "Back To Profile"
        default:
            return "Back To Video Sets"
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if showDownloadedOnly {
                    ForEach(visibleDownloadItems, id: \.id) { item in
                        downloadedSetEntryCard(item)
                    }
                } else {
                    ForEach(filteredVideoSets, id: \.id) { set in
                        videoSetCard(set)
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
                        downloadedSetEntryCard(item)
                    }
                } else {
                    ForEach(filteredVideoSets, id: \.id) { set in
                        videoSetCard(set)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func videoSetCard(_ set: VideoSet) -> some View {
        let isSelected = set.id == appState.selectedVideoSet?.id
        let isAccessible = set.isAccessible(for: appState.session?.userID ?? "")

        CompactMediaRowCard(
            artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
            title: set.setName,
            favoriteSelected: appState.favoritesStore.isFavorite(videoSet: set),
            favoriteAction: { appState.favoritesStore.toggleVideoSet(set) }
        ) {
            Text(set.editors.isEmpty ? "Editors unavailable" : set.editors)
                .font(.custom("Avenir Next Regular", size: 9))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)

            if !set.subject.isEmpty {
                Text(set.subject)
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)
            }
        } footer: {
            HStack(alignment: .center, spacing: 8) {
                StatusPill(
                    text: isAccessible ? "Available to you" : "Restricted",
                    tint: isAccessible ? Palette.accent : Palette.danger
                )

                Spacer(minLength: 0)

                Button("Open Set") {
                    appState.videoSetReturnSection = nil
                    activeSet = set
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isAccessible ? Palette.accent : Palette.muted)
                .disabled(!isAccessible)
            }
        }
        .background(
            isSelected ? Palette.accentSoft.opacity(0.4) : Color.clear,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? Palette.accent.opacity(0.24) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    @ViewBuilder
    private func downloadedSetEntryCard(_ item: DownloadedVideoItem) -> some View {
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
    private func playbackRecord(for item: DownloadedVideoItem) -> VideoPlaybackRecord? {
        guard let remoteURL = item.record.remoteURL else { return nil }
        return videoPlaybackStore.record(forRemoteURL: remoteURL)
    }

    private var filteredVideoSets: [VideoSet] {
        let scopedSets = appState.videoSets.filter { set in
            !appState.videoSetsFavoritesOnly || appState.favoritesStore.isFavorite(videoSet: set)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scopedSets }
        return scopedSets.filter {
            [$0.setName, $0.editors, $0.subject]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var visibleDownloadItems: [DownloadedVideoItem] {
        let downloadedItems = videoDownloadManager.downloadedItems(kind: .set)
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

    private func consumePendingNavigation() {
        guard let pendingID = appState.pendingVideoSetNavigationID else { return }
        guard let selectedSet = appState.selectedVideoSet, selectedSet.id == pendingID else { return }

        activeSet = selectedSet
        appState.pendingVideoSetNavigationID = nil
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

struct VideoSetDetailPage: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore

    let set: VideoSet
    let backTitle: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: onBack) {
                        Label(backTitle, systemImage: "chevron.left")
                            .font(.custom("Avenir Next Demi Bold", size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accent)

                    ScreenHeader(
                        eyebrow: "Set Detail",
                        title: set.setName,
                        subtitle: "Each entry opens in the built-in player while also updating history."
                    )
                }

                Spacer(minLength: 12)

                if appState.isLoadingVideoSetEntries, appState.selectedVideoSet?.id == set.id {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                } else {
                    StatusPill(text: "\(visibleEntries.count) items", tint: Palette.accent)
                        .padding(.top, 4)
                }

                Button("Refresh") {
                    Task { await appState.selectVideoSet(set, forceReload: true) }
                }
                .buttonStyle(.bordered)
            }

            if appState.selectedVideoSet?.id != set.id {
                EmptyStateView(
                    title: "Loading set entries",
                    message: "The selected collection is being prepared.",
                    symbolName: "play.square.stack"
                )
            } else if visibleEntries.isEmpty, appState.isLoadingVideoSetEntries {
                EmptyStateView(
                    title: "Loading set entries",
                    message: "The selected collection is being prepared.",
                    symbolName: "play.square.stack"
                )
            } else if visibleEntries.isEmpty {
                EmptyStateView(
                    title: "No set entries found",
                    message: "This collection did not return any playable rows yet.",
                    symbolName: "play.square.stack"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(visibleEntries, id: \.id) { entry in
                            Button {
                                Task { await appState.playVideoSetEntry(entry, from: set) }
                            } label: {
                                CompactMediaRowCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
                                    title: entry.title,
                                    playbackRecord: playbackRecord(for: entry),
                                    artworkAspectRatio: 0.82,
                                    artworkWidth: 84,
                                    artworkHeight: 104,
                                    titleSize: 12,
                                    titleLineLimit: 2,
                                    contentSpacing: 4
                                ) {
                                    Text(entry.author.isEmpty ? "Author unavailable" : entry.author)
                                        .font(.custom("Avenir Next Regular", size: 9))
                                        .foregroundStyle(Palette.muted)
                                        .lineLimit(2)

                                    Text(entry.editor.isEmpty ? set.setName : entry.editor)
                                        .font(.custom("Avenir Next Medium", size: 8))
                                        .foregroundStyle(Palette.highlight)
                                        .lineLimit(1)
                                } footer: {
                                    HStack(alignment: .center, spacing: 8) {
                                        StatusPill(text: "Video", tint: Palette.accent)

                                        Spacer(minLength: 0)

                                        Text("Tap to play")
                                            .font(.custom("Avenir Next Medium", size: 8))
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
        .task(id: set.id) {
            if appState.selectedVideoSet?.id != set.id || appState.videoSetEntries.isEmpty {
                await appState.selectVideoSet(set)
            }
        }
    }

    @MainActor
    private func playbackRecord(for entry: VideoSetEntry) -> VideoPlaybackRecord? {
        guard let remoteURL = LegacyConfig.videoSetRemoteURL(setName: entry.setName, link: entry.remoteLink) else {
            return nil
        }
        return videoPlaybackStore.record(forRemoteURL: remoteURL)
    }

    private var visibleEntries: [VideoSetEntry] {
        guard appState.selectedVideoSet?.id == set.id else { return [] }
        return appState.videoSetEntries
    }
}
