#if os(iOS)
import SwiftUI
import UIKit

private enum PhoneRootTab: String, CaseIterable, Identifiable {
    case home
    case library
    case search
    case history
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .search: return "Search"
        case .history: return "History"
        case .profile: return "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "books.vertical.fill"
        case .search: return "magnifyingglass"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

private enum PhoneLibrarySection: String, CaseIterable, Identifiable {
    case journals
    case books
    case videos
    case videoSets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journals: return "Journals"
        case .books: return "Books"
        case .videos: return "Videos"
        case .videoSets: return "Sets"
        }
    }

    var appSection: AppSection {
        switch self {
        case .journals: return .journals
        case .books: return .books
        case .videos: return .videos
        case .videoSets: return .videoSets
        }
    }
}

private enum PhoneSearchPage: String, CaseIterable, Identifiable {
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
        case .videoSets: return "Set"
        }
    }

    var videoRailScope: SearchVideoRailScope {
        switch self {
        case .videos:
            return .videos
        case .videoSets:
            return .videoSets
        case .all, .journals, .books:
            return .all
        }
    }
}

private enum PhoneHistoryPage: String, CaseIterable, Identifiable {
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
        case .videoSets: return "Set"
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

private enum PhoneCombinedSearchItem: Identifiable {
    case article(Article)
    case chapter(Chapter)
    case video(Video)
    case videoSet(VideoSetEntry)

    var id: String {
        switch self {
        case .article(let value): return "article-\(value.id)"
        case .chapter(let value): return "chapter-\(value.id)"
        case .video(let value): return "video-\(value.id)"
        case .videoSet(let value): return "set-\(value.id)"
        }
    }

    var sortDate: Date {
        switch self {
        case .article(let value): return value.sortDate ?? .distantPast
        case .chapter(let value): return value.sortDate ?? .distantPast
        case .video(let value): return value.sortDate ?? .distantPast
        case .videoSet(let value): return value.sortDate ?? .distantPast
        }
    }
}

struct IPhoneRootShellView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rootTab: PhoneRootTab = .home

    var body: some View {
        ZStack {
            PhoneCanvas()
                .ignoresSafeArea()

            Group {
                switch rootTab {
                case .home:
                    PhoneDashboardScreen()
                case .library:
                    PhoneLibraryScreen()
                case .search:
                    PhoneSearchExperienceScreen()
                case .history:
                    PhoneHistoryExperienceScreen()
                case .profile:
                    PhoneProfileExperienceScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom) {
            PhoneTabBar(selectedTab: $rootTab) { tab in
                rootTab = tab
                switch tab {
                case .home:
                    appState.selectedSection = .dashboard
                case .library:
                    if !PhoneLibrarySection.allCases.map(\.appSection).contains(appState.selectedSection) {
                        appState.selectedSection = .journals
                    }
                case .search:
                    appState.selectedSection = .search
                case .history:
                    appState.selectedSection = .history
                case .profile:
                    appState.selectedSection = .profile
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .task {
            syncRootTab()
            await appState.loadCurrentSectionIfNeeded()
        }
        .onChange(of: appState.selectedSection) { _ in
            syncRootTab()
            Task { await appState.loadCurrentSectionIfNeeded() }
        }
        .fullScreenCover(item: phoneVideoBinding) { video in
            VideoPlayerScreen(
                video: video,
                backLabel: "Close",
                onClose: { appState.activeVideo = nil }
            )
        }
        .fullScreenCover(item: phoneDocumentBinding) { document in
            DocumentViewerScreen(
                document: document,
                backLabel: "Close",
                showsMetadataHeader: false,
                onClose: { appState.activeDocument = nil }
            )
        }
    }

    private func syncRootTab() {
        switch appState.selectedSection {
        case .dashboard:
            rootTab = .home
        case .journals, .books, .videos, .videoSets:
            rootTab = .library
        case .search:
            rootTab = .search
        case .history:
            rootTab = .history
        case .profile:
            rootTab = .profile
        }
    }

    private var phoneVideoBinding: Binding<VideoPresentation?> {
        Binding(
            get: { appState.activeVideo },
            set: { appState.activeVideo = $0 }
        )
    }

    private var phoneDocumentBinding: Binding<DocumentPresentation?> {
        Binding(
            get: { appState.activeDocument },
            set: { appState.activeDocument = $0 }
        )
    }
}

private struct PhoneCanvas: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.95, blue: 0.94),
                    Color(red: 0.97, green: 0.97, blue: 0.95),
                    Color(red: 0.94, green: 0.96, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.85)
        }
    }
}

private struct PhoneTabBar: View {
    @Binding var selectedTab: PhoneRootTab
    let onSelect: (PhoneRootTab) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhoneRootTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.white : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedTab == tab ? Palette.accent : Color.white.opacity(0.72))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PhonePageScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PhoneHeaderBlock<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Palette.highlight)
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
    }
}

private struct PhoneSurfaceCard<Content: View>: View {
    let content: Content
    let contentPadding: CGFloat

    init(contentPadding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.contentPadding = contentPadding
    }

    var body: some View {
        content
            .padding(contentPadding)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }
}

private struct PhoneMetricPill: View {
    let title: String
    let value: Int
    let tint: Color
    var compact: Bool = false
    var fillsAvailableWidth: Bool = false

    var body: some View {
        VStack(alignment: fillsAvailableWidth ? .center : .leading, spacing: fillsAvailableWidth ? 3 : 4) {
            Text(title.uppercased())
                .font(.system(size: compact ? (fillsAvailableWidth ? 6 : 7) : 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(fillsAvailableWidth ? 0.68 : 0.92)
                .allowsTightening(true)
            Text(value.formatted(.number.grouping(.automatic)))
                .font(.system(size: compact ? (fillsAvailableWidth ? 14 : 17) : 21, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(fillsAvailableWidth ? 0.72 : 0.92)
        }
        .padding(.horizontal, fillsAvailableWidth ? 6 : compact ? 10 : 14)
        .padding(.vertical, fillsAvailableWidth ? 8 : compact ? 9 : 12)
        .frame(
            minWidth: fillsAvailableWidth ? nil : compact ? 74 : 108,
            maxWidth: fillsAvailableWidth ? .infinity : nil,
            alignment: fillsAvailableWidth ? .center : .leading
        )
        .fixedSize(horizontal: !fillsAvailableWidth, vertical: false)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous))
    }
}

private struct PhoneWrapLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = makeRows(for: proposal.width, sizes: sizes)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.last.map { $0.yOffset + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = makeRows(for: bounds.width, sizes: sizes)

        for row in rows {
            for index in row.items.indices {
                let origin = CGPoint(
                    x: bounds.minX + row.xOffsets[index],
                    y: bounds.minY + row.yOffset
                )
                subviews[row.items[index]].place(
                    at: origin,
                    proposal: ProposedViewSize(sizes[row.items[index]])
                )
            }
        }
    }

    private func makeRows(for proposedWidth: CGFloat?, sizes: [CGSize]) -> [PhoneWrapRow] {
        let availableWidth = proposedWidth ?? .infinity
        guard !sizes.isEmpty else { return [] }

        var rows: [PhoneWrapRow] = []
        var currentItems: [Int] = []
        var currentXOffsets: [CGFloat] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentY: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let proposedItemWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if !currentItems.isEmpty && proposedItemWidth > availableWidth {
                rows.append(
                    PhoneWrapRow(
                        items: currentItems,
                        xOffsets: currentXOffsets,
                        yOffset: currentY,
                        width: currentWidth,
                        height: currentHeight
                    )
                )
                currentY += currentHeight + rowSpacing
                currentItems = []
                currentXOffsets = []
                currentWidth = 0
                currentHeight = 0
            }

            let xOffset = currentItems.isEmpty ? 0 : currentWidth + spacing
            currentItems.append(index)
            currentXOffsets.append(xOffset)
            currentWidth = xOffset + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(
                PhoneWrapRow(
                    items: currentItems,
                    xOffsets: currentXOffsets,
                    yOffset: currentY,
                    width: currentWidth,
                    height: currentHeight
                )
            )
        }

        return rows
    }
}

private struct PhoneWrapRow {
    let items: [Int]
    let xOffsets: [CGFloat]
    let yOffset: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private struct PhoneDashboardMetric: Identifiable {
    let title: String
    let value: Int
    let tint: Color

    var id: String { title }
}

private enum PhoneDashboardDestination: Hashable {
    case issue(JournalIssue)
    case book(Book)
    case videoSet(VideoSet)
}

private struct PhoneSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct PhoneLibrarySegmentedPicker: View {
    @Binding var selection: PhoneLibrarySection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhoneLibrarySection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == section ? Color.white : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection == section ? Palette.accent : Color.white.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PhoneSearchField: View {
    let placeholder: String
    @Binding var text: String
    let buttonTitle: String
    let action: () -> Void
    var submitLabel: SubmitLabel = .search
    var onSubmitAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.muted)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .submitLabel(submitLabel)
                    .onSubmit {
                        (onSubmitAction ?? action)()
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.muted.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(buttonTitle, action: action)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct PhoneRowCard<Footer: View>: View {
    let artworkURLs: [URL]
    let title: String
    let subtitle: String
    let detail: String
    let badgeText: String?
    let trailingText: String?
    let favoriteSelected: Bool?
    let favoriteAction: (() -> Void)?
    let playbackRecord: VideoPlaybackRecord?
    let accessory: Footer

    init(
        artworkURLs: [URL],
        title: String,
        subtitle: String,
        detail: String = "",
        badgeText: String? = nil,
        trailingText: String? = nil,
        favoriteSelected: Bool? = nil,
        favoriteAction: (() -> Void)? = nil,
        playbackRecord: VideoPlaybackRecord? = nil,
        @ViewBuilder accessory: () -> Footer = { EmptyView() }
    ) {
        self.artworkURLs = artworkURLs
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badgeText = badgeText
        self.trailingText = trailingText
        self.favoriteSelected = favoriteSelected
        self.favoriteAction = favoriteAction
        self.playbackRecord = playbackRecord
        self.accessory = accessory()
    }

    var body: some View {
        let artworkWidth: CGFloat = 70
        let artworkHeight: CGFloat = 90

        HStack(alignment: .top, spacing: 10) {
            RemoteArtworkView(urls: artworkURLs, aspectRatio: 0.78, cornerRadius: 14)
                .frame(width: artworkWidth, height: artworkHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Palette.highlight)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let playbackRecord {
                    PlaybackProgressSummary(record: playbackRecord)
                }

                Spacer(minLength: 3)

                HStack(spacing: 6) {
                    if let badgeText {
                        Text(badgeText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Palette.accentSoft, in: Capsule())
                    }

                    Spacer(minLength: 0)

                    if let trailingText {
                        Text(trailingText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: artworkHeight, alignment: .topLeading)

            Spacer(minLength: 8)

            accessory
        }
        .padding(12)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let favoriteSelected, let favoriteAction {
                FavoriteBadgeButton(isSelected: favoriteSelected, action: favoriteAction)
                    .padding(10)
            }
        }
    }
}

private struct PhoneCarouselCard: View {
    let artworkURLs: [URL]
    let title: String
    let subtitle: String
    let detail: String
    let downloadState: VideoDownloadState?
    let dimmedContent: Bool
    let playbackRecord: VideoPlaybackRecord?
    let actionTitle: String?
    let action: (() -> Void)?

    private let artworkWidth: CGFloat = 132
    private let artworkHeight: CGFloat = 104
    private let cardInset: CGFloat = 10

    init(
        artworkURLs: [URL],
        title: String,
        subtitle: String,
        detail: String,
        downloadState: VideoDownloadState? = nil,
        dimmedContent: Bool = false,
        playbackRecord: VideoPlaybackRecord? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.artworkURLs = artworkURLs
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.downloadState = downloadState
        self.dimmedContent = dimmedContent
        self.playbackRecord = playbackRecord
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        PhoneSurfaceCard(contentPadding: cardInset) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    RemoteArtworkView(
                        urls: artworkURLs,
                        aspectRatio: 1.2,
                        cornerRadius: 15,
                        imageAlignment: .top,
                        imageContentMode: .fit,
                        imagePadding: 4
                    )
                        .frame(width: artworkWidth, height: artworkHeight)
                        .clipped()

                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(Palette.ink)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)

                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundStyle(Palette.highlight)
                            .lineLimit(2)
                    }

                    if let downloadState {
                        PhoneDownloadStateSummary(state: downloadState)
                    }

                    if let playbackRecord {
                        PlaybackProgressSummary(record: playbackRecord)
                    }
                }
                .opacity(dimmedContent ? 0.62 : 1)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Palette.accent, in: Capsule())
                }
            }
            .frame(width: artworkWidth, alignment: .leading)
        }
    }
}

private struct PhoneDownloadStateSummary: View {
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

    private var title: String {
        switch state {
        case .queued(_):
            return "Queued"
        case .downloading(_):
            return "Downloading"
        case .paused(_):
            return "Paused"
        case .downloaded(_):
            return "Offline"
        case .failed(_):
            return "Failed"
        case .notDownloaded:
            return "Not downloaded"
        }
    }

    private var detailText: String {
        if let status {
            return status.detailText
        }

        switch state {
        case .queued(_):
            return "Waiting for network transfer"
        case .paused(_):
            return "Ready to continue"
        case .failed(let message):
            return message
        case .downloaded(_):
            return "Available offline"
        case .downloading(_), .notDownloaded:
            return ""
        }
    }

    private var tint: Color {
        switch state {
        case .paused(_):
            return Palette.gold
        case .failed(_):
            return Palette.danger
        case .queued(_), .downloading(_), .downloaded(_), .notDownloaded:
            return Palette.accent
        }
    }

    private var progressFraction: Double? {
        status?.fractionCompleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                if let status {
                    Text(status.detailText)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            if status == nil, !detailText.isEmpty {
                Text(detailText)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }

            if let progressFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Palette.accentSoft.opacity(0.9))

                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: max(proxy.size.width * progressFraction, progressFraction > 0 ? 10 : 0))
                    }
                }
                .frame(height: 5)
            } else if case .queued(_) = state {
                ProgressView()
                    .tint(Palette.accent)
                    .scaleEffect(0.75, anchor: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PhoneEmptyState: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        PhoneSurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Palette.accent)
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

@MainActor
private func phonePlaybackRecord(for video: Video, using store: VideoPlaybackStore) -> VideoPlaybackRecord? {
    guard let remoteURL = LegacyConfig.videoRemoteURL(bookJournal: video.bookJournal, link: video.remoteLink) else {
        return nil
    }
    return store.record(forRemoteURL: remoteURL)
}

@MainActor
private func phonePlaybackRecord(for entry: VideoSetEntry, using store: VideoPlaybackStore) -> VideoPlaybackRecord? {
    guard let remoteURL = LegacyConfig.videoSetRemoteURL(setName: entry.setName, link: entry.remoteLink) else {
        return nil
    }
    return store.record(forRemoteURL: remoteURL)
}

@MainActor
private func phonePlaybackRecord(for item: DownloadedVideoItem, using store: VideoPlaybackStore) -> VideoPlaybackRecord? {
    guard let remoteURL = item.record.remoteURL else { return nil }
    return store.record(forRemoteURL: remoteURL)
}

@MainActor
private func phonePlaybackRecord(for entry: HistoryEntry, using store: VideoPlaybackStore) -> VideoPlaybackRecord? {
    switch entry.kind {
    case .video, .videoSet:
        break
    case .article, .chapter:
        return nil
    }

    if let directURL = URL(string: entry.urlString),
       directURL.scheme != nil,
       !directURL.isFileURL {
        return store.record(forRemoteURL: directURL)
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
    return store.record(forRemoteURL: remoteURL)
}

private struct PhoneDashboardScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileAvatarStore: ProfileAvatarStore
    @EnvironmentObject private var videoDownloadManager: VideoDownloadManager
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var destination: PhoneDashboardDestination?

    var body: some View {
        Group {
            switch destination {
            case .issue(let issue):
                PhoneDashboardIssueDetailScreen(issue: issue) {
                    destination = nil
                }
            case .book(let book):
                PhoneDashboardBookDetailScreen(book: book) {
                    destination = nil
                }
            case .videoSet(let set):
                PhoneDashboardVideoSetDetailScreen(set: set) {
                    destination = nil
                }
            case nil:
                dashboardOverview
            }
        }
    }

    private var dashboardOverview: some View {
        PhonePageScroll {
            if let session = appState.session {
                PhoneSurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.highlight)
                                Text(AppBranding.title)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.ink)
                                Text(session.displayName)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            PhoneDashboardAvatarPicker(session: session)
                                .environmentObject(profileAvatarStore)
                        }

                        HStack(alignment: .bottom, spacing: 10) {
                            Text(session.expireDate.isEmpty ? "" : "Renew date \(session.expireDate)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.muted)

                            Spacer(minLength: 0)

                            Text(session.isExpired ? "Expired" : "Active")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(session.isExpired ? Palette.danger : Palette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background((session.isExpired ? Palette.danger : Palette.accent).opacity(0.10), in: Capsule())
                        }
                    }
                }
            }

            PhoneHeaderBlock(
                eyebrow: "Overview",
                title: "Your Library, Medical Research Library Entrance Gate",
                subtitle: "A centralized platform providing access to trusted medical articles, research papers, and academic resources."
            )

            HStack(spacing: 6) {
                ForEach(metrics) { metric in
                    PhoneMetricPill(
                        title: metric.title,
                        value: metric.value,
                        tint: metric.tint,
                        compact: true,
                        fillsAvailableWidth: true
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            phoneCarouselSection(
                title: "Activities",
                subtitle: "Your last 50 opened items in one place."
            ) {
                if activityEntries.isEmpty {
                    PhoneEmptyState(
                        title: "No activity yet",
                        message: "Articles, chapters, videos, and sets you open will appear here.",
                        symbol: "clock.arrow.circlepath"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(activityEntries, id: \.id) { entry in
                                Button {
                                    Task {
                                        await appState.reopenHistoryEntry(entry, historyContext: activityEntries)
                                    }
                                } label: {
                                    PhoneCarouselCard(
                                        artworkURLs: activityArtworkURLs(for: entry),
                                        title: entry.title,
                                        subtitle: entry.subtitle,
                                        detail: activityDetail(for: entry),
                                        playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore),
                                        actionTitle: nil,
                                        action: nil
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            phoneCarouselSection(
                title: "New Issues",
                subtitle: "Latest journal issues ready to open."
            ) {
                if appState.dashboard.recentIssues.isEmpty {
                    PhoneEmptyState(
                        title: "No issues yet",
                        message: "Refresh the dashboard to pull the latest issue highlights.",
                        symbol: "newspaper"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(appState.dashboard.recentIssues, id: \.id) { issue in
                                Button {
                                    destination = .issue(issue)
                                } label: {
                                    PhoneCarouselCard(
                                        artworkURLs: LegacyConfig.issueCoverCandidates(journal: issue.journalName, issue: issue.title),
                                        title: issue.title,
                                        subtitle: issue.journalName,
                                        detail: [issue.year, issue.volume, issue.number].filter { !$0.isEmpty }.joined(separator: " • "),
                                        actionTitle: "Open Issue",
                                        action: nil
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            phoneCarouselSection(
                title: "Downloaded Content",
                subtitle: "Videos saved on this device for offline playback."
            ) {
                if downloadedShelfItems.isEmpty {
                    PhoneEmptyState(
                        title: "No downloads yet",
                        message: "Saved videos and set entries will appear here once downloaded.",
                        symbol: "arrow.down.circle"
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
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
                                        PhoneCarouselCard(
                                            artworkURLs: downloadedItem.record.artworkURLs,
                                            title: downloadedItem.record.title,
                                            subtitle: downloadedItem.record.sourceName,
                                            detail: downloadedItem.record.sourceKind == .set ? "Video Set • Offline" : "Library Video • Offline",
                                            playbackRecord: phonePlaybackRecord(for: downloadedItem, using: videoPlaybackStore),
                                            actionTitle: nil,
                                            action: nil
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    PhoneCarouselCard(
                                        artworkURLs: item.record.artworkURLs,
                                        title: item.record.title,
                                        subtitle: item.record.sourceName,
                                        detail: item.sourceDescriptor,
                                        downloadState: item.state,
                                        dimmedContent: true,
                                        actionTitle: downloadShelfActionTitle(for: item.state),
                                        action: downloadShelfAction(for: item)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            phoneCarouselSection(
                title: "Books",
                subtitle: "Long-form references surfaced for your subject."
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(appState.dashboard.recentBooks, id: \.id) { book in
                            Button {
                                destination = .book(book)
                            } label: {
                                PhoneCarouselCard(
                                    artworkURLs: LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline),
                                    title: book.title,
                                    subtitle: book.editors,
                                    detail: [book.year, book.company].filter { !$0.isEmpty }.joined(separator: " • "),
                                    actionTitle: "Open Book",
                                    action: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            phoneCarouselSection(
                title: "Videos",
                subtitle: "Tap directly into the most recent video materials."
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(appState.dashboard.recentVideos, id: \.id) { video in
                            Button {
                                Task { await appState.playVideo(video) }
                            } label: {
                                PhoneCarouselCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
                                    title: video.title,
                                    subtitle: video.author.isEmpty ? video.editor : video.author,
                                    detail: video.bookJournal,
                                    playbackRecord: phonePlaybackRecord(for: video, using: videoPlaybackStore),
                                    actionTitle: "Play Video",
                                    action: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            phoneCarouselSection(
                title: "Video Sets",
                subtitle: "Grouped collections you can open in one tap."
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(appState.dashboard.recentVideoSets, id: \.id) { set in
                            Button {
                                destination = .videoSet(set)
                            } label: {
                                PhoneCarouselCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
                                    title: set.setName,
                                    subtitle: set.editors,
                                    detail: set.subject,
                                    actionTitle: "Open Set",
                                    action: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var metrics: [PhoneDashboardMetric] {
        [
            PhoneDashboardMetric(title: "Journals", value: appState.dashboard.journalCount, tint: Palette.accent),
            PhoneDashboardMetric(title: "Articles", value: appState.dashboard.articleCount, tint: Palette.highlight),
            PhoneDashboardMetric(title: "Books", value: appState.dashboard.bookCount, tint: Palette.gold),
            PhoneDashboardMetric(title: "Videos", value: appState.dashboard.videoCount, tint: Palette.accent),
            PhoneDashboardMetric(title: "Sets", value: appState.dashboard.videoSetCount, tint: Palette.highlight)
        ]
    }

    private var downloadedShelfItems: [DownloadShelfItem] {
        Array(videoDownloadManager.downloadShelfItems().prefix(10))
    }

    private var activityEntries: [HistoryEntry] {
        Array(appState.historyStore.entries.prefix(50))
    }

    private var playableDownloadedItems: [DownloadedVideoItem] {
        downloadedShelfItems.compactMap(\.downloadedItem)
    }

    private func activityArtworkURLs(for entry: HistoryEntry) -> [URL] {
        guard !entry.coverURLString.isEmpty, let coverURL = URL(string: entry.coverURLString) else {
            return []
        }
        return [coverURL]
    }

    private func activityDetail(for entry: HistoryEntry) -> String {
        [entry.kind.title, entry.detail]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private func phoneCarouselSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PhoneSectionHeader(title: title, subtitle: subtitle)
            content()
        }
    }

    private func downloadShelfActionTitle(for state: VideoDownloadState) -> String? {
        switch state {
        case .queued(_), .downloading(_):
            return "Pause"
        case .paused(_):
            return "Resume"
        case .downloaded(_), .failed(_), .notDownloaded:
            return nil
        }
    }

    private func downloadShelfAction(for item: DownloadShelfItem) -> (() -> Void)? {
        guard let remoteURL = item.record.remoteURL else { return nil }

        switch item.state {
        case .queued(_), .downloading(_):
            return {
                videoDownloadManager.pauseDownload(forRemoteURL: remoteURL)
            }
        case .paused(_):
            return {
                videoDownloadManager.resumeDownload(forRemoteURL: remoteURL)
            }
        case .downloaded(_), .failed(_), .notDownloaded:
            return nil
        }
    }
}

private struct PhoneDashboardAvatarPicker: View {
    @EnvironmentObject private var profileAvatarStore: ProfileAvatarStore
    @State private var isShowingOptions = false
    @State private var activeImageSource: PhoneAvatarImageSource?

    let session: SessionInfo

    var body: some View {
        Button {
            isShowingOptions = true
        } label: {
            avatarImage
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.88), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Profile photo", isPresented: $isShowingOptions, titleVisibility: .visible) {
            Button("Fotoğraf seç") {
                activeImageSource = .photoLibrary
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Fotoğraf çek") {
                    activeImageSource = .camera
                }
            }
            if profileAvatarStore.imageData(for: session) != nil {
                Button("Kaldır", role: .destructive) {
                    profileAvatarStore.removeAvatar(for: session)
                }
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .sheet(item: $activeImageSource) { source in
            PhoneAvatarImagePicker(sourceType: source.sourceType) { data in
                if let data {
                    profileAvatarStore.saveAvatarData(data, for: session)
                }
                activeImageSource = nil
            }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = profileAvatarStore.imageData(for: session),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.accentSoft, Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

private enum PhoneAvatarImageSource: String, Identifiable {
    case photoLibrary
    case camera

    var id: String { rawValue }

    var sourceType: UIImagePickerController.SourceType {
        switch self {
        case .photoLibrary:
            return .photoLibrary
        case .camera:
            return .camera
        }
    }
}

private struct PhoneAvatarImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onSelection: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = sourceType
        controller.allowsEditing = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onSelection: (Data?) -> Void

        init(onSelection: @escaping (Data?) -> Void) {
            self.onSelection = onSelection
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onSelection(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            let data = image?.jpegData(compressionQuality: 0.92) ?? image?.pngData()
            picker.dismiss(animated: true)
            onSelection(data)
        }
    }
}

private struct PhoneDashboardIssueDetailScreen: View {
    @EnvironmentObject private var appState: AppState

    let issue: JournalIssue
    let onBack: () -> Void

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Dashboard",
                title: issue.title,
                subtitle: issue.journalName
            ) {
                PhoneBackButton(label: "Dashboard", action: onBack)
            }

            PhoneSurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    RemoteArtworkView(
                        urls: LegacyConfig.issueCoverCandidates(journal: issue.journalName, issue: issue.title),
                        aspectRatio: 0.76,
                        cornerRadius: 16
                    )
                    .frame(width: 86, height: 116)

                    VStack(alignment: .leading, spacing: 10) {
                        PhoneInfoLine(label: "Journal", value: issue.journalName)
                        PhoneInfoLine(
                            label: "Issue",
                            value: [issue.year, issue.volume, issue.number]
                                .filter { !$0.isEmpty }
                                .joined(separator: " • ")
                        )
                    }
                }
            }

            if appState.isLoadingArticles && appState.selectedIssue?.id == issue.id {
                PhoneEmptyState(
                    title: "Loading articles",
                    message: "Issue articles are being prepared for this dashboard shortcut.",
                    symbol: "doc.text.magnifyingglass"
                )
            } else if appState.selectedIssue?.id == issue.id && appState.articles.isEmpty {
                PhoneEmptyState(
                    title: "No articles found",
                    message: "This issue did not return any article rows.",
                    symbol: "doc.text"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dashboardArticles, id: \.id) { article in
                        Button {
                            Task { await appState.openArticle(article) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.issueCoverCandidates(journal: article.journalName, issue: article.issueTitle),
                                title: article.title,
                                subtitle: article.author,
                                detail: [article.journalName, article.issueTitle].joined(separator: " • "),
                                badgeText: "Article",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: issue.id) {
            await appState.selectIssue(issue)
        }
    }

    private var dashboardArticles: [Article] {
        guard appState.selectedIssue?.id == issue.id else { return [] }
        return appState.articles
    }
}

private struct PhoneDashboardBookDetailScreen: View {
    @EnvironmentObject private var appState: AppState

    let book: Book
    let onBack: () -> Void

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Dashboard",
                title: book.title,
                subtitle: book.editors
            ) {
                PhoneBackButton(label: "Dashboard", action: onBack)
            }

            PhoneSurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    RemoteArtworkView(
                        urls: artworkURLs,
                        aspectRatio: 0.76,
                        cornerRadius: 16
                    )
                    .frame(width: 86, height: 116)

                    VStack(alignment: .leading, spacing: 10) {
                        PhoneInfoLine(label: "Publisher", value: book.company)
                        PhoneInfoLine(label: "Year", value: book.year)
                        PhoneInfoLine(label: "Subject", value: book.subject)
                        PhoneInfoLine(
                            label: "ISBN",
                            value: book.isbnOnline.isEmpty ? book.isbnPrint : book.isbnOnline
                        )
                    }
                }
            }

            if appState.isLoadingChapters && appState.selectedBook?.id == book.id {
                PhoneEmptyState(
                    title: "Loading chapters",
                    message: "The book table of contents is being fetched.",
                    symbol: "text.book.closed"
                )
            } else if appState.selectedBook?.id == book.id && appState.chapters.isEmpty {
                PhoneEmptyState(
                    title: "No chapters found",
                    message: "This title did not return chapter rows from the database.",
                    symbol: "text.book.closed"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dashboardChapters, id: \.id) { chapter in
                        Button {
                            Task { await appState.openChapter(chapter) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: artworkURLs,
                                title: chapter.title,
                                subtitle: chapter.editors,
                                detail: [chapter.bookTitle, chapter.year].filter { !$0.isEmpty }.joined(separator: " • "),
                                badgeText: "Chapter",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: book.id) {
            await appState.selectBook(book)
        }
    }

    private var dashboardChapters: [Chapter] {
        guard appState.selectedBook?.id == book.id else { return [] }
        return appState.chapters
    }

    private var artworkURLs: [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }
}

private struct PhoneDashboardVideoSetDetailScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore

    let set: VideoSet
    let onBack: () -> Void

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Dashboard",
                title: set.setName,
                subtitle: set.editors
            ) {
                PhoneBackButton(label: "Dashboard", action: onBack)
            }

            PhoneSurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    RemoteArtworkView(
                        urls: LegacyConfig.videoCoverCandidates(name: set.setName),
                        aspectRatio: 1.2,
                        cornerRadius: 16,
                        imageAlignment: .top,
                        imageContentMode: .fit,
                        imagePadding: 4
                    )
                    .frame(width: 86, height: 116)

                    VStack(alignment: .leading, spacing: 10) {
                        PhoneInfoLine(label: "Editors", value: set.editors)
                        PhoneInfoLine(label: "Subject", value: set.subject)
                        PhoneInfoLine(
                            label: "Access",
                            value: set.isAccessible(for: appState.session?.userID ?? "") ? "Available" : "Restricted"
                        )
                    }
                }
            }

            if appState.isLoadingVideoSetEntries && appState.selectedVideoSet?.id == set.id {
                PhoneEmptyState(
                    title: "Loading set entries",
                    message: "Fetching the videos inside this collection.",
                    symbol: "arrow.triangle.2.circlepath"
                )
            } else if appState.selectedVideoSet?.id == set.id && appState.videoSetEntries.isEmpty {
                PhoneEmptyState(
                    title: "No set entries found",
                    message: "This collection did not return playable rows.",
                    symbol: "square.stack.3d.up.slash"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dashboardEntries, id: \.id) { entry in
                        Button {
                            Task { await appState.playVideoSetEntry(entry, from: set) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
                                title: entry.title,
                                subtitle: entry.author.isEmpty ? entry.editor : entry.author,
                                detail: entry.setName,
                                badgeText: "Video",
                                trailingText: "Play",
                                playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: set.id) {
            await appState.selectVideoSet(set)
        }
    }

    private var dashboardEntries: [VideoSetEntry] {
        guard appState.selectedVideoSet?.id == set.id else { return [] }
        return appState.videoSetEntries
    }
}

private struct PhoneBackButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: "chevron.left")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.accent)
        }
        .buttonStyle(.plain)
    }
}

private struct PhoneInfoLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.highlight)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PhoneLibraryScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var selectedLibrarySection: PhoneLibrarySection = .journals
    @State private var journalQuery = ""
    @State private var bookQuery = ""
    @State private var videoQuery = ""
    @State private var setQuery = ""
    @State private var activeJournal: Journal?
    @State private var activeIssue: JournalIssue?
    @State private var activeBook: Book?
    @State private var activeSet: VideoSet?

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Library",
                title: "Browse your content",
                subtitle: "Phone-first browsing for journals, books, videos, and training sets."
            ) {
                Button {
                    Task { await appState.refreshCurrentSection() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.86), in: Circle())
                }
                .buttonStyle(.plain)
            }

            PhoneLibrarySegmentedPicker(selection: librarySectionBinding)

            currentLibraryContent
        }
        .task {
            syncSelectionFromAppState()
            consumePendingNavigation()
        }
        .onChange(of: appState.selectedSection) { _ in
            syncSelectionFromAppState()
            consumePendingNavigation()
        }
        .onChange(of: appState.pendingJournalNavigationID) { _ in consumePendingNavigation() }
        .onChange(of: appState.pendingJournalIssueNavigationID) { _ in consumePendingNavigation() }
        .onChange(of: appState.pendingBookNavigationID) { _ in consumePendingNavigation() }
        .onChange(of: appState.pendingVideoSetNavigationID) { _ in consumePendingNavigation() }
    }

    private var librarySectionBinding: Binding<PhoneLibrarySection> {
        Binding(
            get: { selectedLibrarySection },
            set: { newValue in
                selectedLibrarySection = newValue
                appState.selectedSection = newValue.appSection
                if newValue != .journals {
                    activeJournal = nil
                    activeIssue = nil
                }
                if newValue != .books {
                    activeBook = nil
                }
                if newValue != .videoSets {
                    activeSet = nil
                }
            }
        )
    }

    @ViewBuilder
    private var currentLibraryContent: some View {
        switch selectedLibrarySection {
        case .journals:
            journalsContent
        case .books:
            booksContent
        case .videos:
            videosContent
        case .videoSets:
            videoSetsContent
        }
    }

    private var journalsContent: some View {
        Group {
            if let activeJournal {
                if let activeIssue {
                    phoneJournalArticles(for: activeJournal, issue: activeIssue)
                } else {
                    phoneJournalVolumes(for: activeJournal)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    PhoneSearchField(
                        placeholder: "Search journals, ISSN, subject",
                        text: $journalQuery,
                        buttonTitle: "Search"
                    ) {
                        Task { await appState.loadJournals(search: journalQuery) }
                    }

                    if filteredJournals.isEmpty {
                        PhoneEmptyState(
                            title: appState.journals.isEmpty ? "No journals loaded" : "No journals matched",
                            message: appState.journals.isEmpty ? "Pull titles from the server to start browsing." : "Try a broader journal search.",
                            symbol: "newspaper"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredJournals, id: \.id) { journal in
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.coverCandidates(for: journal.name),
                                    title: journal.name,
                                    subtitle: journal.subject.isEmpty ? journal.issn : journal.subject,
                                    detail: journal.subject.isEmpty ? "" : journal.issn,
                                    badgeText: "Journal",
                                    trailingText: "Open",
                                    favoriteSelected: appState.favoritesStore.isFavorite(journal: journal),
                                    favoriteAction: { appState.favoritesStore.toggleJournal(journal) }
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .onTapGesture {
                                    activeJournal = journal
                                    activeIssue = nil
                                    Task { await appState.selectJournal(journal) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func phoneJournalVolumes(for journal: Journal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Journal",
                title: journal.name,
                subtitle: "Select an issue to open its article list."
            ) {
                HStack(spacing: 10) {
                    FavoriteBadgeButton(
                        isSelected: appState.favoritesStore.isFavorite(journal: journal),
                        action: { appState.favoritesStore.toggleJournal(journal) }
                    )

                    Button {
                        activeJournal = nil
                        activeIssue = nil
                        appState.journalReturnSection = nil
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if appState.isLoadingJournalIssues {
                PhoneEmptyState(
                    title: "Loading issues",
                    message: "Fetching recent and archived issues for this journal.",
                    symbol: "arrow.triangle.2.circlepath"
                )
            } else if appState.journalIssues.isEmpty {
                PhoneEmptyState(
                    title: "No issues found",
                    message: "This journal did not return any issue rows.",
                    symbol: "square.stack.3d.up.slash"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.journalIssues, id: \.id) { issue in
                        Button {
                            activeIssue = issue
                            Task { await appState.selectIssue(issue) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.issueCoverCandidates(journal: journal.name, issue: issue.title),
                                title: issue.title,
                                subtitle: journal.name,
                                detail: [issue.year, issue.volume, issue.number].filter { !$0.isEmpty }.joined(separator: " • "),
                                badgeText: "Issue",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func phoneJournalArticles(for journal: Journal, issue: JournalIssue) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Issue",
                title: issue.title,
                subtitle: journal.name
            ) {
                Button {
                    activeIssue = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }

            if appState.isLoadingArticles {
                PhoneEmptyState(
                    title: "Loading articles",
                    message: "Fetching issue articles from the library database.",
                    symbol: "doc.text.magnifyingglass"
                )
            } else if appState.articles.isEmpty {
                PhoneEmptyState(
                    title: "No articles found",
                    message: "This issue did not return article rows.",
                    symbol: "doc.text"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.articles, id: \.id) { article in
                        Button {
                            Task { await appState.openArticle(article) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.issueCoverCandidates(journal: article.journalName, issue: article.issueTitle),
                                title: article.title,
                                subtitle: article.author,
                                detail: [article.journalName, article.issueTitle].joined(separator: " • "),
                                badgeText: "Article",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var booksContent: some View {
        Group {
            if let activeBook {
                phoneBookChapters(for: activeBook)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    PhoneSearchField(
                        placeholder: "Search books, editors, year",
                        text: $bookQuery,
                        buttonTitle: "Search"
                    ) {
                        Task { await appState.loadBooks(search: bookQuery) }
                    }

                    if filteredBooks.isEmpty {
                        PhoneEmptyState(
                            title: appState.books.isEmpty ? "No books loaded" : "No books matched",
                            message: appState.books.isEmpty ? "Pull book titles from the server to start browsing." : "Try a broader book search.",
                            symbol: "books.vertical"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBooks, id: \.id) { book in
                                PhoneRowCard(
                                    artworkURLs: artworkURLs(for: book),
                                    title: book.title,
                                    subtitle: book.editors,
                                    detail: [book.year, book.company].filter { !$0.isEmpty }.joined(separator: " • "),
                                    badgeText: "Book",
                                    trailingText: "Open",
                                    favoriteSelected: appState.favoritesStore.isFavorite(book: book),
                                    favoriteAction: { appState.favoritesStore.toggleBook(book) }
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .onTapGesture {
                                    activeBook = book
                                    Task { await appState.selectBook(book) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func phoneBookChapters(for book: Book) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Book",
                title: book.title,
                subtitle: book.editors
            ) {
                HStack(spacing: 10) {
                    FavoriteBadgeButton(
                        isSelected: appState.favoritesStore.isFavorite(book: book),
                        action: { appState.favoritesStore.toggleBook(book) }
                    )

                    Button {
                        activeBook = nil
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            PhoneSurfaceCard {
                HStack(alignment: .top, spacing: 14) {
                    RemoteArtworkView(urls: artworkURLs(for: book), aspectRatio: 0.76, cornerRadius: 16)
                        .frame(width: 86, height: 116)

                    VStack(alignment: .leading, spacing: 10) {
                        infoLine("Publisher", book.company)
                        infoLine("Year", book.year)
                        infoLine("Subject", book.subject)
                        infoLine("ISBN", book.isbnOnline.isEmpty ? book.isbnPrint : book.isbnOnline)
                    }
                }
            }

            if appState.isLoadingChapters {
                PhoneEmptyState(
                    title: "Loading chapters",
                    message: "Fetching this book's table of contents.",
                    symbol: "text.book.closed"
                )
            } else if appState.chapters.isEmpty {
                PhoneEmptyState(
                    title: "No chapters found",
                    message: "This title did not return chapter rows from the database.",
                    symbol: "text.book.closed"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.chapters, id: \.id) { chapter in
                        Button {
                            Task { await appState.openChapter(chapter) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: artworkURLs(for: book),
                                title: chapter.title,
                                subtitle: chapter.editors,
                                detail: [chapter.bookTitle, chapter.year].filter { !$0.isEmpty }.joined(separator: " • "),
                                badgeText: "Chapter",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var videosContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneSearchField(
                placeholder: "Search videos, author, journal",
                text: $videoQuery,
                buttonTitle: "Search"
            ) {
                Task { await appState.loadVideos(search: videoQuery) }
            }

            if filteredVideos.isEmpty {
                PhoneEmptyState(
                    title: appState.videos.isEmpty ? "No videos loaded" : "No videos matched",
                    message: appState.videos.isEmpty ? "Pull video rows from the server to start browsing." : "Try a broader video search.",
                    symbol: "play.rectangle"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredVideos, id: \.id) { video in
                        Button {
                            Task { await appState.playVideo(video) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
                                title: video.title,
                                subtitle: video.author.isEmpty ? video.editor : video.author,
                                detail: video.bookJournal,
                                badgeText: "Video",
                                trailingText: "Play",
                                playbackRecord: phonePlaybackRecord(for: video, using: videoPlaybackStore)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var videoSetsContent: some View {
        Group {
            if let activeSet {
                phoneVideoSetEntries(for: activeSet)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    PhoneSearchField(
                        placeholder: "Search sets, editors, subject",
                        text: $setQuery,
                        buttonTitle: "Search"
                    ) {
                        Task { await appState.refreshCurrentSection() }
                    }

                    if filteredSets.isEmpty {
                        PhoneEmptyState(
                            title: appState.videoSets.isEmpty ? "No sets loaded" : "No sets matched",
                            message: appState.videoSets.isEmpty ? "Pull set rows from the server to start browsing." : "Try a broader set search.",
                            symbol: "square.stack.3d.up"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSets, id: \.id) { set in
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
                                    title: set.setName,
                                    subtitle: set.editors,
                                    detail: set.subject,
                                    badgeText: set.isAccessible(for: appState.session?.userID ?? "") ? "Available" : "Restricted",
                                    trailingText: "Open",
                                    favoriteSelected: appState.favoritesStore.isFavorite(videoSet: set),
                                    favoriteAction: { appState.favoritesStore.toggleVideoSet(set) }
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .onTapGesture {
                                    activeSet = set
                                    Task { await appState.selectVideoSet(set) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func phoneVideoSetEntries(for set: VideoSet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Set",
                title: set.setName,
                subtitle: "Playable entries for this collection."
            ) {
                HStack(spacing: 10) {
                    FavoriteBadgeButton(
                        isSelected: appState.favoritesStore.isFavorite(videoSet: set),
                        action: { appState.favoritesStore.toggleVideoSet(set) }
                    )

                    Button {
                        activeSet = nil
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if appState.isLoadingVideoSetEntries {
                PhoneEmptyState(
                    title: "Loading set entries",
                    message: "Fetching playable videos for this collection.",
                    symbol: "arrow.triangle.2.circlepath"
                )
            } else if appState.videoSetEntries.isEmpty {
                PhoneEmptyState(
                    title: "No set entries found",
                    message: "This collection did not return playable rows.",
                    symbol: "square.stack.3d.up.slash"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.videoSetEntries, id: \.id) { entry in
                        Button {
                            Task { await appState.playVideoSetEntry(entry, from: set) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
                                title: entry.title,
                                subtitle: entry.author.isEmpty ? entry.editor : entry.author,
                                detail: entry.setName,
                                badgeText: "Video",
                                trailingText: "Play",
                                playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func syncSelectionFromAppState() {
        if let librarySection = PhoneLibrarySection.allCases.first(where: { $0.appSection == appState.selectedSection }) {
            selectedLibrarySection = librarySection
        }
    }

    private func consumePendingNavigation() {
        if let pendingID = appState.pendingJournalNavigationID,
           let selectedJournal = appState.selectedJournal,
           selectedJournal.id == pendingID {
            activeJournal = selectedJournal
            activeIssue = nil
            appState.pendingJournalNavigationID = nil
        }

        if let pendingID = appState.pendingJournalIssueNavigationID,
           let selectedJournal = appState.selectedJournal,
           let selectedIssue = appState.selectedIssue,
           selectedIssue.id == pendingID {
            activeJournal = selectedJournal
            activeIssue = selectedIssue
            appState.pendingJournalIssueNavigationID = nil
        }

        if let pendingID = appState.pendingBookNavigationID,
           let selectedBook = appState.selectedBook,
           selectedBook.id == pendingID {
            activeBook = selectedBook
            appState.pendingBookNavigationID = nil
        }

        if let pendingID = appState.pendingVideoSetNavigationID,
           let selectedSet = appState.selectedVideoSet,
           selectedSet.id == pendingID {
            activeSet = selectedSet
            appState.pendingVideoSetNavigationID = nil
        }
    }

    private var filteredJournals: [Journal] {
        let query = journalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.journals }
        return appState.journals.filter {
            [$0.name, $0.issn, $0.subject].joined(separator: " ").matchesNormalizedSearch(query)
        }
    }

    private var filteredBooks: [Book] {
        let query = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.books }
        return appState.books.filter {
            [$0.title, $0.editors, $0.year, $0.company, $0.subject, $0.isbnOnline]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var filteredVideos: [Video] {
        let query = videoQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.videos }
        return appState.videos.filter {
            [$0.title, $0.author, $0.editor, $0.bookJournal]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var filteredSets: [VideoSet] {
        let query = setQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.videoSets }
        return appState.videoSets.filter {
            [$0.setName, $0.editors, $0.subject]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private func artworkURLs(for book: Book) -> [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Palette.highlight)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
    }
}

private struct PhoneSearchExperienceScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var query = ""
    @State private var lastQuery = ""
    @State private var selectedPage: PhoneSearchPage = .all

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Search",
                title: "Find across the library",
                subtitle: "One search box for articles, chapters, videos, and set entries."
            )

            PhoneSearchField(
                placeholder: "Search title, author, editor, subject",
                text: $query,
                buttonTitle: "Go"
            ) {
                submitSearch()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhoneSearchPage.allCases) { page in
                        Button {
                            selectedPage = page
                        } label: {
                            Text(page.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedPage == page ? Color.white : Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedPage == page ? Palette.accent : Color.white.opacity(0.84))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if appState.searchResults.isEmpty {
                PhoneEmptyState(
                    title: lastQuery.isEmpty ? "Start with a search" : "No results found",
                    message: lastQuery.isEmpty ? "Use a keyword to search the entire library." : "Try a broader phrase or switch result type.",
                    symbol: "magnifyingglass.circle"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(currentSearchItems) { item in
                        switch item {
                        case .article(let article):
                            Button {
                                Task { await appState.openArticle(article) }
                            } label: {
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.issueCoverCandidates(journal: article.journalName, issue: article.issueTitle),
                                    title: article.title,
                                    subtitle: article.author,
                                    detail: [article.journalName, article.issueTitle].joined(separator: " • "),
                                    badgeText: "Article",
                                    trailingText: "Open"
                                )
                            }
                            .buttonStyle(.plain)
                        case .chapter(let chapter):
                            Button {
                                Task { await appState.openChapter(chapter) }
                            } label: {
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.bookCoverCandidates(isbn: chapter.isbn),
                                    title: chapter.title,
                                    subtitle: chapter.editors,
                                    detail: [chapter.bookTitle, chapter.year].joined(separator: " • "),
                                    badgeText: "Book",
                                    trailingText: "Open"
                                )
                            }
                            .buttonStyle(.plain)
                        case .video(let video):
                            Button {
                                Task { await appState.playVideoFromSearch(video, scope: selectedPage.videoRailScope) }
                            } label: {
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: video.imageLink),
                                    title: video.title,
                                    subtitle: video.author.isEmpty ? video.editor : video.author,
                                    detail: video.bookJournal,
                                    badgeText: "Video",
                                    trailingText: "Play",
                                    playbackRecord: phonePlaybackRecord(for: video, using: videoPlaybackStore)
                                )
                            }
                            .buttonStyle(.plain)
                        case .videoSet(let entry):
                            Button {
                                Task { await appState.openVideoSetEntryFromSearch(entry, scope: selectedPage.videoRailScope) }
                            } label: {
                                PhoneRowCard(
                                    artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
                                    title: entry.title,
                                    subtitle: entry.author.isEmpty ? entry.editor : entry.author,
                                    detail: entry.setName,
                                    badgeText: "Set",
                                    trailingText: "Open",
                                    playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var currentSearchItems: [PhoneCombinedSearchItem] {
        switch selectedPage {
        case .all:
            return (
                appState.searchResults.articles.map(PhoneCombinedSearchItem.article)
                + appState.searchResults.chapters.map(PhoneCombinedSearchItem.chapter)
                + appState.searchResults.videos.map(PhoneCombinedSearchItem.video)
                + appState.searchResults.videoSetEntries.map(PhoneCombinedSearchItem.videoSet)
            ).sorted { $0.sortDate > $1.sortDate }
        case .journals:
            return appState.searchResults.articles.map(PhoneCombinedSearchItem.article)
        case .books:
            return appState.searchResults.chapters.map(PhoneCombinedSearchItem.chapter)
        case .videos:
            return appState.searchResults.videos.map(PhoneCombinedSearchItem.video)
        case .videoSets:
            return appState.searchResults.videoSetEntries.map(PhoneCombinedSearchItem.videoSet)
        }
    }

    private func submitSearch() {
        lastQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            await appState.runSearch(lastQuery)
        }
    }
}

private struct PhoneHistoryExperienceScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var selectedPage: PhoneHistoryPage = .all
    @State private var searchText = ""
    @State private var visibleItemCount = 50

    private let pageSize = 50

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "History",
                title: "Recently opened",
                subtitle: "Quickly jump back into the PDFs and videos you already opened."
            ) {
                Button {
                    Task { await appState.refreshHistory(kind: selectedPage.historyKind) }
                } label: {
                    HStack(spacing: 6) {
                        if appState.isRefreshingHistory {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Refresh")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.82), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhoneHistoryPage.allCases) { page in
                        Button {
                            selectedPage = page
                        } label: {
                            Text(page.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(selectedPage == page ? Color.white : Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedPage == page ? Palette.accent : Color.white.opacity(0.84))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            PhoneSearchField(
                placeholder: "Filter title, source, author",
                text: $searchText,
                buttonTitle: "Clear"
            ) {
                searchText = ""
            }

            if filteredEntries.isEmpty {
                PhoneEmptyState(
                    title: "No history found",
                    message: hasSearch ? "Try a different filter." : "Open a document or video to build your recent list.",
                    symbol: "clock.badge.questionmark"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleEntries) { entry in
                        Button {
                            let visibleEntries = visibleEntries
                            Task { await appState.reopenHistoryEntry(entry, historyContext: visibleEntries) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: coverURLs(for: entry),
                                title: entry.title,
                                subtitle: entry.subtitle,
                                detail: entry.detail,
                                badgeText: entry.kind.title,
                                trailingText: LegacyDate.historyListFormatter.string(from: entry.openedAt),
                                playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            loadMoreIfNeeded(currentEntry: entry)
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
        .onChange(of: selectedPage) { _ in
            resetPaginationAndPrepareHistory()
        }
        .onChange(of: searchText) { _ in
            visibleItemCount = pageSize
        }
    }

    private var filteredEntries: [HistoryEntry] {
        let baseEntries: [HistoryEntry]
        switch selectedPage {
        case .all: baseEntries = appState.historyStore.entries
        case .articles: baseEntries = appState.historyStore.entries.filter { $0.kind == .article }
        case .books: baseEntries = appState.historyStore.entries.filter { $0.kind == .chapter }
        case .videos: baseEntries = appState.historyStore.entries.filter { $0.kind == .video }
        case .videoSets: baseEntries = appState.historyStore.entries.filter { $0.kind == .videoSet }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return baseEntries }
        return baseEntries.filter {
            [$0.title, $0.subtitle, $0.detail, $0.kind.title]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var visibleEntries: [HistoryEntry] {
        Array(filteredEntries.prefix(visibleItemCount))
    }

    private var hasSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func coverURLs(for entry: HistoryEntry) -> [URL] {
        guard let url = URL(string: entry.coverURLString) else { return [] }
        return [url]
    }

    private func applyPreferredPageSelection() {
        switch appState.preferredHistoryPageRawValue {
        case "articles": selectedPage = .articles
        case "books": selectedPage = .books
        case "videos": selectedPage = .videos
        case "videoSets": selectedPage = .videoSets
        default: selectedPage = .all
        }
        searchText = ""
    }

    private func resetPaginationAndPrepareHistory() {
        visibleItemCount = pageSize
        appState.prepareHistoryInBackgroundIfNeeded(
            kind: selectedPage.historyKind,
            minimumCount: pageSize,
            force: false
        )
    }

    private func loadMoreIfNeeded(currentEntry entry: HistoryEntry) {
        guard visibleEntries.last?.id == entry.id else { return }
        guard visibleItemCount < filteredEntries.count else { return }
        visibleItemCount = min(visibleItemCount + pageSize, filteredEntries.count)
    }
}

private struct PhoneProfileExperienceScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @State private var selectedDetail: ProfileDetailSection?
    @State private var activeFavoriteBook: Book?
    @State private var activeFavoriteSet: VideoSet?

    var body: some View {
        PhonePageScroll {
            PhoneHeaderBlock(
                eyebrow: "Profile",
                title: "Usage & favorites",
                subtitle: "Your saved content and recent activity in one place."
            ) {
                Button {
                    Task { await appState.refreshProfile() }
                } label: {
                    Text("Refresh")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.82), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let profile = appState.profile {
                PhoneSurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("E-mail", profile.email)
                        infoRow("User ID", profile.userID)
                        infoRow("Subject", profile.subject)
                        infoRow("Access", profile.expireDate)
                        infoRow("Serial", profile.serial)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        profileMetricButton("Articles", profile.articleCount, tint: Palette.accent, section: .articleHistory)
                        profileMetricButton("Chapters", profile.chapterCount, tint: Palette.highlight, section: .chapterHistory)
                        profileMetricButton("Videos", profile.videoCount, tint: Palette.gold, section: .videoHistory)
                        profileMetricButton("Set Videos", profile.videoSetCount, tint: Palette.accent, section: .videoSetHistory)
                        profileMetricButton("Fav Journals", profile.favoriteJournalCount, tint: Palette.accent, section: .favoriteJournals)
                        profileMetricButton("Fav Books", profile.favoriteBookCount, tint: Palette.highlight, section: .favoriteBooks)
                        profileMetricButton("Fav Sets", profile.favoriteVideoSetCount, tint: Palette.gold, section: .favoriteVideoSets)
                    }
                }

                if let activeFavoriteBook {
                    PhoneSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Button {
                                self.activeFavoriteBook = nil
                            } label: {
                                Label("Back To Favorite Books", systemImage: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.accent)
                            }
                            .buttonStyle(.plain)

                            PhoneLibraryScreenBookDetail(book: activeFavoriteBook)
                                .environmentObject(appState)
                        }
                    }
                } else if let activeFavoriteSet {
                    PhoneSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Button {
                                self.activeFavoriteSet = nil
                            } label: {
                                Label("Back To Favorite Sets", systemImage: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.accent)
                            }
                            .buttonStyle(.plain)

                            PhoneLibraryScreenVideoSetDetail(set: activeFavoriteSet)
                                .environmentObject(appState)
                        }
                    }
                } else if let selectedDetail {
                    PhoneSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                PhoneSectionHeader(title: selectedDetail.title, subtitle: selectedDetail.subtitle)
                                Spacer()
                                Button("Hide") {
                                    self.selectedDetail = nil
                                    appState.profileSelectedDetailSectionRawValue = nil
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.accent)
                            }

                            profileDetailContent(for: selectedDetail)
                        }
                    }
                }
            } else {
                PhoneEmptyState(
                    title: "Profile is not ready",
                    message: "Refresh the profile to pull usage counts and favorites.",
                    symbol: "person.text.rectangle"
                )
            }
        }
    }

    private func profileMetricButton(_ title: String, _ value: Int, tint: Color, section: ProfileDetailSection) -> some View {
        Button {
            toggleDetail(section)
        } label: {
            PhoneMetricPill(title: title, value: value, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func toggleDetail(_ section: ProfileDetailSection) {
        if selectedDetail == section {
            selectedDetail = nil
            activeFavoriteBook = nil
            activeFavoriteSet = nil
            appState.profileSelectedDetailSectionRawValue = nil
            return
        }

        selectedDetail = section
        activeFavoriteBook = nil
        activeFavoriteSet = nil
        appState.profileSelectedDetailSectionRawValue = section.rawValue

        Task { await prepare(section) }
    }

    private func prepare(_ section: ProfileDetailSection) async {
        switch section {
        case .articleHistory:
            if articleHistory.isEmpty { await appState.refreshHistory(kind: .article) }
        case .chapterHistory:
            if chapterHistory.isEmpty { await appState.refreshHistory(kind: .chapter) }
        case .videoHistory:
            if videoHistory.isEmpty { await appState.refreshHistory(kind: .video) }
        case .videoSetHistory:
            if videoSetHistory.isEmpty { await appState.refreshHistory(kind: .videoSet) }
        case .favoriteJournals:
            if favoriteJournals.isEmpty { await appState.loadJournals() }
        case .favoriteBooks:
            if favoriteBooks.isEmpty { await appState.loadBooks() }
        case .favoriteVideoSets:
            if favoriteVideoSets.isEmpty { await appState.loadVideoSetsForProfile() }
        }
    }

    @ViewBuilder
    private func profileDetailContent(for section: ProfileDetailSection) -> some View {
        switch section {
        case .articleHistory:
            profileHistoryList(articleHistory)
        case .chapterHistory:
            profileHistoryList(chapterHistory)
        case .videoHistory:
            profileHistoryList(videoHistory)
        case .videoSetHistory:
            profileHistoryList(videoSetHistory)
        case .favoriteJournals:
            if favoriteJournals.isEmpty {
                PhoneEmptyState(title: "No favorite journals", message: "Pin journals to keep them here.", symbol: "star")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(favoriteJournals, id: \.id) { journal in
                        Button {
                            appState.showFavoriteJournals()
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.coverCandidates(for: journal.name),
                                title: journal.name,
                                subtitle: journal.subject,
                                detail: journal.issn,
                                badgeText: "Journal",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .favoriteBooks:
            if favoriteBooks.isEmpty {
                PhoneEmptyState(title: "No favorite books", message: "Pin books to keep them here.", symbol: "star")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(favoriteBooks, id: \.id) { book in
                        Button {
                            activeFavoriteSet = nil
                            activeFavoriteBook = book
                            Task { await appState.selectBook(book) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: artworkURLs(for: book),
                                title: book.title,
                                subtitle: book.editors,
                                detail: [book.year, book.company].filter { !$0.isEmpty }.joined(separator: " • "),
                                badgeText: "Book",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .favoriteVideoSets:
            if favoriteVideoSets.isEmpty {
                PhoneEmptyState(title: "No favorite sets", message: "Pin video sets to keep them here.", symbol: "star")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(favoriteVideoSets, id: \.id) { set in
                        Button {
                            activeFavoriteBook = nil
                            activeFavoriteSet = set
                            Task { await appState.selectVideoSet(set) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.videoCoverCandidates(name: set.setName),
                                title: set.setName,
                                subtitle: set.editors,
                                detail: set.subject,
                                badgeText: "Set",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profileHistoryList(_ entries: [HistoryEntry]) -> some View {
        if entries.isEmpty {
            PhoneEmptyState(title: "No items yet", message: "Open content to build a quick return list here.", symbol: "clock")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(entries) { entry in
                    Button {
                        let visibleEntries = entries
                        Task { await appState.reopenHistoryEntry(entry, historyContext: visibleEntries) }
                    } label: {
                        PhoneRowCard(
                            artworkURLs: coverURLs(for: entry),
                            title: entry.title,
                            subtitle: entry.subtitle,
                            detail: entry.detail,
                            badgeText: entry.kind.title,
                            trailingText: LegacyDate.historyListFormatter.string(from: entry.openedAt),
                            playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var articleHistory: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .article }
    }

    private var chapterHistory: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .chapter }
    }

    private var videoHistory: [HistoryEntry] {
        appState.historyStore.entries.filter { $0.kind == .video }
    }

    private var videoSetHistory: [HistoryEntry] {
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

    private func coverURLs(for entry: HistoryEntry) -> [URL] {
        guard let url = URL(string: entry.coverURLString) else { return [] }
        return [url]
    }

    private func artworkURLs(for book: Book) -> [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(width: 78, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
    }
}

private struct PhoneLibraryScreenBookDetail: View {
    @EnvironmentObject private var appState: AppState
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Book",
                title: book.title,
                subtitle: book.editors
            )

            if appState.isLoadingChapters {
                PhoneEmptyState(
                    title: "Loading chapters",
                    message: "Fetching this book's table of contents.",
                    symbol: "text.book.closed"
                )
            } else if appState.chapters.isEmpty {
                PhoneEmptyState(
                    title: "No chapters found",
                    message: "This title did not return chapter rows.",
                    symbol: "text.book.closed"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.chapters, id: \.id) { chapter in
                        Button {
                            Task { await appState.openChapter(chapter) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline),
                                title: chapter.title,
                                subtitle: chapter.editors,
                                detail: [chapter.bookTitle, chapter.year].joined(separator: " • "),
                                badgeText: "Chapter",
                                trailingText: "Open"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct PhoneLibraryScreenVideoSetDetail: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    let set: VideoSet

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PhoneHeaderBlock(
                eyebrow: "Set",
                title: set.setName,
                subtitle: set.editors
            )

            if appState.isLoadingVideoSetEntries {
                PhoneEmptyState(
                    title: "Loading set entries",
                    message: "Fetching playable videos for this collection.",
                    symbol: "arrow.triangle.2.circlepath"
                )
            } else if appState.videoSetEntries.isEmpty {
                PhoneEmptyState(
                    title: "No set entries found",
                    message: "This set did not return playable rows.",
                    symbol: "square.stack.3d.up.slash"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.videoSetEntries, id: \.id) { entry in
                        Button {
                            Task { await appState.playVideoSetEntry(entry, from: set) }
                        } label: {
                            PhoneRowCard(
                                artworkURLs: LegacyConfig.videoCoverCandidates(name: entry.imageLink),
                                title: entry.title,
                                subtitle: entry.author.isEmpty ? entry.editor : entry.author,
                                detail: entry.setName,
                                badgeText: "Video",
                                trailingText: "Play",
                                playbackRecord: phonePlaybackRecord(for: entry, using: videoPlaybackStore)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
#endif
