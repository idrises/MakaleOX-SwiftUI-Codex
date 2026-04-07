import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var appState: AppState
    private let sidebarMinWidth: CGFloat = 238
    private let sidebarIdealWidth: CGFloat = 252
    private let sidebarMaxWidth: CGFloat = 266

    var body: some View {
        NavigationSplitView {
            AppCanvas {
                VStack(alignment: .leading, spacing: 16) {
                    if let session = appState.session {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Welcome back")
                                    .font(.custom("Avenir Next Medium", size: 13))
                                    .foregroundStyle(Palette.highlight)
                                Text(session.displayName)
                                    .font(.custom("Avenir Next Bold", size: 24))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(session.email)
                                    .font(.custom("Avenir Next Regular", size: 13))
                                    .foregroundStyle(Palette.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                StatusPill(
                                    text: session.isExpired ? "Expired" : "Active until \(session.expireDate)",
                                    tint: session.isExpired ? Palette.danger : Palette.accent
                                )
                            }
                        }
                    }

                    List(AppSection.allCases, selection: $appState.selectedSection) { section in
                        Label(section.title, systemImage: section.symbolName)
                            .font(.custom("Avenir Next Demi Bold", size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tag(section)
                            .padding(.vertical, 4)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(.clear)

                    Spacer()
                }
                .padding(18)
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
                    .padding(24)
            }
        }
        .toolbar {
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
    }

    @ViewBuilder
    private var contentView: some View {
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
}
