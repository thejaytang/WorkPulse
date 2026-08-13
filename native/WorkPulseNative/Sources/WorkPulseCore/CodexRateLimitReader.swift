import Foundation

public struct RateLimitBucketSnapshot: Equatable, Identifiable, Sendable {
    public var limitID: String
    public var displayName: String?
    public var usedPercent: Double
    public var windowDurationMinutes: Int
    public var resetsAt: Date

    public init(limitID: String, displayName: String?, usedPercent: Double, windowDurationMinutes: Int, resetsAt: Date) {
        self.limitID = limitID
        self.displayName = displayName
        self.usedPercent = max(0, min(100, usedPercent))
        self.windowDurationMinutes = max(0, windowDurationMinutes)
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double { 100 - usedPercent }
    public var id: String { limitID }
}

public enum CodexRateLimitReaderError: Error, LocalizedError, Sendable {
    case codexNotFound
    case serverExited
    case timedOut
    case initializeRejected
    case rateLimitsUnavailable
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case .codexNotFound: "未找到本机 Codex 可执行文件。"
        case .serverExited: "Codex App Server 在读取完成前退出。"
        case .timedOut: "读取 Codex 额度超时。"
        case .initializeRejected: "Codex App Server 初始化失败。"
        case .rateLimitsUnavailable: "当前账号或版本不提供额度数据。"
        case .malformedResponse: "Codex App Server 返回了无法识别的数据。"
        }
    }
}

public enum CodexRateLimitReader {
    public static func resolveExecutable() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0) }
    }

    public static func read(executableURL: URL? = nil) throws -> [RateLimitBucketSnapshot] {
        guard let executable = executableURL ?? resolveExecutable() else {
            throw CodexRateLimitReaderError.codexNotFound
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]

        let input = Pipe()
        let output = Pipe()
        let diagnostic = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = diagnostic
        diagnostic.fileHandleForReading.readabilityHandler = { handle in
            // Drain stderr so a verbose experimental server cannot block on a full pipe.
            // Diagnostics are intentionally discarded here because they may contain paths.
            _ = handle.availableData
        }

        try process.run()
        let timeoutGuard = ProcessTimeoutGuard(process: process)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 8)
        timer.setEventHandler { timeoutGuard.expire() }
        timer.resume()
        defer {
            timer.cancel()
            diagnostic.fileHandleForReading.readabilityHandler = nil
            input.fileHandleForWriting.closeFile()
            if process.isRunning { process.terminate() }
        }

        let initializeRequest = #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"workpulse","title":"WorkPulse","version":"0.2.0"},"capabilities":{"experimentalApi":false,"optOutNotificationMethods":[]}}}"# + "\n"
        input.fileHandleForWriting.write(Data(initializeRequest.utf8))

        var framer = JSONLFramer()
        var initialized = false

        while true {
            let data = output.fileHandleForReading.availableData
            guard !data.isEmpty else {
                throw timeoutGuard.hasExpired ? CodexRateLimitReaderError.timedOut : CodexRateLimitReaderError.serverExited
            }

            for line in try framer.append(data) {
                guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                    throw CodexRateLimitReaderError.malformedResponse
                }
                if (object["id"] as? Int) == 1 {
                    guard object["result"] != nil, object["error"] == nil else {
                        throw CodexRateLimitReaderError.initializeRejected
                    }
                    if !initialized {
                        initialized = true
                        let readyRequests = [
                            #"{"method":"initialized","params":{}}"#,
                            #"{"id":2,"method":"account/rateLimits/read"}"#
                        ].joined(separator: "\n") + "\n"
                        input.fileHandleForWriting.write(Data(readyRequests.utf8))
                    }
                }
                if (object["id"] as? Int) == 2 {
                    guard initialized else { throw CodexRateLimitReaderError.initializeRejected }
                    return try decodeRateLimitsResponse(line)
                }
            }
        }
    }

    public static func decodeRateLimitsResponse(_ data: Data) throws -> [RateLimitBucketSnapshot] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["error"] == nil,
              let result = object["result"] as? [String: Any] else {
            throw CodexRateLimitReaderError.rateLimitsUnavailable
        }

        func decodeBucket(limitID: String, raw: Any) -> RateLimitBucketSnapshot? {
            guard let bucket = raw as? [String: Any],
                  let primary = bucket["primary"] as? [String: Any],
                  let usedPercent = (primary["usedPercent"] as? NSNumber)?.doubleValue,
                  let duration = (primary["windowDurationMins"] as? NSNumber)?.intValue,
                  let resetSeconds = (primary["resetsAt"] as? NSNumber)?.doubleValue else { return nil }

            return RateLimitBucketSnapshot(
                limitID: limitID,
                displayName: bucket["limitName"] as? String,
                usedPercent: usedPercent,
                windowDurationMinutes: duration,
                resetsAt: Date(timeIntervalSince1970: resetSeconds)
            )
        }

        var buckets: [RateLimitBucketSnapshot] = []
        if let bucketObjects = result["rateLimitsByLimitId"] as? [String: Any] {
            buckets = bucketObjects.compactMap { decodeBucket(limitID: $0.key, raw: $0.value) }
        }
        if buckets.isEmpty, let single = result["rateLimits"] as? [String: Any] {
            let limitID = (single["limitId"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "default"
            if let bucket = decodeBucket(limitID: limitID, raw: single) {
                buckets = [bucket]
            }
        }
        guard !buckets.isEmpty else { throw CodexRateLimitReaderError.rateLimitsUnavailable }
        return buckets.sorted { $0.limitID < $1.limitID }
    }
}

private final class ProcessTimeoutGuard: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var expired = false

    init(process: Process) {
        self.process = process
    }

    var hasExpired: Bool {
        lock.withLock { expired }
    }

    func expire() {
        lock.withLock { expired = true }
        if process.isRunning { process.terminate() }
    }
}
