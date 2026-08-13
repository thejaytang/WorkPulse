import Foundation

public enum TelemetryEventName: String, Codable, Sendable {
    case sourceEventObserved = "source_event_observed"
    case surfacePresented = "surface_presented"
    case openRequestAccepted = "open_request_accepted"
    case openConfirmedExact = "open_confirmed_exact"
    case fallbackPresented = "fallback_presented"
    case acknowledged
    case resolved
    case invalidated
}

public struct TelemetryEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var eventID: UUID
    public var recordedAt: Date
    public var name: TelemetryEventName
    public var workEventType: WorkEventType?
    public var surface: DeliverySurface?
    public var resolution: EventResolutionState?
    public var freshness: DataFreshness?

    public init(
        eventID: UUID,
        recordedAt: Date,
        name: TelemetryEventName,
        workEventType: WorkEventType? = nil,
        surface: DeliverySurface? = nil,
        resolution: EventResolutionState? = nil,
        freshness: DataFreshness? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.eventID = eventID
        self.recordedAt = recordedAt
        self.name = name
        self.workEventType = workEventType
        self.surface = surface
        self.resolution = resolution
        self.freshness = freshness
    }
}

public enum TelemetryExporter {
    public static let forbiddenKeys: Set<String> = [
        "title", "url", "path", "prompt", "content", "message", "gmail",
        "adapterid", "sourceeventid"
    ]

    public static func encode(_ envelope: TelemetryEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        guard containsOnlyAllowedKeys(data) else {
            throw TelemetryExportError.forbiddenField
        }
        return data
    }

    public static func containsOnlyAllowedKeys(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return false }
        return dictionary.keys.allSatisfy { !forbiddenKeys.contains($0.lowercased()) }
    }
}

public enum TelemetryExportError: Error, Equatable, Sendable {
    case forbiddenField
}

public struct TelemetryRetentionPolicy: Equatable, Sendable {
    public var retentionDays: Int

    public init(retentionDays: Int = 14) {
        self.retentionDays = max(1, retentionDays)
    }

    public func shouldDelete(recordedAt: Date, now: Date) -> Bool {
        guard let cutoff = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -retentionDays,
            to: now
        ) else { return false }
        return recordedAt < cutoff
    }
}

public enum SafetyStopReason: String, Codable, Hashable, Sendable {
    case privacyExposure
    case wrongTarget
    case falseHighRiskAlert
    case incompatibleSchema
}

public struct PilotSafetyMonitor: Codable, Equatable, Sendable {
    public private(set) var reasons: Set<SafetyStopReason>

    public init() {
        self.reasons = []
    }

    public var shouldStop: Bool { !reasons.isEmpty }

    public mutating func record(_ reason: SafetyStopReason) {
        reasons.insert(reason)
    }
}
