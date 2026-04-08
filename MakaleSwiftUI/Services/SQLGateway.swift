import Foundation

enum SQLGatewayError: LocalizedError {
    case connectionFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            if detail.isEmpty {
                return "The app could not connect to the legacy content server."
            }
            return "The app could not connect to the legacy content server. \(detail)"
        case .queryFailed(let detail):
            if detail.isEmpty {
                return "The app could not complete the database request."
            }
            return "The app could not complete the database request. \(detail)"
        }
    }
}

#if os(macOS) || os(iOS)
private final class SQLClientDelegateProxy: NSObject, SQLClientDelegate {
    private let lock = NSLock()
    private var lastErrorDetail = ""

    func clear() {
        lock.lock()
        lastErrorDetail = ""
        lock.unlock()
    }

    func takeLastError() -> String {
        lock.lock()
        defer {
            lastErrorDetail = ""
            lock.unlock()
        }
        return lastErrorDetail
    }

    func error(_ error: String!, code: Int32, severity: Int32) {
        lock.lock()
        lastErrorDetail = "[\(code)] \(error ?? "Unknown SQL error")"
        lock.unlock()
    }

    func message(_ message: String!) {
        // Legacy callbacks are noisy; the last explicit error is enough for UI feedback.
    }
}

actor SQLGateway {
    private let client = SQLClient.sharedInstance()!
    private let delegate = SQLClientDelegateProxy()
    private let callbackQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "MakaleSwiftUI.SQLClient.Callbacks"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func query(_ sql: String, parameters: [Any?] = [], timeout: Int = 60) async throws -> [SQLRow] {
        let command = SQLGateway.interpolate(sql: sql, parameters: parameters)
        let tables = try await runWithRetry(command, timeout: timeout)
        return tables.first ?? []
    }

    @discardableResult
    func execute(_ sql: String, parameters: [Any?] = [], timeout: Int = 60) async throws -> Int {
        let command = SQLGateway.interpolate(sql: sql, parameters: parameters)
        _ = try await runWithRetry(command, timeout: timeout)
        return 0
    }

    private func runWithRetry(_ sql: String, timeout: Int) async throws -> [[SQLRow]] {
        do {
            return try await run(sql, timeout: timeout)
        } catch {
            guard shouldRetry(after: error) else { throw error }

            delegate.clear()
            client.disconnect()
            try? await Task.sleep(nanoseconds: 200_000_000)
            return try await run(sql, timeout: timeout)
        }
    }

    private func run(_ sql: String, timeout: Int) async throws -> [[SQLRow]] {
        configureClient(timeout: timeout)
        try await connect()
        defer { client.disconnect() }

        delegate.clear()
        let results = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[[SQLRow]], Error>) in
            client.execute(sql) { [delegate] tables in
                guard let tables else {
                    let detail = delegate.takeLastError()
                    continuation.resume(throwing: SQLGatewayError.queryFailed(detail))
                    return
                }

                let parsedTables: [[SQLRow]] = tables.compactMap { table in
                    let rows = table as? [Any] ?? []
                    let parsedRows = rows.compactMap { $0 as? SQLRow }
                    return parsedRows
                }
                continuation.resume(returning: parsedTables)
            }
        }

        return results
    }

    private func connect() async throws {
        delegate.clear()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.connect(
                LegacyConfig.server,
                username: LegacyConfig.username,
                password: LegacyConfig.password,
                database: LegacyConfig.database
            ) { [delegate] success in
                guard success else {
                    let detail = delegate.takeLastError()
                    continuation.resume(throwing: SQLGatewayError.connectionFailed(detail))
                    return
                }

                continuation.resume()
            }
        }
    }

    private func configureClient(timeout: Int) {
        client.timeout = Int32(max(timeout, 5))
        client.charset = "UTF-8"
        client.delegate = delegate
        client.callbackQueue = callbackQueue
    }

    private func shouldRetry(after error: Error) -> Bool {
        guard let gatewayError = error as? SQLGatewayError else { return false }

        let detail: String
        switch gatewayError {
        case .connectionFailed(let value), .queryFailed(let value):
            detail = value.lowercased()
        }

        let retryHints = [
            "[20009]",
            "[20047]",
            "[20056]",
            "unable to connect",
            "adaptive server is unavailable or does not exist",
            "dbprocess is dead",
            "error in closing network connection",
            "adaptive server connection timed out",
            "datastream processing out of sync"
        ]

        return retryHints.contains { detail.contains($0) }
    }

    private static func interpolate(sql: String, parameters: [Any?]) -> String {
        guard !parameters.isEmpty else { return sql }

        let parts = sql.components(separatedBy: "?")
        guard parts.count - 1 == parameters.count else { return sql }

        var output = ""
        for (index, part) in parts.dropLast().enumerated() {
            output += part
            output += literal(for: parameters[index])
        }
        output += parts.last ?? ""
        return output
    }

    private static func literal(for value: Any?) -> String {
        guard let value else { return "NULL" }

        switch value {
        case let number as NSNumber:
            return number.stringValue
        case let date as Date:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return "'\(formatter.string(from: date))'"
        case let string as String:
            return "'\(string.replacingOccurrences(of: "'", with: "''"))'"
        default:
            return "'\("\(value)".replacingOccurrences(of: "'", with: "''"))'"
        }
    }

}
#else
actor SQLGateway {
    func query(_ sql: String, parameters: [Any?] = [], timeout: Int = 60) async throws -> [SQLRow] {
        throw SQLGatewayError.connectionFailed("iPad and iPhone builds still need an iOS-compatible SQL client layer.")
    }

    @discardableResult
    func execute(_ sql: String, parameters: [Any?] = [], timeout: Int = 60) async throws -> Int {
        throw SQLGatewayError.connectionFailed("iPad and iPhone builds still need an iOS-compatible SQL client layer.")
    }
}
#endif
