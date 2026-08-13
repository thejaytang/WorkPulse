import Foundation
import SQLite3

public struct CodexRunningTaskSnapshot: Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var startedAt: Date
    public var lastActivityAt: Date
    public var rolloutPath: String?

    public init(
        id: String,
        displayName: String,
        startedAt: Date,
        lastActivityAt: Date,
        rolloutPath: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.rolloutPath = rolloutPath
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}

public enum CodexTaskReaderError: Error, LocalizedError, Sendable {
    case stateDatabaseUnavailable
    case stateDatabaseOpenFailed
    case stateQueryFailed

    public var errorDescription: String? {
        switch self {
        case .stateDatabaseUnavailable:
            "未找到 Codex 本地任务状态数据库。"
        case .stateDatabaseOpenFailed:
            "无法以只读方式打开 Codex 本地任务状态数据库。"
        case .stateQueryFailed:
            "Codex 本地任务元数据查询失败。"
        }
    }
}

public enum CodexTaskLifecycleState: Equatable, Sendable {
    case running(startedAt: Date)
    case inactive
    case unknown
}

public enum CodexTaskTerminalOutcome: String, Codable, Equatable, Sendable {
    case completed
    case cancelled
    case failed
    case aborted
}

public enum CodexTaskLatestLifecycleEvent: Equatable, Sendable {
    case started(Date)
    case terminal(CodexTaskTerminalOutcome, Date)
}

public enum CodexTaskLifecycleDetector {
    private static let terminalTypes: Set<String> = [
        "task_complete",
        "task_cancelled",
        "task_canceled",
        "task_failed",
        "turn_aborted"
    ]

    public static func state(fromNewestLines lines: [Data]) -> CodexTaskLifecycleState {
        guard let event = latestEvent(fromNewestLines: lines) else { return .unknown }
        switch event {
        case .started(let date): return .running(startedAt: date)
        case .terminal: return .inactive
        }
    }

    public static func terminalOutcome(fromNewestLines lines: [Data]) -> CodexTaskTerminalOutcome? {
        guard case .terminal(let outcome, _) = latestEvent(fromNewestLines: lines) else { return nil }
        return outcome
    }

    public static func latestEvent(fromNewestLines lines: [Data]) -> CodexTaskLatestLifecycleEvent? {
        for line in lines {
            guard let event = lifecycleEvent(from: line) else { continue }
            switch event.type {
            case "task_started": return .started(event.timestamp)
            case "task_complete": return .terminal(.completed, event.timestamp)
            case "task_cancelled", "task_canceled": return .terminal(.cancelled, event.timestamp)
            case "task_failed": return .terminal(.failed, event.timestamp)
            case "turn_aborted": return .terminal(.aborted, event.timestamp)
            default: continue
            }
        }
        return nil
    }

    private static func lifecycleEvent(from line: Data) -> (type: String, timestamp: Date)? {
        guard line.range(of: Data("task_".utf8)) != nil
                || line.range(of: Data("turn_aborted".utf8)) != nil,
              let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any],
              let type = payload["type"] as? String,
              type == "task_started" || terminalTypes.contains(type),
              let rawTimestamp = object["timestamp"] as? String,
              let timestamp = parseTimestamp(rawTimestamp) else {
            return nil
        }
        return (type, timestamp)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

public enum CodexRunningTaskReader {
    private static let recentCandidateInterval: TimeInterval = 48 * 60 * 60
    private static let activeSilenceLimit: TimeInterval = 24 * 60 * 60
    private static let chunkSize: UInt64 = 256 * 1_024
    private static let maximumScanSize: UInt64 = 32 * 1_024 * 1_024
    private static let lifecycleCache = CodexTaskLifecycleCache()

    public static func read(
        codexHome: URL? = nil,
        now: Date = Date(),
        maximumCandidates: Int = 50
    ) throws -> [CodexRunningTaskSnapshot] {
        let home = codexHome ?? defaultCodexHome()
        let databaseURL = home.appendingPathComponent("state_5.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw CodexTaskReaderError.stateDatabaseUnavailable
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            if let database { sqlite3_close(database) }
            throw CodexTaskReaderError.stateDatabaseOpenFailed
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 250)

        let sql = """
        SELECT id, rollout_path, COALESCE(NULLIF(name, ''), ''), title, cwd, recency_at_ms
        FROM threads
        WHERE archived = 0
          AND recency_at_ms >= ?
          AND COALESCE(source, '') NOT LIKE '%subagent%'
        ORDER BY recency_at_ms DESC, id DESC
        LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw CodexTaskReaderError.stateQueryFailed
        }
        defer { sqlite3_finalize(statement) }

        let cutoffMilliseconds = Int64(now.addingTimeInterval(-recentCandidateInterval).timeIntervalSince1970 * 1_000)
        sqlite3_bind_int64(statement, 1, cutoffMilliseconds)
        sqlite3_bind_int(statement, 2, Int32(max(1, min(maximumCandidates, 200))))

        var snapshots: [CodexRunningTaskSnapshot] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = textColumn(statement, index: 0),
                  let rolloutPath = textColumn(statement, index: 1),
                  !id.isEmpty,
                  !rolloutPath.isEmpty else { continue }

            let rolloutURL = URL(fileURLWithPath: rolloutPath)
            guard let lifecycle = try? lifecycleState(at: rolloutURL),
                  case .running(let startedAt) = lifecycle else { continue }

            let attributes = try? FileManager.default.attributesOfItem(atPath: rolloutPath)
            let lastActivityAt = (attributes?[.modificationDate] as? Date) ?? startedAt
            guard now.timeIntervalSince(lastActivityAt) <= activeSilenceLimit else { continue }

            let storedName = textColumn(statement, index: 2)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let storedTitle = textColumn(statement, index: 3).flatMap(conciseDisplayTitle)
            let cwd = textColumn(statement, index: 4) ?? ""
            let fallbackName = URL(fileURLWithPath: cwd).lastPathComponent
            let displayName = storedName.flatMap { $0.isEmpty ? nil : $0 }
                ?? storedTitle
                ?? (fallbackName.isEmpty ? "Codex 任务" : fallbackName)

            snapshots.append(CodexRunningTaskSnapshot(
                id: id,
                displayName: displayName,
                startedAt: startedAt,
                lastActivityAt: lastActivityAt,
                rolloutPath: rolloutPath
            ))
        }

        return snapshots.sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id < $1.id
        }
    }

    public static func terminalOutcome(for snapshot: CodexRunningTaskSnapshot) -> CodexTaskTerminalOutcome? {
        guard let rolloutPath = snapshot.rolloutPath, !rolloutPath.isEmpty else { return nil }
        return try? terminalOutcome(at: URL(fileURLWithPath: rolloutPath))
    }

    private static func defaultCodexHome() -> URL {
        if let configured = ProcessInfo.processInfo.environment["CODEX_HOME"], !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    private static func textColumn(_ statement: OpaquePointer, index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    private static func conciseDisplayTitle(_ value: String) -> String? {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              !normalized.hasPrefix("The following is the Codex agent history") else { return nil }
        let firstClause = normalized.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { "。！？!?".contains($0) }
        ).first.map(String.init) ?? normalized
        let limit = 48
        return firstClause.count > limit ? String(firstClause.prefix(limit)) + "…" : firstClause
    }

    private static func lifecycleState(at url: URL) throws -> CodexTaskLifecycleState {
        guard let event = try latestLifecycleEvent(at: url) else { return .unknown }
        switch event {
        case .started(let date): return .running(startedAt: date)
        case .terminal: return .inactive
        }
    }

    private static func terminalOutcome(at url: URL) throws -> CodexTaskTerminalOutcome? {
        guard case .terminal(let outcome, _) = try latestLifecycleEvent(at: url) else { return nil }
        return outcome
    }

    private static func latestLifecycleEvent(at url: URL) throws -> CodexTaskLatestLifecycleEvent? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let modificationDate = attributes[.modificationDate] as? Date
        let fileIdentity = CodexTaskLifecycleCache.FileIdentity(
            device: (attributes[.systemNumber] as? NSNumber)?.uint64Value,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )

        if let cached = lifecycleCache.entry(for: url.path),
           cached.fileIdentity == fileIdentity,
           cached.fileSize == fileSize,
           cached.modificationDate == modificationDate {
            return cached.event
        }

        let previous = lifecycleCache.entry(for: url.path)
        let sameFile = previous?.fileIdentity == fileIdentity
        let incrementalLowerBound: UInt64?
        if let previous, sameFile, fileSize >= previous.fileSize {
            let overlapStart = previous.fileSize > chunkSize ? previous.fileSize - chunkSize : 0
            incrementalLowerBound = max(overlapStart, fileSize > maximumScanSize ? fileSize - maximumScanSize : 0)
        } else {
            incrementalLowerBound = nil
        }

        let newlyObserved = try scanLatestLifecycleEvent(
            at: url,
            endOffset: fileSize,
            explicitLowerBound: incrementalLowerBound
        )
        // Only reuse an older lifecycle event when this is provably the same
        // file and it has not been truncated. A path replacement or shrink is
        // a new causal history and must fail closed rather than resurrecting
        // the previous task state.
        let canReusePrevious = sameFile && previous.map { fileSize >= $0.fileSize } == true
        let resolved = newlyObserved ?? (canReusePrevious ? previous?.event : nil)
        lifecycleCache.store(
            CodexTaskLifecycleCache.Entry(
                fileIdentity: fileIdentity,
                fileSize: fileSize,
                modificationDate: modificationDate,
                event: resolved
            ),
            for: url.path
        )
        return resolved
    }

    private static func scanLatestLifecycleEvent(
        at url: URL,
        endOffset: UInt64,
        explicitLowerBound: UInt64? = nil
    ) throws -> CodexTaskLatestLifecycleEvent? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let lowerBound = explicitLowerBound
            ?? (endOffset > maximumScanSize ? endOffset - maximumScanSize : 0)
        var cursor = endOffset
        var trailingFragment = Data()

        while cursor > lowerBound {
            let start = max(lowerBound, cursor > chunkSize ? cursor - chunkSize : 0)
            try handle.seek(toOffset: start)
            let chunk = try handle.read(upToCount: Int(cursor - start)) ?? Data()
            var combined = chunk
            combined.append(trailingFragment)
            let pieces = combined.split(separator: 0x0A, omittingEmptySubsequences: true).map { Data($0) }

            let hasPartialLeadingLine = start > lowerBound && chunk.first != 0x0A
            let inspectable = hasPartialLeadingLine ? Array(pieces.dropFirst()) : pieces
            if let event = CodexTaskLifecycleDetector.latestEvent(
                fromNewestLines: Array(inspectable.reversed())
            ) { return event }

            trailingFragment = hasPartialLeadingLine ? (pieces.first ?? Data()) : Data()
            cursor = start
        }
        return nil
    }
}

private final class CodexTaskLifecycleCache: @unchecked Sendable {
    struct FileIdentity: Equatable {
        var device: UInt64?
        var inode: UInt64?
    }

    struct Entry {
        var fileIdentity: FileIdentity
        var fileSize: UInt64
        var modificationDate: Date?
        var event: CodexTaskLatestLifecycleEvent?
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func entry(for path: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries[path]
    }

    func store(_ entry: Entry, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        if entries.count >= 256, entries[path] == nil {
            entries.remove(at: entries.startIndex)
        }
        entries[path] = entry
    }
}
