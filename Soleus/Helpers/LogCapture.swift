import Foundation
import Combine
import FirebaseCrashlytics

class LogCapture: ObservableObject {
    static let shared = LogCapture()

    @Published var logs: [LogEntry] = []
    private let maxLogs = 500

    // Persistent log file for error/critical entries that survive crashes
    private static let persistedLogURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("soleus-persisted-errors.log")
    }()

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let level: LogLevel
        let message: String

        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    enum LogLevel: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case critical = "🔥"
    }

    private init() {
        loadPersistedLogs()
    }

    func log(_ message: String, category: String = "General", level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), category: category, level: level, message: message)

        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }

        // Persist error and critical logs synchronously so they survive crashes
        if level == .error || level == .critical {
            persistEntry(entry)
        }

        // Forward to Crashlytics as breadcrumbs and non-fatals.
        // Strip user-entered content before it leaves the device.
        let remoteMessage = Self.scrubUserContent(message)
        switch level {
        case .warning, .error, .critical:
            Crashlytics.crashlytics().log("[\(category)] \(remoteMessage)")
        default:
            break
        }
        if level == .error || level == .critical {
            let err = NSError(
                domain: "com.damiensprinkle.Soleus.\(category)",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: remoteMessage]
            )
            Crashlytics.crashlytics().record(error: err)
        }
    }

    // MARK: - Scrubbing

    // Convention: log statements wrap user-entered values in single quotes
    // (e.g. "Adding exercise '\(name)'"). This strips anything between single
    // quotes before logs leave the device, so exercise names, workout titles,
    // and notes never reach Crashlytics or the support-email attachment.
    private static let userContentRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "'[^']*'", options: [])
    }()

    static func scrubUserContent(_ message: String) -> String {
        guard let regex = userContentRegex else { return message }
        let range = NSRange(message.startIndex..., in: message)
        return regex.stringByReplacingMatches(in: message, options: [], range: range, withTemplate: "'<redacted>'")
    }

    func debug(_ message: String, category: String = "General") {
        log(message, category: category, level: .debug)
    }

    func info(_ message: String, category: String = "General") {
        log(message, category: category, level: .info)
    }

    func warning(_ message: String, category: String = "General") {
        log(message, category: category, level: .warning)
    }

    func error(_ message: String, category: String = "General") {
        log(message, category: category, level: .error)
    }

    func critical(_ message: String, category: String = "General") {
        log(message, category: category, level: .critical)
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
        try? FileManager.default.removeItem(at: Self.persistedLogURL)
    }

    // MARK: - Persistence

    private func persistEntry(_ entry: LogEntry) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        // Scrub user content before persisting — this file is attached to
        // support emails, so it must not contain exercise names or notes.
        // Escape backslashes then newlines so each entry stays on one line.
        let safeMessage = Self.scrubUserContent(entry.message)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
        let line = "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(safeMessage)\n"
        guard let data = line.data(using: .utf8) else { return }

        let url = Self.persistedLogURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }

        trimPersistedLog()
    }

    private func loadPersistedLogs() {
        guard let contents = try? String(contentsOf: Self.persistedLogURL, encoding: .utf8) else { return }
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let entries: [LogEntry] = lines.compactMap { line in
            // Format: [date] [emoji] [category] message
            guard line.hasPrefix("[") else { return nil }
            let parts = line.components(separatedBy: "] [")
            // Minimum 3 parts: "[date", "emoji", "category] message"]
            guard parts.count >= 3 else { return nil }
            let dateStr = String(parts[0].dropFirst())
            let emoji = parts[1]
            // parts[2] contains "category] message" — split on first "] "
            let remainder = parts[2...].joined(separator: "] [")
            guard let closingRange = remainder.range(of: "] ") else { return nil }
            let category = String(remainder[remainder.startIndex..<closingRange.lowerBound])
            let rawMessage = String(remainder[closingRange.upperBound...])
            // Unescape: restore newlines and backslashes
            let message = rawMessage
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\\", with: "\\")
            let level = LogLevel.allCases.first { $0.rawValue == emoji } ?? .error
            let date = formatter.date(from: dateStr) ?? Date()
            return LogEntry(timestamp: date, category: "(prev) \(category)", level: level, message: message)
        }

        if !entries.isEmpty {
            logs = entries
        }
    }

    private func trimPersistedLog() {
        guard let contents = try? String(contentsOf: Self.persistedLogURL, encoding: .utf8) else { return }
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if lines.count > 200 {
            let trimmed = lines.suffix(200).joined(separator: "\n") + "\n"
            try? trimmed.write(to: Self.persistedLogURL, atomically: true, encoding: .utf8)
        }
    }
}

extension LogCapture.LogLevel: CaseIterable {}
