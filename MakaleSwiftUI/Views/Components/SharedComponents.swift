#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif
import AVKit
import CryptoKit
import ImageIO
import PDFKit
import SwiftUI

enum Palette {
    static let canvas = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let surface = Color.white.opacity(0.84)
    static let surfaceStrong = Color.white.opacity(0.95)
    static let ink = Color(red: 0.13, green: 0.16, blue: 0.17)
    static let muted = Color(red: 0.37, green: 0.43, blue: 0.42)
    static let accent = Color(red: 0.14, green: 0.43, blue: 0.39)
    static let accentSoft = Color(red: 0.85, green: 0.93, blue: 0.90)
    static let highlight = Color(red: 0.82, green: 0.41, blue: 0.27)
    static let gold = Color(red: 0.85, green: 0.66, blue: 0.24)
    static let danger = Color(red: 0.75, green: 0.28, blue: 0.24)
}

struct AppCanvas<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Palette.canvas,
                    Color(red: 0.90, green: 0.93, blue: 0.91),
                    Color(red: 0.96, green: 0.92, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Palette.accentSoft.opacity(0.55))
                .frame(width: 460, height: 460)
                .blur(radius: 18)
                .offset(x: -420, y: -280)

            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: 430, y: 280)

            content
        }
        .foregroundStyle(Palette.ink)
    }
}

struct BusyOverlay: View {
    let title: String
    let detail: String
    let progress: Double?

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 16) {
                if let progress {
                    VStack(spacing: 10) {
                        ProgressView(value: progress, total: 1)
                            .progressViewStyle(.linear)
                            .tint(Palette.accent)
                            .frame(width: 220)
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.custom("Avenir Next Demi Bold", size: 14))
                            .foregroundStyle(Palette.accent)
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Palette.accent)
                }

                Text(title.isEmpty ? "Please wait" : title)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                    .foregroundStyle(Palette.ink)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.2), value: title)
        .animation(.easeInOut(duration: 0.2), value: detail)
        .animation(.easeInOut(duration: 0.2), value: progress ?? -1)
    }
}

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var titleSize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.custom("Avenir Next Demi Bold", size: 12))
                .tracking(1.6)
                .foregroundStyle(Palette.highlight)
            Text(title)
                .font(.custom("Avenir Next Bold", size: titleSize))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.custom("Avenir Next Regular", size: 15))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

struct SearchInputField: View {
    let placeholder: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .search
    var onSubmitAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.muted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .submitLabel(submitLabel)
                .onSubmit {
                    onSubmitAction?()
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
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
    }
}

struct MetricChip: View {
    let label: String
    let value: String
    let tint: Color

    init(label: String, value: String, tint: Color) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    init(label: String, value: Int, tint: Color) {
        self.init(
            label: label,
            value: value.formatted(.number.grouping(.automatic)),
            tint: tint
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.custom("Avenir Next Demi Bold", size: 10))
                .tracking(0.9)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.custom("Avenir Next Bold", size: 20))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 84, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct FavoriteBadgeButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Palette.gold : Palette.muted)
                .padding(8)
                .background(Color.white.opacity(0.78), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class ArtworkLoader: ObservableObject {
    private static let cache: NSCache<NSURL, PlatformImage> = {
        let cache = NSCache<NSURL, PlatformImage>()
        cache.countLimit = 240
        return cache
    }()
    private static let diskCacheDirectory: URL? = {
        guard let baseDirectory = try? LegacyConfig.applicationSupportDirectory() else { return nil }
        let cacheDirectory = baseDirectory.appendingPathComponent("ArtworkCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        return cacheDirectory
    }()

    @Published private(set) var image: PlatformImage?
    @Published private(set) var isLoading = false

    private var currentKey = ""
    private var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    func load(urls: [URL]) {
        let key = urls.map(\.absoluteString).joined(separator: "|")
        guard currentKey != key || (image == nil && !isLoading) else { return }

        currentKey = key
        loadTask?.cancel()

        if let cached = Self.cachedImage(for: urls) {
            image = cached
            isLoading = false
            return
        }

        image = nil
        guard !urls.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        loadTask = Task {
            let loadedImage = await Self.loadFirstAvailableImage(from: urls)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.currentKey == key else { return }
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }

    static func cachedImage(for urls: [URL]) -> PlatformImage? {
        for url in urls {
            if let cached = cache.object(forKey: url as NSURL) {
                return cached
            }

            if let diskCached = diskCachedImage(for: url) {
                cache.setObject(diskCached, forKey: url as NSURL)
                return diskCached
            }
        }

        return nil
    }

    private static func loadFirstAvailableImage(from urls: [URL]) async -> PlatformImage? {
        for url in urls {
            if let cached = cache.object(forKey: url as NSURL) {
                return cached
            }

            if let diskCached = diskCachedImage(for: url) {
                cache.setObject(diskCached, forKey: url as NSURL)
                return diskCached
            }

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 20

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = thumbnailImage(from: data) else {
                    continue
                }

                cache.setObject(image, forKey: url as NSURL)
                persistImageData(data, for: url)
                return image
            } catch {
                continue
            }
        }

        return nil
    }

    private static func diskCachedImage(for url: URL) -> PlatformImage? {
        guard let fileURL = cacheFileURL(for: url),
              let data = try? Data(contentsOf: fileURL),
              let image = thumbnailImage(from: data) else {
            return nil
        }

        return image
    }

    private static func persistImageData(_ data: Data, for url: URL) {
        guard let fileURL = cacheFileURL(for: url) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private static func cacheFileURL(for url: URL) -> URL? {
        guard let diskCacheDirectory else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined()
        return diskCacheDirectory.appendingPathComponent(fileName).appendingPathExtension("img")
    }

    private static func thumbnailImage(from data: Data, maxPixelSize: CGFloat = 420) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

#if canImport(AppKit)
        return NSImage(cgImage: cgImage, size: .zero)
#elseif canImport(UIKit)
        return UIImage(cgImage: cgImage)
#else
        return nil
#endif
    }
}

struct RemoteArtworkView: View {
    let urls: [URL]
    var aspectRatio: CGFloat = 0.72
    var cornerRadius: CGFloat = 22
    var imageAlignment: Alignment = .center
    var imageContentMode: ContentMode = .fill
    var imagePadding: CGFloat = 0

    @StateObject private var loader = ArtworkLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.accentSoft, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = loader.image ?? ArtworkLoader.cachedImage(for: urls) {
#if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: imageContentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: imageAlignment)
                    .padding(imagePadding)
#else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: imageContentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: imageAlignment)
                    .padding(imagePadding)
#endif
            } else if loader.isLoading {
                ProgressView().tint(Palette.accent)
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: urls.map(\.absoluteString).joined(separator: "|")) {
            loader.load(urls: urls)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.accent.opacity(0.8))
            Text("Makale")
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(Palette.muted)
        }
    }
}

struct MediaCard<Content: View>: View {
    let artworkURLs: [URL]
    let favoriteSelected: Bool?
    let favoriteAction: (() -> Void)?
    let artworkAspectRatio: CGFloat
    let contentSpacing: CGFloat
    let cardPadding: CGFloat
    let content: Content

    init(
        artworkURLs: [URL],
        favoriteSelected: Bool? = nil,
        favoriteAction: (() -> Void)? = nil,
        artworkAspectRatio: CGFloat = 0.8,
        contentSpacing: CGFloat = 10,
        cardPadding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.artworkURLs = artworkURLs
        self.favoriteSelected = favoriteSelected
        self.favoriteAction = favoriteAction
        self.artworkAspectRatio = artworkAspectRatio
        self.contentSpacing = contentSpacing
        self.cardPadding = cardPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            ZStack(alignment: .topTrailing) {
                RemoteArtworkView(urls: artworkURLs, aspectRatio: artworkAspectRatio, cornerRadius: 20)
                if let favoriteSelected, let favoriteAction {
                    FavoriteBadgeButton(isSelected: favoriteSelected, action: favoriteAction)
                        .padding(10)
                }
            }

            content
        }
        .padding(cardPadding)
        .background(Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

struct CompactMediaRowCard<Details: View, Footer: View>: View {
    let artworkURLs: [URL]
    let title: String
    let favoriteSelected: Bool?
    let favoriteAction: (() -> Void)?
    let playbackRecord: VideoPlaybackRecord?
    let artworkAspectRatio: CGFloat
    let artworkWidth: CGFloat
    let artworkHeight: CGFloat
    let cornerRadius: CGFloat
    let cardPadding: CGFloat
    let titleSize: CGFloat
    let titleLineLimit: Int
    let contentSpacing: CGFloat
    let details: Details
    let footer: Footer

    init(
        artworkURLs: [URL],
        title: String,
        favoriteSelected: Bool? = nil,
        favoriteAction: (() -> Void)? = nil,
        playbackRecord: VideoPlaybackRecord? = nil,
        artworkAspectRatio: CGFloat = 0.78,
        artworkWidth: CGFloat = 84,
        artworkHeight: CGFloat = 108,
        cornerRadius: CGFloat = 11,
        cardPadding: CGFloat = 9,
        titleSize: CGFloat = 12,
        titleLineLimit: Int = 2,
        contentSpacing: CGFloat = 4,
        @ViewBuilder details: () -> Details,
        @ViewBuilder footer: () -> Footer
    ) {
        self.artworkURLs = artworkURLs
        self.title = title
        self.favoriteSelected = favoriteSelected
        self.favoriteAction = favoriteAction
        self.playbackRecord = playbackRecord
        self.artworkAspectRatio = artworkAspectRatio
        self.artworkWidth = artworkWidth
        self.artworkHeight = artworkHeight
        self.cornerRadius = cornerRadius
        self.cardPadding = cardPadding
        self.titleSize = titleSize
        self.titleLineLimit = titleLineLimit
        self.contentSpacing = contentSpacing
        self.details = details()
        self.footer = footer()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteArtworkView(
                urls: artworkURLs,
                aspectRatio: artworkAspectRatio,
                cornerRadius: cornerRadius
            )
            .frame(width: artworkWidth, height: artworkHeight)
            .clipped()

            VStack(alignment: .leading, spacing: contentSpacing) {
                HStack(alignment: .top, spacing: 7) {
                    Text(title)
                        .font(.custom("Avenir Next Demi Bold", size: titleSize))
                        .lineLimit(titleLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let favoriteSelected, let favoriteAction {
                        Spacer(minLength: 6)

                        FavoriteBadgeButton(
                            isSelected: favoriteSelected,
                            action: favoriteAction
                        )
                        .frame(width: 30, height: 30, alignment: .topTrailing)
                    }
                }

                details

                if let playbackRecord {
                    PlaybackProgressSummary(record: playbackRecord)
                }

                Spacer(minLength: 3)

                footer
            }
            .frame(maxWidth: .infinity, minHeight: artworkHeight, alignment: .topLeading)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, minHeight: artworkHeight + (cardPadding * 2) + 2, alignment: .topLeading)
        .background(Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 7, y: 3)
    }
}

enum PlaybackProgressFormatting {
    static func timeString(seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let paddedSeconds = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        if hours > 0 {
            let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
            return "\(hours):\(paddedMinutes):\(paddedSeconds)"
        }

        return "\(minutes):\(paddedSeconds)"
    }
}

struct PlaybackProgressSummary: View {
    let record: VideoPlaybackRecord
    var compact: Bool = true

    private var progressFraction: Double? {
        if record.isCompleted {
            return 1
        }
        return record.progressFraction
    }

    private var leadingText: String {
        if record.isCompleted {
            return "Completed"
        }
        if record.lastPositionSeconds >= 8 {
            return "Resume"
        }
        return "Watched"
    }

    private var trailingText: String {
        if let durationSeconds = record.durationSeconds, durationSeconds > 0 {
            let currentSeconds = record.isCompleted ? durationSeconds : max(record.lastPositionSeconds, 0)
            return "\(PlaybackProgressFormatting.timeString(seconds: currentSeconds)) / \(PlaybackProgressFormatting.timeString(seconds: durationSeconds))"
        }

        return PlaybackProgressFormatting.timeString(seconds: max(record.lastPositionSeconds, record.watchedSeconds))
    }

    private var barTint: Color {
        record.isCompleted ? Palette.accent : Palette.highlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 8) {
                Text(leadingText)
                    .font(.custom("Avenir Next Demi Bold", size: compact ? 9 : 11))
                    .foregroundStyle(record.isCompleted ? Palette.accent : Palette.muted)

                Spacer(minLength: 0)

                Text(trailingText)
                    .font(.custom("Avenir Next Medium", size: compact ? 9 : 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }

            if let progressFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Palette.accentSoft.opacity(0.9))

                        Capsule(style: .continuous)
                            .fill(barTint)
                            .frame(width: max(proxy.size.width * progressFraction, progressFraction > 0 ? 10 : 0))
                    }
                }
                .frame(height: compact ? 5 : 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbolName: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.accent)
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 20))
            Text(message)
                .font(.custom("Avenir Next Regular", size: 14))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(36)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(Palette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next Demi Bold", size: 12))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.1), in: Capsule())
    }
}

@MainActor
final class PDFReaderNavigator: ObservableObject {
    @Published private(set) var currentPageIndex = 1
    @Published private(set) var pageCount = 1

    weak var pdfView: PDFView?

    func attach(to pdfView: PDFView) {
        self.pdfView = pdfView
        refresh()
    }

    func refresh() {
        let resolvedPageCount = pdfView?.document?.pageCount ?? 0
        pageCount = max(resolvedPageCount, 1)

        guard let pdfView,
              let document = pdfView.document,
              let currentPage = pdfView.currentPage else {
            currentPageIndex = 1
            return
        }

        currentPageIndex = max(document.index(for: currentPage) + 1, 1)
    }

    var canGoPrevious: Bool {
        currentPageIndex > 1
    }

    var canGoNext: Bool {
        currentPageIndex < pageCount
    }

    func goToPreviousPage() {
        pdfView?.goToPreviousPage(nil)
        refresh()
    }

    func goToNextPage() {
        pdfView?.goToNextPage(nil)
        refresh()
    }
}

struct DocumentViewerScreen: View {
    let document: DocumentPresentation
    let backLabel: String
    let onClose: () -> Void
    let showsMetadataHeader: Bool
    @StateObject private var pdfNavigator = PDFReaderNavigator()

    init(
        document: DocumentPresentation,
        backLabel: String,
        showsMetadataHeader: Bool = true,
        onClose: @escaping () -> Void
    ) {
        self.document = document
        self.backLabel = backLabel
        self.showsMetadataHeader = showsMetadataHeader
        self.onClose = onClose
    }

    var body: some View {
#if os(iOS)
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            PDFContainerView(url: document.url, navigator: pdfNavigator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            readerTopBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            readerBottomBar
        }
#else
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(action: onClose) {
                    Label(backLabel, systemImage: "chevron.left")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                Spacer()
#if os(macOS)
                Button("Export") { exportPDF() }
#endif
            }

            if showsMetadataHeader {
                ScreenHeader(
                    eyebrow: "Reader",
                    title: document.title,
                    subtitle: document.url.lastPathComponent
                )
            }

#if os(macOS)
            PDFContainerView(url: document.url)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 720)
#else
            SectionCard {
                PDFContainerView(url: document.url)
                    .frame(minHeight: 540)
            }
#endif
        }
#endif
    }

#if os(macOS)
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.url.lastPathComponent
        if panel.runModal() == .OK, let destination = panel.url {
            try? FileManager.default.copyItem(at: document.url, to: destination)
        }
    }
#endif

#if os(iOS)
    private var readerTopBar: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(backLabel)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 108, alignment: .leading)

            Spacer()

            ShareLink(item: document.url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, alignment: .trailing)
        }
        .overlay {
            Text("PDF View")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(Color.black.opacity(0.05))
        }
    }

    private var readerBottomBar: some View {
        HStack {
            Text("\(pdfNavigator.currentPageIndex) of \(pdfNavigator.pageCount)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .frame(minWidth: 72, alignment: .leading)

            Spacer()

            HStack(spacing: 10) {
                readerNavButton(
                    systemImage: "chevron.left",
                    enabled: pdfNavigator.canGoPrevious,
                    action: { pdfNavigator.goToPreviousPage() }
                )

                Text("\(pdfNavigator.currentPageIndex) / \(pdfNavigator.pageCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 58)

                readerNavButton(
                    systemImage: "chevron.right",
                    enabled: pdfNavigator.canGoNext,
                    action: { pdfNavigator.goToNextPage() }
                )
            }

            Spacer()

            Color.clear
                .frame(width: 72, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
                .overlay(Color.black.opacity(0.05))
        }
    }

    private func readerNavButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? Palette.ink : Palette.muted.opacity(0.45))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(enabled ? 0.95 : 0.55), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
#endif
}

struct VideoPlayerScreen: View {
    @EnvironmentObject private var videoDownloadManager: VideoDownloadManager
    @EnvironmentObject private var videoPlaybackStore: VideoPlaybackStore
    @Environment(\.scenePhase) private var scenePhase
    let video: VideoPresentation
    let backLabel: String
    let onClose: () -> Void
    @State private var player: AVPlayer
    @State private var currentItem: VideoRailItem
    @State private var timeObserverToken: Any?
    @State private var playbackEndObserver: NSObjectProtocol?
    @State private var lastTrackedPlaybackSecond: Double?
#if os(iOS)
    @State private var focusedRailItemID: String?
    @State private var selectionCommitTask: Task<Void, Never>?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    init(video: VideoPresentation, backLabel: String, onClose: @escaping () -> Void) {
        self.video = video
        self.backLabel = backLabel
        self.onClose = onClose
        _player = State(initialValue: AVPlayer(url: video.url))
        _currentItem = State(initialValue: video.currentItem)
#if os(iOS)
        _focusedRailItemID = State(initialValue: video.currentItem.id)
#endif
    }

    var body: some View {
        if #available(macOS 14.0, *) {
            Group {
#if os(iOS)
                iosVideoBody
#else
                macVideoBody
#endif
            }
            .onAppear {
                installPeriodicProgressObserverIfNeeded()
                preparePlayback(for: currentItem, replaceCurrentItem: false)
            }
            .onDisappear {
                persistCurrentPlaybackProgress()
                player.pause()
                removePlayerObservers()
#if os(iOS)
                selectionCommitTask?.cancel()
#endif
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    persistCurrentPlaybackProgress()
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }

#if os(macOS)
    private var macVideoBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text(backLabel)
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                downloadActionButton
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PLAYING NOW")
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                    .tracking(1.4)
                    .foregroundStyle(Palette.highlight)

                Text(currentItem.title)
                    .font(.custom("Avenir Next Medium", size: videoTitleSize))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SectionCard {
                ZStack(alignment: .bottomTrailing) {
                    MacVideoPlayerContainer(player: player)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 620)

                    HStack(spacing: 10) {
                        PlayerSkipButton(
                            systemImage: "gobackward.10",
                            action: { seek(by: -10) }
                        )

                        PlayerSkipButton(
                            systemImage: "goforward.10",
                            action: { seek(by: 10) }
                        )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 22)
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Video details")
                        .font(.custom("Avenir Next Demi Bold", size: 15))
                        .foregroundStyle(Palette.ink)

                    MacVideoMetaCard(
                        systemImage: currentItem.sourceKind.systemImage,
                        title: currentItem.sourceKind.cardTitle,
                        detail: currentItem.sourceName,
                        caption: currentItem.sourceDetail.isEmpty ? currentItem.sourceKind.summaryPrefix : currentItem.sourceDetail
                    )
                }
            }

            if railItems.count > 1 {
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(video.railTitle)
                            .font(.custom("Avenir Next Demi Bold", size: 16))
                            .foregroundStyle(Palette.ink)

                        if !video.railSubtitle.isEmpty {
                            Text(video.railSubtitle)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(Palette.muted)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(railItems) { item in
                                    Button {
                                        activateRailItem(withID: item.id)
                                    } label: {
                                        MacVideoRailCard(
                                            item: item,
                                            isFocused: currentItem.id == item.id
                                        )
                                        .frame(width: 252)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
#else
    private var iosVideoBody: some View {
        GeometryReader { proxy in
            let horizontalPadding = horizontalSizeClass == .regular ? 26.0 : 18.0
            let topInset = horizontalSizeClass == .regular ? 10.0 : 4.0
            let bottomInset = max(proxy.safeAreaInsets.bottom, 18)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.08, blue: 0.13),
                        Color(red: 0.10, green: 0.18, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Palette.accent.opacity(0.18))
                    .frame(width: 360, height: 360)
                    .blur(radius: 48)
                    .offset(x: -160, y: -280)
                    .ignoresSafeArea()

                Circle()
                    .fill(Palette.highlight.opacity(0.14))
                    .frame(width: 320, height: 320)
                    .blur(radius: 56)
                    .offset(x: 140, y: 320)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    iosTopBar
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, topInset)
                        .padding(.bottom, 10)

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 18) {
                            iosTitleBlock
                            iosVideoSurface
                            iosMetadataPanel
                            if railItems.count > 1 {
                                iosRelatedVideosRail
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, bottomInset + 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var iosTopBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Label(backLabel, systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            downloadActionButton
        }
    }

    private var iosTitleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLAYING NOW")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Palette.highlight)

            Text(currentItem.title)
                .font(.system(size: horizontalSizeClass == .regular ? 18 : 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var iosVideoSurface: some View {
        ZStack {
            IOSInlineVideoPlayerContainer(player: player)
                .frame(maxWidth: .infinity)
                .frame(height: horizontalSizeClass == .regular ? 460 : 248)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 30 : 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 30 : 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 28, y: 16)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.04),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 30 : 26, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var iosMetadataPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Video details")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)

            VideoMetaCard(
                systemImage: currentItem.sourceKind.systemImage,
                title: currentItem.sourceKind.cardTitle,
                detail: currentItem.sourceName,
                caption: currentItem.sourceDetail.isEmpty ? currentItem.sourceKind.summaryPrefix : currentItem.sourceDetail
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var iosRelatedVideosRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.railTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                if !video.railSubtitle.isEmpty {
                    Text(video.railSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                let cardWidth = min(horizontalSizeClass == .regular ? 264 : 208, proxy.size.width * 0.72)
                let horizontalInset = max((proxy.size.width - cardWidth) / 2, 0)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(railItems) { item in
                            Button {
                                withAnimation(.snappy(duration: 0.28)) {
                                    focusedRailItemID = item.id
                                }
                            } label: {
                                IOSVideoRailCard(
                                    item: item,
                                    isFocused: focusedRailItemID == item.id
                                )
                                .frame(width: cardWidth)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, horizontalInset)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedRailItemID, anchor: .center)
                .onChange(of: focusedRailItemID) { _, newValue in
                    scheduleSettledVideoSwitch(for: newValue)
                }
            }
            .frame(height: horizontalSizeClass == .regular ? 236 : 212)
        }
    }
#endif

    private var currentDownloadState: VideoDownloadState {
        videoDownloadManager.downloadState(for: currentItem)
    }

    @ViewBuilder
    private var downloadActionButton: some View {
        Button(action: performDownloadAction) {
            Label(downloadButtonTitle, systemImage: downloadButtonSymbol)
#if os(iOS)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(downloadButtonForegroundStyle)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(downloadButtonBackgroundColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(downloadButtonBorderColor, lineWidth: 1)
                )
#else
                .font(.custom("Avenir Next Demi Bold", size: 12))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(downloadButtonMacBackgroundColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(downloadButtonMacBorderColor, lineWidth: 1)
                )
#endif
        }
        .buttonStyle(.plain)
        .disabled(isDownloadActionDisabled)
    }

    private var railItems: [VideoRailItem] {
        video.railItems.isEmpty ? [video.currentItem] : video.railItems
    }

    private func scheduleSettledVideoSwitch(for itemID: String?) {
#if os(iOS)
        selectionCommitTask?.cancel()
        guard let itemID, itemID != currentItem.id else { return }

        selectionCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            activateRailItem(withID: itemID)
        }
#endif
    }

    private func activateRailItem(withID itemID: String) {
        guard let selectedItem = railItems.first(where: { $0.id == itemID }) else { return }
        guard selectedItem.id != currentItem.id else { return }

        persistCurrentPlaybackProgress()
        currentItem = selectedItem
        preparePlayback(for: selectedItem, replaceCurrentItem: true)
    }

    private func seek(by delta: Double) {
        let currentSeconds = max(player.currentTime().seconds, 0)
        guard currentSeconds.isFinite else { return }

        let durationSeconds = player.currentItem?.duration.seconds ?? .infinity
        let targetSeconds = currentSeconds + delta
        let boundedSeconds: Double

        if durationSeconds.isFinite && durationSeconds > 0 {
            boundedSeconds = min(max(targetSeconds, 0), durationSeconds)
        } else {
            boundedSeconds = max(targetSeconds, 0)
        }

        let targetTime = CMTime(seconds: boundedSeconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private var videoTitleSize: CGFloat {
#if os(iOS)
        return horizontalSizeClass == .regular ? 22 : 24
#else
        return 20
#endif
    }

    private var downloadButtonTitle: String {
        switch currentDownloadState {
        case .notDownloaded:
            return "Download"
        case .queued(let status):
            if let fraction = status?.fractionCompleted {
                return "Pause \(Int((fraction * 100).rounded()))%"
            }
            return "Pause"
        case .downloading(let status):
            if let fraction = status.fractionCompleted {
                return "Pause \(Int((fraction * 100).rounded()))%"
            }
            return "Pause"
        case .paused(_):
            return "Resume"
        case .downloaded(_):
            return "Offline"
        case .failed(_):
            return "Retry"
        }
    }

    private var downloadButtonSymbol: String {
        switch currentDownloadState {
        case .downloaded(_):
            return "checkmark.circle.fill"
        case .paused(_):
            return "play.circle"
        case .queued(_), .downloading(_):
            return "pause.circle"
        case .failed(_):
            return "arrow.clockwise.circle"
        case .notDownloaded:
            return "arrow.down.circle"
        }
    }

    private var isDownloadActionDisabled: Bool {
        switch currentDownloadState {
        case .downloaded(_):
            return true
        case .notDownloaded, .queued(_), .downloading(_), .paused(_), .failed(_):
            return false
        }
    }

#if os(iOS)
    private var downloadButtonBackgroundColor: Color {
        switch currentDownloadState {
        case .downloaded(_):
            return Palette.accent.opacity(0.24)
        case .paused(_):
            return Palette.gold.opacity(0.20)
        case .queued(_), .downloading(_):
            return Color.white.opacity(0.08)
        case .failed(_):
            return Palette.danger.opacity(0.22)
        case .notDownloaded:
            return Color.white.opacity(0.10)
        }
    }

    private var downloadButtonBorderColor: Color {
        switch currentDownloadState {
        case .downloaded(_):
            return Palette.accent.opacity(0.36)
        case .paused(_):
            return Palette.gold.opacity(0.34)
        case .queued(_), .downloading(_):
            return Color.white.opacity(0.12)
        case .failed(_):
            return Palette.danger.opacity(0.34)
        case .notDownloaded:
            return Color.white.opacity(0.12)
        }
    }

    private var downloadButtonForegroundStyle: Color {
        switch currentDownloadState {
        case .failed(_):
            return Palette.danger
        case .paused(_):
            return Palette.gold
        default:
            return Color.white
        }
    }
#else
    private var downloadButtonMacBackgroundColor: Color {
        switch currentDownloadState {
        case .downloaded(_):
            return Palette.accent.opacity(0.16)
        case .paused(_):
            return Palette.gold.opacity(0.16)
        case .queued(_), .downloading(_):
            return Palette.highlight.opacity(0.12)
        case .failed(_):
            return Palette.danger.opacity(0.16)
        case .notDownloaded:
            return Color.white.opacity(0.78)
        }
    }

    private var downloadButtonMacBorderColor: Color {
        switch currentDownloadState {
        case .downloaded(_):
            return Palette.accent.opacity(0.34)
        case .paused(_):
            return Palette.gold.opacity(0.34)
        case .queued(_), .downloading(_):
            return Palette.highlight.opacity(0.28)
        case .failed(_):
            return Palette.danger.opacity(0.34)
        case .notDownloaded:
            return Color.black.opacity(0.08)
        }
    }
#endif

    private func preparePlayback(for item: VideoRailItem, replaceCurrentItem: Bool) {
        if replaceCurrentItem {
            player.replaceCurrentItem(with: AVPlayerItem(url: item.url))
        }

        installPlaybackEndObserver()

        if let resumeSecond = videoPlaybackStore.resumeTime(forRemoteURL: item.remoteURL) {
            lastTrackedPlaybackSecond = resumeSecond
            let resumeTime = CMTime(seconds: resumeSecond, preferredTimescale: 600)
            player.seek(to: resumeTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                lastTrackedPlaybackSecond = resumeSecond
                player.play()
            }
        } else {
            let currentSeconds = max(player.currentTime().seconds, 0)
            lastTrackedPlaybackSecond = currentSeconds.isFinite ? currentSeconds : 0
            player.play()
        }
    }

    private func installPeriodicProgressObserverIfNeeded() {
        guard timeObserverToken == nil else { return }

        let interval = CMTime(seconds: 5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            recordProgress(at: time.seconds)
        }
    }

    private func installPlaybackEndObserver() {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }

        guard let currentPlayerItem = player.currentItem else { return }
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: currentPlayerItem,
            queue: .main
        ) { _ in
            persistCurrentPlaybackProgress()
            let durationSeconds = currentDurationSeconds
            Task { @MainActor in
                videoPlaybackStore.markCompleted(for: currentItem, durationSeconds: durationSeconds)
            }
            lastTrackedPlaybackSecond = nil
        }
    }

    private func removePlayerObservers() {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }

        lastTrackedPlaybackSecond = nil
    }

    private func recordProgress(at seconds: Double) {
        let boundedSeconds = max(seconds, 0)
        guard boundedSeconds.isFinite else { return }

        let watchedIncrement: Double
        if let lastTrackedPlaybackSecond,
           boundedSeconds + 0.25 >= lastTrackedPlaybackSecond {
            watchedIncrement = min(max(boundedSeconds - lastTrackedPlaybackSecond, 0), 6)
        } else {
            watchedIncrement = 0
        }

        lastTrackedPlaybackSecond = boundedSeconds
        videoPlaybackStore.saveProgress(
            for: currentItem,
            positionSeconds: boundedSeconds,
            durationSeconds: currentDurationSeconds,
            watchedIncrement: watchedIncrement
        )
    }

    private func persistCurrentPlaybackProgress() {
        let currentSeconds = max(player.currentTime().seconds, 0)
        guard currentSeconds.isFinite else { return }

        let watchedIncrement: Double
        if let lastTrackedPlaybackSecond,
           currentSeconds + 0.25 >= lastTrackedPlaybackSecond {
            watchedIncrement = min(max(currentSeconds - lastTrackedPlaybackSecond, 0), 6)
        } else {
            watchedIncrement = 0
        }

        videoPlaybackStore.saveProgress(
            for: currentItem,
            positionSeconds: currentSeconds,
            durationSeconds: currentDurationSeconds,
            watchedIncrement: watchedIncrement
        )
        lastTrackedPlaybackSecond = currentSeconds
    }

    private var currentDurationSeconds: Double? {
        let seconds = player.currentItem?.duration.seconds ?? .infinity
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    private func performDownloadAction() {
        guard !isDownloadActionDisabled else { return }
        switch currentDownloadState {
        case .queued(_), .downloading(_):
            videoDownloadManager.pauseDownload(forRemoteURL: currentItem.remoteURL)
        case .paused(_):
            videoDownloadManager.resumeDownload(forRemoteURL: currentItem.remoteURL)
        case .notDownloaded, .failed(_):
            videoDownloadManager.startDownload(for: currentItem)
        case .downloaded(_):
            break
        }
    }
}

#if os(iOS)
private struct VideoMetaCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let caption: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.highlight)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct IOSVideoRailCard: View {
    let item: VideoRailItem
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtworkView(
                urls: item.artworkURLs,
                aspectRatio: 1.28,
                cornerRadius: 20,
                imageAlignment: .center,
                imageContentMode: .fill
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail.isEmpty ? item.subtitle : item.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isFocused ? Palette.highlight.opacity(0.8) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1 : 0.94)
        .shadow(color: .black.opacity(isFocused ? 0.24 : 0.10), radius: isFocused ? 18 : 10, y: isFocused ? 10 : 6)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isFocused)
    }
}
#endif

#if os(macOS)
private struct MacVideoMetaCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let caption: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.highlight)
                .frame(width: 38, height: 38)
                .background(Palette.highlight.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)

                Text(detail)
                    .font(.custom("Avenir Next Demi Bold", size: 15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !caption.isEmpty {
                    Text(caption)
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct MacVideoRailCard: View {
    let item: VideoRailItem
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtworkView(
                urls: item.artworkURLs,
                aspectRatio: 1.22,
                cornerRadius: 18,
                imageAlignment: .center,
                imageContentMode: .fill
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.detail.isEmpty ? item.subtitle : item.detail)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isFocused ? Palette.accentSoft.opacity(0.92) : Color.white.opacity(0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isFocused ? Palette.accent.opacity(0.72) : Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isFocused ? 0.10 : 0.05), radius: isFocused ? 16 : 10, y: isFocused ? 8 : 4)
        .scaleEffect(isFocused ? 1 : 0.98)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: isFocused)
    }
}
#endif

struct PlayerSkipButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#if os(macOS)
struct MacVideoPlayerContainer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
#else
struct IOSInlineVideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.showsPlaybackControls = true
    }
}
#endif

#if os(macOS)
struct PDFContainerView: NSViewRepresentable {
    let url: URL
    var navigator: PDFReaderNavigator? = nil

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .white
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if context.coordinator.loadedURL != url || nsView.document == nil {
            nsView.document = PDFDocument(url: url)
            context.coordinator.loadedURL = url
        }
        navigator?.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
#else
struct PDFContainerView: UIViewRepresentable {
    let url: URL
    var navigator: PDFReaderNavigator? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(navigator: navigator)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .white
        view.displaysPageBreaks = true
        context.coordinator.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.loadDocumentIfNeeded(from: url, into: uiView)
        context.coordinator.bind(to: uiView)
        Task { @MainActor in
            navigator?.refresh()
        }
    }

    @MainActor
    final class Coordinator {
        private weak var observedView: PDFView?
        private let navigator: PDFReaderNavigator?
        private var observers: [NSObjectProtocol] = []
        private var loadedURL: URL?

        init(navigator: PDFReaderNavigator?) {
            self.navigator = navigator
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        func bind(to view: PDFView) {
            guard observedView !== view else {
                navigator?.attach(to: view)
                return
            }

            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedView = view
            navigator?.attach(to: view)

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: Notification.Name.PDFViewPageChanged,
                    object: view,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.navigator?.refresh()
                    }
                }
            )

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: Notification.Name.PDFViewDocumentChanged,
                    object: view,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.navigator?.refresh()
                    }
                }
            )
        }

        func loadDocumentIfNeeded(from url: URL, into view: PDFView) {
            guard loadedURL != url || view.document == nil else { return }
            view.document = PDFDocument(url: url)
            loadedURL = url
        }
    }
}
#endif
