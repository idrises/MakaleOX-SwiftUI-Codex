import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MainShellView: View {
    @EnvironmentObject private var appState: AppState
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    #endif

    var body: some View {
        #if os(iOS)
        if isCompactPhoneLayout {
            IPhoneRootShellView()
        } else {
            splitShellView
        }
        #else
        splitShellView
        #endif
    }

    private var splitShellView: some View {
        NavigationSplitView(columnVisibility: splitViewVisibilityBinding) {
            AppCanvas {
                VStack(alignment: .leading, spacing: 16) {
                    if let session = appState.session {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(AppBranding.title)
                                    .font(.custom("Avenir Next Demi Bold", size: 15))
                                    .foregroundStyle(Palette.highlight)
                                Text(session.displayName)
                                    .font(.custom("Avenir Next Demi Bold", size: 20))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                StatusPill(
                                    text: session.isExpired ? "Expired" : "Active until \(session.expireDate)",
                                    tint: session.isExpired ? Palette.danger : Palette.accent
                                )
                            }
                        }
                    }

                    sidebarList
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(.clear)

                    Spacer()
                }
                .padding(sidebarPadding)
                .frame(
                    minWidth: sidebarMinWidth,
                    idealWidth: sidebarIdealWidth,
                    maxWidth: sidebarMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            .navigationSplitViewColumnWidth(min: sidebarMinWidth, ideal: sidebarIdealWidth, max: sidebarMaxWidth)
        } detail: {
            AppCanvas {
                contentView
                    .padding(.horizontal, detailPadding)
                    .padding(.bottom, detailPadding)
                    .padding(.top, detailTopPadding)
            }
        }
        .toolbar {
            #if os(iOS)
            if shouldShowSplitHeaderMenuButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        splitViewVisibility = .all
                    } label: {
                        Label("Menu", systemImage: "sidebar.leading")
                    }
                }
            }
            #endif
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await appState.refreshCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .task(id: appState.selectedSection) {
            await appState.loadCurrentSectionIfNeeded()
        }
        .onChange(of: appState.selectedSection) { _ in
            #if os(iOS)
            appState.dismissActiveContent()
            #endif
        }
#if os(iOS)
        .sheet(item: modalDocumentBinding) { document in
            DocumentViewerScreen(
                document: document,
                backLabel: "Close",
                showsMetadataHeader: false,
                onClose: { appState.activeDocument = nil }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: modalVideoBinding) { video in
            VideoPlayerScreen(
                video: video,
                backLabel: "Close",
                onClose: { appState.activeVideo = nil }
            )
            .presentationBackground(.clear)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
#endif
#if os(macOS)
        .onChange(of: appState.activeDocument?.id) { _ in
            if appState.activeDocument != nil {
                openWindow(id: "document-viewer")
            } else {
                closeAuxiliaryWindow(named: "Reader")
            }
        }
        .onChange(of: appState.activeVideo?.id) { _ in
            if appState.activeVideo != nil {
                openWindow(id: "video-viewer")
            } else {
                closeAuxiliaryWindow(named: "Video")
            }
        }
#endif
    }

#if os(iOS)
    private var iPhoneShellView: some View {
        NavigationStack {
            AppCanvas {
                contentView
                    .padding(.horizontal, detailPadding)
                    .padding(.bottom, 8)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom) {
                iPhoneSectionBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let session = appState.session {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.displayName)
                            .font(.custom("Avenir Next Demi Bold", size: 14))
                            .lineLimit(1)
                        Text(session.isExpired ? "Expired" : "Active")
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(session.isExpired ? Palette.danger : Palette.accent)
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await appState.refreshCurrentSection() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Menu {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task(id: appState.selectedSection) {
            await appState.loadCurrentSectionIfNeeded()
        }
        .onChange(of: appState.selectedSection) { _ in
            appState.dismissActiveContent()
        }
    }

    private var iPhoneSectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        appState.selectedSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                            Text(section.title)
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                                .lineLimit(1)
                        }
                        .foregroundStyle(appState.selectedSection == section ? Color.white : Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(appState.selectedSection == section ? Palette.accent : Color.white.opacity(0.74))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
#endif

    @ViewBuilder
    private var sidebarList: some View {
#if os(macOS)
        List(AppSection.allCases, selection: $appState.selectedSection) { section in
            sidebarRow(for: section)
                .tag(section)
        }
#else
        List {
            ForEach(AppSection.allCases) { section in
                Button {
                    appState.selectedSection = section
                } label: {
                    sidebarRow(for: section)
                        .foregroundStyle(appState.selectedSection == section ? Color.white : Palette.ink)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(appState.selectedSection == section ? Palette.accent : Color.clear)
                        .padding(.vertical, 2)
                )
            }
        }
#endif
    }

    private func sidebarRow(for section: AppSection) -> some View {
        Label(section.title, systemImage: section.symbolName)
            .font(.custom("Avenir Next Demi Bold", size: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var contentView: some View {
#if os(macOS)
        switch appState.selectedSection {
        case .dashboard:
            DashboardScreen()
        case .journals:
            JournalsScreen()
        case .books:
            BooksScreen()
        case .videos:
            VideosScreen()
        case .videoSets:
            VideoSetsScreen()
        case .search:
            SearchScreen()
        case .history:
            HistoryScreen()
        case .profile:
            ProfileScreen()
        }
#else
        if let document = appState.activeDocument, !showsModalDocumentViewer {
            DocumentViewerScreen(
                document: document,
                backLabel: "Back To \(appState.selectedSection.title)",
                onClose: { appState.dismissActiveContent() }
            )
        } else if let video = appState.activeVideo, !showsModalVideoPlayer {
            VideoPlayerScreen(
                video: video,
                backLabel: "Back To \(appState.selectedSection.title)",
                onClose: { appState.dismissActiveContent() }
            )
        } else {
            switch appState.selectedSection {
            case .dashboard:
                DashboardScreen()
            case .journals:
                JournalsScreen()
            case .books:
                BooksScreen()
            case .videos:
                VideosScreen()
            case .videoSets:
                VideoSetsScreen()
            case .search:
                SearchScreen()
            case .history:
                HistoryScreen()
            case .profile:
                ProfileScreen()
            }
        }
#endif
    }

    private var sidebarPadding: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 12 : 12
#else
        return 18
#endif
    }

    private var detailPadding: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 16 : 14
#else
        return 24
#endif
    }

#if os(macOS)
    private func closeAuxiliaryWindow(named title: String) {
        for window in NSApplication.shared.windows where window.title == title {
            window.close()
        }
    }
#endif

    private var detailTopPadding: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 8 : 10
#else
        return 10
#endif
    }

    private var sidebarMinWidth: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 214 : 198
#else
        return 238
#endif
    }

    private var sidebarIdealWidth: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 228 : 208
#else
        return 252
#endif
    }

    private var sidebarMaxWidth: CGFloat {
#if os(iOS)
        return isRegularIPadLayout ? 244 : 220
#else
        return 266
#endif
    }

#if os(iOS)
    private var splitViewVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { splitViewVisibility },
            set: { splitViewVisibility = $0 }
        )
    }

    private var isRegularIPadLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var shouldShowSplitHeaderMenuButton: Bool {
        isRegularIPadLayout && splitViewVisibility == .detailOnly
    }

    private var isCompactPhoneLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var showsModalVideoPlayer: Bool {
        isRegularIPadLayout
    }

    private var showsModalDocumentViewer: Bool {
        isRegularIPadLayout
    }

    private var modalDocumentBinding: Binding<DocumentPresentation?> {
        Binding(
            get: { showsModalDocumentViewer ? appState.activeDocument : nil },
            set: { appState.activeDocument = $0 }
        )
    }

    private var modalVideoBinding: Binding<VideoPresentation?> {
        Binding(
            get: { showsModalVideoPlayer ? appState.activeVideo : nil },
            set: { appState.activeVideo = $0 }
        )
    }
#else
    private var splitViewVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        .constant(.all)
    }
#endif
}
