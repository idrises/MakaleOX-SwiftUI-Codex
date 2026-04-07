import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteJournalIDs: Set<String>
    @Published private(set) var favoriteBookIDs: Set<String>
    @Published private(set) var favoriteVideoSetIDs: Set<String>

    private let journalKey = "MakaleSwiftUI.favoriteJournal"
    private let bookKey = "MakaleSwiftUI.favoriteBook"
    private let videoSetKey = "MakaleSwiftUI.favoriteVideoSet"

    init() {
        self.favoriteJournalIDs = Set(UserDefaults.standard.stringArray(forKey: journalKey) ?? [])
        self.favoriteBookIDs = Set(UserDefaults.standard.stringArray(forKey: bookKey) ?? [])
        self.favoriteVideoSetIDs = Set(UserDefaults.standard.stringArray(forKey: videoSetKey) ?? [])
    }

    func toggleJournal(_ journal: Journal) {
        toggle(&favoriteJournalIDs, value: journal.id)
        persist(favoriteJournalIDs, key: journalKey)
    }

    func toggleBook(_ book: Book) {
        toggle(&favoriteBookIDs, value: book.id)
        persist(favoriteBookIDs, key: bookKey)
    }

    func toggleVideoSet(_ set: VideoSet) {
        toggle(&favoriteVideoSetIDs, value: set.id)
        persist(favoriteVideoSetIDs, key: videoSetKey)
    }

    func isFavorite(journal: Journal) -> Bool { favoriteJournalIDs.contains(journal.id) }
    func isFavorite(book: Book) -> Bool { favoriteBookIDs.contains(book.id) }
    func isFavorite(videoSet: VideoSet) -> Bool { favoriteVideoSetIDs.contains(videoSet.id) }

    private func toggle(_ values: inout Set<String>, value: String) {
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
    }

    private func persist(_ values: Set<String>, key: String) {
        UserDefaults.standard.set(Array(values).sorted(), forKey: key)
    }
}
