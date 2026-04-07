import SwiftUI

private enum JournalsLayoutMode: String {
    case list
    case gallery
}

struct JournalsScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("journals.layout.mode") private var layoutModeRawValue = JournalsLayoutMode.list.rawValue
    @State private var searchText = ""
    @State private var activeJournal: Journal?
    @State private var activeIssue: JournalIssue?

    var body: some View {
        journalPane
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                consumePendingNavigation()
            }
            .onChange(of: appState.pendingJournalIssueNavigationID) { _ in
                consumePendingNavigation()
            }
    }

    private var journalPane: some View {
        SectionCard {
            if let activeJournal {
                if let activeIssue {
                    JournalArticlesPage(
                        journal: activeJournal,
                        issue: activeIssue,
                        backTitle: appState.journalReturnSection == .dashboard ? "Back To Dashboard" : "Back To Volumes",
                        onBack: {
                            if appState.journalReturnSection == .dashboard {
                                self.activeIssue = nil
                                self.activeJournal = nil
                                appState.journalReturnSection = nil
                                appState.pendingJournalIssueNavigationID = nil
                                appState.selectedSection = .dashboard
                            } else {
                                self.activeIssue = nil
                            }
                        }
                    )
                    .environmentObject(appState)
                } else {
                    JournalVolumesPage(
                        journal: activeJournal,
                        backTitle: appState.journalReturnSection == .dashboard ? "Back To Dashboard" : "Back To Journals",
                        onBack: {
                            if appState.journalReturnSection == .dashboard {
                                self.activeIssue = nil
                                self.activeJournal = nil
                                appState.journalReturnSection = nil
                                appState.pendingJournalIssueNavigationID = nil
                                appState.selectedSection = .dashboard
                            } else {
                                self.activeIssue = nil
                                self.activeJournal = nil
                            }
                        },
                        onSelectIssue: { issue in
                            self.activeIssue = issue
                        }
                    )
                    .environmentObject(appState)
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        ScreenHeader(
                            eyebrow: "Journals",
                            title: "Browse titles",
                            subtitle: "A clean journal shelf focused on titles, quick filtering, favorites, and volume browsing."
                        )

                        Spacer(minLength: 12)

                        Picker("Layout", selection: $layoutModeRawValue) {
                            Text("List").tag(JournalsLayoutMode.list.rawValue)
                            Text("Gallery").tag(JournalsLayoutMode.gallery.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .controlSize(.small)
                    }

                    HStack(spacing: 10) {
                        TextField("Filter title, ISSN, subject…", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Button("Refresh Search") {
                            Task { await appState.loadJournals(search: searchText) }
                        }
                        .buttonStyle(.bordered)
                    }

                    if filteredJournals.isEmpty {
                        EmptyStateView(
                            title: appState.journals.isEmpty ? "No journals loaded" : "No journals matched",
                            message: appState.journals.isEmpty
                                ? "Refresh the library to pull journal titles from the legacy server."
                                : "Try a different title, ISSN, or subject filter.",
                            symbolName: "newspaper"
                        )
                    } else {
                        ScrollView {
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
    }

    private var layoutMode: JournalsLayoutMode {
        JournalsLayoutMode(rawValue: layoutModeRawValue) ?? .list
    }

    private var filteredJournals: [Journal] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.journals }
        return appState.journals.filter {
            [$0.name, $0.issn, $0.subject]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }

    private var listContent: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredJournals, id: \.id) { journal in
                journalCard(journal)
            }
        }
    }

    private var galleryContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 304, maximum: 354), spacing: 10, alignment: .top)],
            spacing: 10
        ) {
            ForEach(filteredJournals, id: \.id) { journal in
                journalCard(journal)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func journalCard(_ journal: Journal) -> some View {
        let isSelected = journal.id == appState.selectedJournal?.id

        Button {
            appState.journalReturnSection = nil
            activeIssue = nil
            activeJournal = journal
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.coverCandidates(for: journal.name),
                title: journal.name,
                favoriteSelected: appState.favoritesStore.isFavorite(journal: journal),
                favoriteAction: { appState.favoritesStore.toggleJournal(journal) }
            ) {
                Text(journal.issn.isEmpty ? "ISSN unavailable" : journal.issn)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)

                if !journal.subject.isEmpty {
                    Text(journal.subject)
                        .font(.custom("Avenir Next Medium", size: 8))
                        .foregroundStyle(Palette.highlight)
                        .lineLimit(1)
                }
            } footer: {
                HStack(alignment: .center, spacing: 6) {
                    Spacer(minLength: 0)
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
        .buttonStyle(.plain)
    }

    private func consumePendingNavigation() {
        guard let pendingID = appState.pendingJournalIssueNavigationID else { return }
        guard let selectedJournal = appState.selectedJournal else { return }
        guard let selectedIssue = appState.selectedIssue, selectedIssue.id == pendingID else { return }

        activeJournal = selectedJournal
        activeIssue = selectedIssue
        appState.pendingJournalIssueNavigationID = nil
    }
}

private struct JournalVolumesPage: View {
    @EnvironmentObject private var appState: AppState

    let journal: Journal
    let backTitle: String
    let onBack: () -> Void
    let onSelectIssue: (JournalIssue) -> Void

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
                        eyebrow: "Volumes",
                        title: journal.name,
                        subtitle: "Recent and archived issues for the selected journal are collected on this separate page."
                    )
                }

                Spacer(minLength: 12)

                if appState.isLoadingJournalIssues, appState.selectedJournal?.id == journal.id {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                } else {
                    StatusPill(text: "\(visibleIssues.count) items", tint: Palette.accent)
                        .padding(.top, 4)
                }

                Button("Refresh") {
                    Task { await appState.selectJournal(journal) }
                }
                .buttonStyle(.bordered)
            }

            if appState.isLoadingJournalIssues, appState.selectedJournal?.id == journal.id {
                EmptyStateView(
                    title: "Loading volumes",
                    message: "The selected journal's issues are being prepared.",
                    symbolName: "clock.arrow.circlepath"
                )
            } else if visibleIssues.isEmpty {
                EmptyStateView(
                    title: "No volumes found",
                    message: "This journal does not currently expose issue records in the legacy database.",
                    symbolName: "square.stack.3d.down.right"
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 304, maximum: 354), spacing: 10, alignment: .top)],
                        spacing: 10
                    ) {
                        ForEach(visibleIssues, id: \.id) { issue in
                            volumeCard(issue)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .task(id: journal.id) {
            if appState.selectedJournal?.id != journal.id || appState.journalIssues.isEmpty {
                await appState.selectJournal(journal)
            }
        }
    }

    private var visibleIssues: [JournalIssue] {
        guard appState.selectedJournal?.id == journal.id else { return [] }
        return appState.journalIssues
    }

    @ViewBuilder
    private func volumeCard(_ issue: JournalIssue) -> some View {
        Button {
            onSelectIssue(issue)
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
}

private struct JournalArticlesPage: View {
    @EnvironmentObject private var appState: AppState

    let journal: Journal
    let issue: JournalIssue
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
                        eyebrow: "Articles",
                        title: issue.title,
                        subtitle: "Articles for \(journal.name) are grouped here so you can open the PDF list directly from the selected issue."
                    )
                }

                Spacer(minLength: 12)

                if appState.isLoadingArticles, appState.selectedIssue?.id == issue.id {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                } else {
                    StatusPill(text: "\(visibleArticles.count) items", tint: Palette.accent)
                        .padding(.top, 4)
                }

                Button("Refresh") {
                    Task { await appState.selectIssue(issue, forceReload: true) }
                }
                .buttonStyle(.bordered)
            }

            if appState.isLoadingArticles, appState.selectedIssue?.id == issue.id {
                EmptyStateView(
                    title: "Loading articles",
                    message: "The selected issue is being prepared.",
                    symbolName: "doc.text.magnifyingglass"
                )
            } else if visibleArticles.isEmpty {
                EmptyStateView(
                    title: "No articles found",
                    message: "This issue did not return article rows from the legacy database.",
                    symbolName: "doc.text"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(visibleArticles, id: \.id) { article in
                            articleCard(article)
                        }
                    }
                }
            }
        }
        .task(id: issue.id) {
            if appState.selectedIssue?.id != issue.id || appState.articles.isEmpty {
                await appState.selectIssue(issue)
            }
        }
    }

    private var visibleArticles: [Article] {
        guard appState.selectedIssue?.id == issue.id else { return [] }
        return appState.articles
    }

    private func articleCard(_ article: Article) -> some View {
        Button {
            Task { await appState.openArticle(article) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: LegacyConfig.issueCoverCandidates(
                    journal: article.journalName,
                    issue: article.issueTitle
                ),
                title: article.title,
                artworkAspectRatio: 0.78,
                artworkWidth: 72,
                artworkHeight: 96,
                titleSize: 14,
                titleLineLimit: 2
            ) {
                Text(article.author.isEmpty ? "Author unavailable" : article.author)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                Text([article.journalName, article.issueTitle].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(2)
            } footer: {
                HStack(alignment: .center, spacing: 8) {
                    Text(
                        ["Article", article.year, article.volume]
                            .filter { !$0.isEmpty }
                            .joined(separator: " • ")
                    )
                    .font(.custom("Avenir Next Medium", size: 10))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("Open Article")
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
