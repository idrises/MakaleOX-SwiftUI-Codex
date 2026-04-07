import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: SessionInfo?

    private let storageKey = "MakaleSwiftUI.session"

    init() {
        restore()
    }

    func restore() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let session = try? JSONDecoder().decode(SessionInfo.self, from: data)
        else {
            self.session = nil
            return
        }

        self.session = session
    }

    func save(_ session: SessionInfo) {
        self.session = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func clear() {
        session = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
