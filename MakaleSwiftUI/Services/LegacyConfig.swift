import Foundation

enum LegacyConfig {
    static let server = "77.245.148.21"
    static let username = "NDB226238"
    static let password = "F1y9j31Z"
    static let database = "NDB226238"

    static let portalRoot = "http://plastikcerrahiportal.net"
    static let dataRoot = "\(portalRoot)/DDAATTAA"
    static let imageRoot = "\(dataRoot)/images"
    static let coverRoot = "\(imageRoot)/cover"
    static let issueRoot = "\(imageRoot)/issues"
    static let videoCoverRoot = "\(imageRoot)/videoCover"
    static let booksRoot = "\(portalRoot)/books"
    static let videosRoot = "\(portalRoot)/videos"
    static let videoSetsRoot = "\(portalRoot)/videosetler"

    static func encodedPathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectory = base.appendingPathComponent("MakaleSwiftUIData", isDirectory: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    static func coverCandidates(for journal: String) -> [URL] {
        let encodedJournal = encodedPathComponent(journal)
        return [
            "\(coverRoot)/\(encodedJournal).jpg",
            "\(coverRoot)/\(encodedJournal).gif",
            "\(coverRoot)/\(encodedJournal).png"
        ].compactMap(URL.init(string:))
    }

    static func issueCoverCandidates(journal: String, issue: String) -> [URL] {
        let encodedJournal = encodedPathComponent(journal)
        let encodedIssue = encodedPathComponent(issue)
        let issueCandidates = [
            "\(issueRoot)/\(encodedJournal)/\(encodedIssue).jpg",
            "\(issueRoot)/\(encodedJournal)/\(encodedIssue).gif",
            "\(issueRoot)/\(encodedJournal)/\(encodedIssue).png"
        ]
        return issueCandidates.compactMap(URL.init(string:)) + coverCandidates(for: journal)
    }

    static func bookCoverCandidates(isbn: String) -> [URL] {
        let encoded = encodedPathComponent(isbn) + ".jpg"
        return ["\(coverRoot)/\(encoded)"].compactMap(URL.init(string:))
    }

    static func videoCoverCandidates(name: String) -> [URL] {
        let encoded = encodedPathComponent(name)
        return [
            "\(videoCoverRoot)/\(encoded).jpg",
            "\(videoCoverRoot)/\(encoded).gif"
        ].compactMap(URL.init(string:))
    }

    static func articleRemoteURL(journal: String, folder: String, pdfLink: String) -> URL? {
        URL(string: "\(dataRoot)/\(encodedPathComponent(journal))/\(encodedPathComponent(folder))/\(encodedPathComponent(pdfLink)).pdf")
    }

    static func chapterRemoteURL(isbn: String, pdfLink: String) -> URL? {
        URL(string: "\(booksRoot)/\(encodedPathComponent(isbn))/\(encodedPathComponent(pdfLink)).pdf")
    }

    static func videoRemoteURL(bookJournal: String, link: String) -> URL? {
        URL(string: "\(videosRoot)/\(encodedPathComponent(bookJournal))/\(encodedPathComponent(link))")
    }

    static func videoSetRemoteURL(setName: String, link: String) -> URL? {
        URL(string: "\(videoSetsRoot)/\(encodedPathComponent(setName))/\(encodedPathComponent(link))")
    }
}

extension String {
    var sqlEscaped: String {
        replacingOccurrences(of: "'", with: "''")
    }
}
