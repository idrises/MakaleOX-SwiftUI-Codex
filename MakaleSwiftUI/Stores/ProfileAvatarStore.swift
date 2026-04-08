import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class ProfileAvatarStore: ObservableObject {
    static let shared = ProfileAvatarStore()

    @Published private var avatarDataByIdentity: [String: Data]

    private let storageKey = "MakaleSwiftUI.profileAvatarStore"

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data)
        else {
            self.avatarDataByIdentity = [:]
            return
        }

        self.avatarDataByIdentity = decoded
    }

    func imageData(for session: SessionInfo) -> Data? {
        avatarDataByIdentity[identity(for: session)]
    }

    func saveAvatarData(_ data: Data, for session: SessionInfo) {
        guard let normalized = normalizedAvatarData(from: data) else { return }
        avatarDataByIdentity[identity(for: session)] = normalized
        persist()
    }

    private func identity(for session: SessionInfo) -> String {
        if !session.userID.isEmpty {
            return session.userID
        }
        if !session.email.isEmpty {
            return session.email.lowercased()
        }
        return session.displayName.lowercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(avatarDataByIdentity) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func normalizedAvatarData(from data: Data) -> Data? {
#if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 640
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1)
        let targetSize = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.84) ?? rendered.pngData()
#elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return image.tiffRepresentation
#else
        return data
#endif
    }
}
