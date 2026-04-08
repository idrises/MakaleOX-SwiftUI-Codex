import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct MainShellView: View {
    @EnvironmentObject private var appState: AppState
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    @EnvironmentObject private var profileAvatarStore: ProfileAvatarStore
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
                            sidebarSessionCard(session)
                        }
                    }

                    sidebarList
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(.clear)

                    Spacer()

                    #if os(iOS)
                    if let session = appState.session, isRegularIPadLayout {
                        SectionCard {
                            sidebarFooterCard(session)
                        }
                    }
                    #endif
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
            #if os(iOS)
            .toolbar(removing: .sidebarToggle)
            #endif
            .navigationSplitViewColumnWidth(min: sidebarMinWidth, ideal: sidebarIdealWidth, max: sidebarMaxWidth)
        } detail: {
            AppCanvas {
                contentView
                    .padding(.horizontal, detailPadding)
                    .padding(.bottom, detailPadding)
                    .padding(.top, detailTopPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            #if os(iOS)
            .toolbar(usesVisibleIPadToolbar ? .visible : .hidden, for: .navigationBar)
            #endif
        }
        .toolbar {
            #if os(iOS)
            if usesVisibleIPadToolbar {
                if shouldShowSplitHeaderMenu {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button {
                                splitViewVisibility = .all
                            } label: {
                                Label("Show Sidebar", systemImage: "sidebar.leading")
                            }

                            Divider()

                            ForEach(AppSection.allCases) { section in
                                Button {
                                    appState.selectedSection = section
                                } label: {
                                    Label(section.title, systemImage: appState.selectedSection == section ? "checkmark.circle.fill" : section.symbolName)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: appState.selectedSection.symbolName)
                                Text(appState.selectedSection.title)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
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
            #else
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
            #endif
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
        .fullScreenCover(item: modalDocumentBinding) { document in
            DocumentViewerScreen(
                document: document,
                backLabel: "Close",
                showsMetadataHeader: false,
                onClose: { appState.activeDocument = nil }
            )
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
        return isRegularIPadLayout ? 2 : 10
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

    private var shouldShowSplitHeaderMenu: Bool {
        isRegularIPadLayout && splitViewVisibility == .detailOnly
    }

    private var usesVisibleIPadToolbar: Bool {
        !isRegularIPadLayout || shouldShowSplitHeaderMenu
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

#if os(iOS)
extension MainShellView {
    @ViewBuilder
    private func sidebarSessionCard(_ session: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppBranding.title)
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(Palette.highlight)

            Text(session.displayName)
                .font(.custom("Avenir Next Demi Bold", size: 15))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.expireDate.isEmpty ? "Renew date -" : "Renew date \(session.expireDate)")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

            Text(session.isExpired ? "Expired" : "Active")
                .font(.custom("Avenir Next Demi Bold", size: 10))
                .foregroundStyle(session.isExpired ? Palette.danger : Palette.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    (session.isExpired ? Palette.danger : Palette.accent).opacity(0.10),
                    in: Capsule()
                )
        }
    }

    @ViewBuilder
    private func sidebarFooterCard(_ session: SessionInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SidebarAvatarPicker(session: session)
                .environmentObject(profileAvatarStore)

            VStack(alignment: .leading, spacing: 3) {
                Text("Profile photo")
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .foregroundStyle(Palette.ink)

                Text("Tap to change")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 0)

            Button {
                toggleSidebarVisibility()
            } label: {
                Image(systemName: splitViewVisibility == .detailOnly ? "sidebar.leading" : "sidebar.trailing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.accent.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleSidebarVisibility() {
        splitViewVisibility = splitViewVisibility == .detailOnly ? .all : .detailOnly
    }
}

private struct SidebarAvatarPicker: View {
    @EnvironmentObject private var profileAvatarStore: ProfileAvatarStore
    @State private var isShowingOptions = false
    @State private var activeImageSource: SidebarAvatarImageSource?

    let session: SessionInfo

    var body: some View {
        Button {
            isShowingOptions = true
        } label: {
            avatarImage
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
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
            SidebarAvatarImagePicker(sourceType: source.sourceType) { data in
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
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

private enum SidebarAvatarImageSource: String, Identifiable {
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

private struct SidebarAvatarImagePicker: UIViewControllerRepresentable {
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
        let onSelection: (Data?) -> Void

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
            let data = image?.jpegData(compressionQuality: 0.88) ?? image?.pngData()
            picker.dismiss(animated: true)
            onSelection(data)
        }
    }
}
#endif
