import SwiftUI

private enum VideosLayoutMode: String {
    case list
    case gallery
}

struct VideosScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("videos.layout.mode") private var layoutModeRawValue = VideosLayoutMode.list.rawValue
    @State private var searchText = ""

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

                    Picker("Layout", selection: $layoutModeRawValue) {
                        Text("List").tag(VideosLayoutMode.list.rawValue)
                        Text("Gallery").tag(VideosLayoutMode.gallery.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    TextField("Filter title, author, journal…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button("Refresh Search") {
                        Task { await appState.loadVideos(search: searchText) }
                    }
                    .buttonStyle(.bordered)
                }

                if filteredVideos.isEmpty {
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
                ForEach(filteredVideos, id: \.id) { video in
                    videoCard(video)
                }
            }
        }
    }

    private var galleryContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 304, maximum: 354), spacing: 10, alignment: .top)],
                spacing: 10
            ) {
                ForEach(filteredVideos, id: \.id) { video in
                    videoCard(video)
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

    private var filteredVideos: [Video] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.videos }
        return appState.videos.filter {
            [$0.title, $0.author, $0.bookJournal, $0.editor]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }
}
