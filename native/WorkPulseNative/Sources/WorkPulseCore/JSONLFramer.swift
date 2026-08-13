import Foundation

public enum JSONLFramerError: Error, Equatable, Sendable {
    case lineTooLarge
    case bufferTooLarge
    case truncatedFrame
}

public struct JSONLFramer: Sendable {
    private var buffer = Data()
    public let maximumLineBytes: Int
    public let maximumBufferBytes: Int

    public init(maximumLineBytes: Int = 4 * 1_024 * 1_024, maximumBufferBytes: Int = 8 * 1_024 * 1_024) {
        self.maximumLineBytes = maximumLineBytes
        self.maximumBufferBytes = maximumBufferBytes
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        guard buffer.count + data.count <= maximumBufferBytes else {
            buffer.removeAll(keepingCapacity: false)
            throw JSONLFramerError.bufferTooLarge
        }
        buffer.append(data)

        var lines: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            var line = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            if line.last == 0x0D { line = line.dropLast() }
            guard line.count <= maximumLineBytes else {
                buffer.removeAll(keepingCapacity: false)
                throw JSONLFramerError.lineTooLarge
            }
            if !line.isEmpty, !line.allSatisfy({ $0 == 0x20 || $0 == 0x09 }) {
                lines.append(Data(line))
            }
        }

        guard buffer.count <= maximumLineBytes else {
            buffer.removeAll(keepingCapacity: false)
            throw JSONLFramerError.lineTooLarge
        }
        return lines
    }

    public mutating func finish() throws -> Data? {
        defer { buffer.removeAll(keepingCapacity: false) }
        if buffer.isEmpty || buffer.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }) {
            return nil
        }
        throw JSONLFramerError.truncatedFrame
    }
}

public struct ReconnectPolicy: Equatable, Sendable {
    public var baseDelay: TimeInterval
    public var maximumDelay: TimeInterval

    public init(baseDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 30) {
        self.baseDelay = max(0, baseDelay)
        self.maximumDelay = max(self.baseDelay, maximumDelay)
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        return min(maximumDelay, baseDelay * pow(2, Double(attempt - 1)))
    }
}
