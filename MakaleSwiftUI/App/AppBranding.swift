import Foundation

enum AppBranding {
    static var title: String {
        if let title = Bundle.main.object(forInfoDictionaryKey: "AppBrandTitle") as? String,
           !title.isEmpty {
            return title
        }
        return "MedLib"
    }
}
