import SwiftUI

private enum BooksLayoutMode: String {
    case list
    case gallery
}

struct BooksScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("books.layout.mode") private var layoutModeRawValue = BooksLayoutMode.list.rawValue
    @State private var searchText = ""
    @State private var activeBook: Book?

    var body: some View {
        bookPane
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                consumePendingNavigation()
            }
            .onChange(of: appState.pendingBookNavigationID) { _ in
                consumePendingNavigation()
            }
    }

    private var bookPane: some View {
        SectionCard {
            if let activeBook {
                BookChaptersPage(
                    book: activeBook,
                    backTitle: appState.bookReturnSection == .dashboard ? "Back To Dashboard" : "Back To Books",
                    onBack: {
                        if appState.bookReturnSection == .dashboard {
                            self.activeBook = nil
                            appState.bookReturnSection = nil
                            appState.pendingBookNavigationID = nil
                            appState.selectedSection = .dashboard
                        } else {
                            self.activeBook = nil
                        }
                    }
                )
                .environmentObject(appState)
            } else {
                browseContent
            }
        }
    }

    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ScreenHeader(
                    eyebrow: "Books",
                    title: "Browse titles",
                    subtitle: "A cleaner book shelf focused on covers, editors, quick filtering, and favorites."
                )

                Spacer(minLength: 12)

                Picker("Layout", selection: $layoutModeRawValue) {
                    Text("List").tag(BooksLayoutMode.list.rawValue)
                    Text("Gallery").tag(BooksLayoutMode.gallery.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                TextField("Filter title, editor, year…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button("Refresh Search") {
                    Task { await appState.loadBooks(search: searchText) }
                }
                .buttonStyle(.bordered)
            }

            if filteredBooks.isEmpty {
                EmptyStateView(
                    title: appState.books.isEmpty ? "No books loaded" : "No books matched",
                    message: appState.books.isEmpty
                        ? "Refresh the library to pull books from the legacy server."
                        : "Try a different title, editor, or year filter.",
                    symbolName: "books.vertical"
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

    private var layoutMode: BooksLayoutMode {
        BooksLayoutMode(rawValue: layoutModeRawValue) ?? .list
    }

    private var listContent: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredBooks, id: \.id) { book in
                bookCard(book)
            }
        }
    }

    private var galleryContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 304, maximum: 354), spacing: 10, alignment: .top)],
            spacing: 10
        ) {
            ForEach(filteredBooks, id: \.id) { book in
                bookCard(book)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func bookCard(_ book: Book) -> some View {
        let isSelected = book.id == appState.selectedBook?.id

        Button {
            appState.bookReturnSection = nil
            activeBook = book
        } label: {
            CompactMediaRowCard(
                artworkURLs: artworkURLs(for: book),
                title: book.title,
                favoriteSelected: appState.favoritesStore.isFavorite(book: book),
                favoriteAction: { appState.favoritesStore.toggleBook(book) }
            ) {
                Text(book.editors.isEmpty ? "Editor unavailable" : book.editors)
                    .font(.custom("Avenir Next Regular", size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                Text([book.year, book.company].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.custom("Avenir Next Medium", size: 8))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)
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
        guard let pendingID = appState.pendingBookNavigationID else { return }
        guard let selectedBook = appState.selectedBook, selectedBook.id == pendingID else { return }

        activeBook = selectedBook
        appState.pendingBookNavigationID = nil
    }

    private func artworkURLs(for book: Book) -> [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.books }
        return appState.books.filter {
            [$0.title, $0.editors, $0.year, $0.company, $0.isbnOnline]
                .joined(separator: " ")
                .matchesNormalizedSearch(query)
        }
    }
}

private struct BookChaptersPage: View {
    @EnvironmentObject private var appState: AppState

    let book: Book
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
                        eyebrow: "Book Detail",
                        title: book.title,
                        subtitle: "Book details and chapters are grouped here so you can open the PDF list directly from the selected title."
                    )
                }

                Spacer(minLength: 12)

                if appState.isLoadingChapters, appState.selectedBook?.id == book.id {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                } else {
                    StatusPill(text: "\(visibleChapters.count) items", tint: Palette.accent)
                        .padding(.top, 4)
                }

                Button("Refresh") {
                    Task { await appState.selectBook(book, forceReload: true) }
                }
                .buttonStyle(.bordered)
            }

            bookSummaryCard

            if appState.isLoadingChapters, appState.selectedBook?.id == book.id {
                EmptyStateView(
                    title: "Loading chapters",
                    message: "The selected book is being prepared.",
                    symbolName: "books.vertical.circle"
                )
            } else if visibleChapters.isEmpty {
                EmptyStateView(
                    title: "No chapters found",
                    message: "This book did not return chapter rows from the legacy database.",
                    symbolName: "doc.text"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(visibleChapters, id: \.id) { chapter in
                            chapterCard(chapter)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .task(id: book.id) {
            if appState.selectedBook?.id != book.id || appState.chapters.isEmpty {
                await appState.selectBook(book)
            }
        }
    }

    private var visibleChapters: [Chapter] {
        guard appState.selectedBook?.id == book.id else { return [] }
        return appState.chapters
    }

    private var bookSummaryCard: some View {
        HStack(alignment: .top, spacing: 18) {
            RemoteArtworkView(
                urls: artworkURLs(for: book),
                aspectRatio: 0.78,
                cornerRadius: 18
            )
            .frame(width: 108, height: 138)

            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 220), spacing: 18, alignment: .topLeading),
                        GridItem(.flexible(minimum: 220), spacing: 18, alignment: .topLeading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    DetailLine(label: "Editors", value: book.editors, fallback: "Editor unavailable")
                    DetailLine(label: "Publisher", value: book.company, fallback: "Publisher unavailable")
                    DetailLine(label: "Year", value: book.year, fallback: "Year unavailable")
                    DetailLine(label: "Subject", value: book.subject, fallback: "Subject unavailable")
                    DetailLine(label: "ISBN", value: primaryISBN, fallback: "ISBN unavailable")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }

    private func chapterCard(_ chapter: Chapter) -> some View {
        Button {
            Task { await appState.openChapter(chapter) }
        } label: {
            CompactMediaRowCard(
                artworkURLs: artworkURLs(for: book),
                title: chapter.title,
                artworkAspectRatio: 0.78,
                artworkWidth: 72,
                artworkHeight: 96,
                titleSize: 14,
                titleLineLimit: 2
            ) {
                Text(chapter.editors.isEmpty ? "Editor unavailable" : chapter.editors)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                Text([book.title, chapter.year].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(2)
            } footer: {
                HStack(alignment: .center, spacing: 8) {
                    Text(
                        ["Book", chapter.year, primaryISBN]
                            .filter { !$0.isEmpty }
                            .joined(separator: " • ")
                    )
                    .font(.custom("Avenir Next Medium", size: 10))
                    .foregroundStyle(Palette.highlight)
                    .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("Open Chapter")
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var primaryISBN: String {
        book.isbnOnline.isEmpty ? book.isbnPrint : book.isbnOnline
    }

    private func artworkURLs(for book: Book) -> [URL] {
        var urls = LegacyConfig.bookCoverCandidates(isbn: book.isbnOnline)
        if book.isbnPrint != book.isbnOnline {
            urls += LegacyConfig.bookCoverCandidates(isbn: book.isbnPrint)
        }
        return urls
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    let fallback: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.custom("Avenir Next Demi Bold", size: 9))
                .tracking(1.0)
                .foregroundStyle(Palette.highlight)

            Text(value.isEmpty ? fallback : value)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(Palette.ink)
                .lineLimit(3)
        }
    }
}
