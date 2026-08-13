import Foundation

public enum SnapshotStoreError: Error, Equatable {
    case unsupportedSchema(Int)
}

private struct SnapshotSchemaHeader: Decodable {
    let schemaVersion: Int
}

public actor SnapshotStore {
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
    public func write(_ snapshot: WidgetSnapshot) throws -> Bool {
        var candidate = snapshot
        if let current = try read() {
            if snapshot.generatedAt < current.generatedAt { return false }
            if snapshot.generatedAt == current.generatedAt {
                candidate.revision = current.revision
                return candidate == current
            }
            candidate.revision = current.revision &+ 1
        } else {
            candidate.revision = max(1, snapshot.revision)
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(candidate)
        try data.write(to: fileURL, options: [.atomic])
        return true
    }

    public func writeNext(_ snapshot: WidgetSnapshot) throws -> WidgetSnapshot {
        var candidate = snapshot
        let previousRevision: UInt64
        do {
            previousRevision = try read()?.revision ?? 0
        } catch SnapshotStoreError.unsupportedSchema {
            // A host + extension update must be able to replace its own older schema.
            previousRevision = 0
        } catch is DecodingError {
            // Preserve corrupt bytes for diagnostics, then let the host repair the
            // canonical snapshot. I/O and permission errors still fail closed.
            try quarantineCorruptSnapshot()
            previousRevision = 0
        }
        candidate.revision = previousRevision &+ 1
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(candidate)
        try data.write(to: fileURL, options: [.atomic])
        return candidate
    }

    public func read() throws -> WidgetSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let header = try decoder.decode(SnapshotSchemaHeader.self, from: data)
        guard header.schemaVersion == WidgetSnapshot.currentSchemaVersion else {
            throw SnapshotStoreError.unsupportedSchema(header.schemaVersion)
        }
        let snapshot = try decoder.decode(WidgetSnapshot.self, from: data)
        return snapshot
    }

    private func quarantineCorruptSnapshot() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let quarantineURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(UUID().uuidString)")
        try fileManager.copyItem(at: fileURL, to: quarantineURL)
    }
}
