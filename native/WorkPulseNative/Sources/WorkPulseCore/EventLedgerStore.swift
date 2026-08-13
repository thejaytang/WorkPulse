import Foundation

public enum EventLedgerStoreError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
}

private struct EventLedgerSchemaHeader: Decodable {
    let schemaVersion: Int
}

public struct PersistedEventLedger: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var revision: UInt64
    public var writtenAt: Date
    public var ledger: EventLedger

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        revision: UInt64 = 0,
        writtenAt: Date,
        ledger: EventLedger
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.writtenAt = writtenAt
        self.ledger = ledger
    }
}

public actor EventLedgerStore {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys]
    }

    @discardableResult
    public func write(
        _ ledger: EventLedger,
        revision: UInt64 = 0,
        at date: Date = .now
    ) throws -> Bool {
        if let current = try read() {
            if current.revision > revision { return false }
            if current.revision == revision { return current.ledger == ledger }
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let persisted = PersistedEventLedger(
            revision: revision,
            writtenAt: date,
            ledger: ledger
        )
        let data = try encoder.encode(persisted)
        try data.write(to: fileURL, options: [.atomic])
        return true
    }

    public func read() throws -> PersistedEventLedger? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let header = try decoder.decode(EventLedgerSchemaHeader.self, from: data)
        guard header.schemaVersion == PersistedEventLedger.currentSchemaVersion else {
            throw EventLedgerStoreError.unsupportedSchema(header.schemaVersion)
        }
        let persisted = try decoder.decode(PersistedEventLedger.self, from: data)
        return persisted
    }
}
