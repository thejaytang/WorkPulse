import Foundation

public enum EventResolutionState: String, Codable, Sendable {
    case active
    case acknowledged
    case resolved
    case invalidated
}

public enum EventResolutionKind: String, Codable, Sendable {
    case sourceConfirmed
    case userDisposition
}

public enum EventInvalidationReason: String, Codable, Sendable {
    case sourceRetracted
    case normalizationRejected
    case incompatibleSchema
}

public enum EventUserDisposition: String, Codable, Sendable {
    case unread
    case seenPending
    case snoozed
    case userHandled
}

public enum SourceEvidenceClass: String, Codable, Sendable {
    case fixture
    case initialReconcile
    case liveVerifiedTransition
}

public enum SourceAdapterKind: String, Codable, Sendable {
    case controlledFixture
    case codexAppServer
}

public enum DigestValidationError: Error, Equatable, Sendable {
    case invalidLength
}

public struct Digest32: Codable, Equatable, Hashable, Sendable {
    public let bytes: Data

    public init(bytes: Data) throws {
        guard bytes.count == 32 else { throw DigestValidationError.invalidLength }
        self.bytes = bytes
    }

    public init(repeating byte: UInt8) {
        self.bytes = Data(repeating: byte, count: 32)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(bytes: container.decode(Data.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(bytes)
    }
}

public struct EventSourceIdentity: Codable, Equatable, Hashable, Sendable {
    public var adapterKind: SourceAdapterKind
    public var sourceScopeID: UUID
    public var sourceObjectDigest: Digest32
    public var resolutionCycleDigest: Digest32
    public var schemaRevision: UInt32

    public init(
        adapterKind: SourceAdapterKind,
        sourceScopeID: UUID,
        sourceObjectDigest: Digest32,
        resolutionCycleDigest: Digest32,
        schemaRevision: UInt32
    ) {
        self.adapterKind = adapterKind
        self.sourceScopeID = sourceScopeID
        self.sourceObjectDigest = sourceObjectDigest
        self.resolutionCycleDigest = resolutionCycleDigest
        self.schemaRevision = schemaRevision
    }
}

public struct ActiveDeliveryGrant: Codable, Equatable, Hashable, Sendable {
    public var adapterKind: SourceAdapterKind
    public var sourceScopeID: UUID
    public var allowedEventTypes: Set<WorkEventType>
    public var validUntil: Date

    public init(
        adapterKind: SourceAdapterKind,
        sourceScopeID: UUID,
        allowedEventTypes: Set<WorkEventType>,
        validUntil: Date
    ) {
        self.adapterKind = adapterKind
        self.sourceScopeID = sourceScopeID
        self.allowedEventTypes = allowedEventTypes
        self.validUntil = validUntil
    }

    public func authorizes(source: EventSourceIdentity, type: WorkEventType, at date: Date) -> Bool {
        adapterKind == source.adapterKind
            && sourceScopeID == source.sourceScopeID
            && allowedEventTypes.contains(type)
            && date <= validUntil
    }
}

public struct SourceCapabilityRegistry: Codable, Equatable, Sendable {
    public var revision: UInt64
    public var activeDeliveryGrants: Set<ActiveDeliveryGrant>

    public init(
        revision: UInt64 = 0,
        activeDeliveryGrants: Set<ActiveDeliveryGrant> = []
    ) {
        self.revision = revision
        self.activeDeliveryGrants = activeDeliveryGrants
    }

    public func authorizesActiveDelivery(source: EventSourceIdentity, type: WorkEventType, at date: Date) -> Bool {
        activeDeliveryGrants.contains { $0.authorizes(source: source, type: type, at: date) }
    }
}

public struct EventObservation: Equatable, Sendable {
    public var eventID: UUID?
    public var source: EventSourceIdentity
    public var transitionDigest: Digest32
    public var type: WorkEventType
    public var observedAt: Date
    public var freshness: DataFreshness
    public var evidenceClass: SourceEvidenceClass

    public init(
        eventID: UUID? = nil,
        source: EventSourceIdentity,
        transitionDigest: Digest32,
        type: WorkEventType,
        observedAt: Date,
        freshness: DataFreshness,
        evidenceClass: SourceEvidenceClass = .fixture
    ) {
        self.eventID = eventID
        self.source = source
        self.transitionDigest = transitionDigest
        self.type = type
        self.observedAt = observedAt
        self.freshness = freshness
        self.evidenceClass = evidenceClass
    }
}

public struct WorkEventRecord: Codable, Equatable, Identifiable, Sendable {
    public private(set) var id: UUID
    public private(set) var source: EventSourceIdentity
    public private(set) var type: WorkEventType
    public private(set) var firstObservedAt: Date
    public private(set) var lastObservedAt: Date
    public private(set) var freshness: DataFreshness
    public private(set) var evidenceClass: SourceEvidenceClass
    public private(set) var resolution: EventResolutionState
    public private(set) var userDisposition: EventUserDisposition
    public private(set) var snoozedUntil: Date?
    public private(set) var activeOwner: DeliverySurface?
    public private(set) var presentationCount: Int
    public private(set) var lastPresentedAt: Date?
    public private(set) var openRequestCount: Int
    public private(set) var lastOpenRequestedAt: Date?
    public private(set) var acknowledgedAt: Date?
    public private(set) var resolvedAt: Date?
    public private(set) var resolutionKind: EventResolutionKind?
    public private(set) var invalidatedAt: Date?
    public private(set) var invalidationReason: EventInvalidationReason?

    fileprivate init(observation: EventObservation) {
        self.id = observation.eventID ?? UUID()
        self.source = observation.source
        self.type = observation.type
        self.firstObservedAt = observation.observedAt
        self.lastObservedAt = observation.observedAt
        self.freshness = observation.freshness
        self.evidenceClass = observation.evidenceClass
        self.resolution = .active
        self.userDisposition = .unread
        self.snoozedUntil = nil
        self.activeOwner = nil
        self.presentationCount = 0
        self.lastPresentedAt = nil
        self.openRequestCount = 0
        self.lastOpenRequestedAt = nil
        self.acknowledgedAt = nil
        self.resolvedAt = nil
        self.resolutionKind = nil
        self.invalidatedAt = nil
        self.invalidationReason = nil
    }

    public var isTerminal: Bool { resolution == .resolved || resolution == .invalidated }

    public func effectiveUserDisposition(at date: Date) -> EventUserDisposition {
        guard userDisposition == .snoozed, let snoozedUntil, date >= snoozedUntil else {
            return userDisposition
        }
        return .seenPending
    }

    public func isVisibleInNeedsYou(at date: Date) -> Bool {
        guard !isTerminal else { return false }
        return switch effectiveUserDisposition(at: date) {
        case .unread, .seenPending: true
        case .snoozed, .userHandled: false
        }
    }

    public func isEligibleForActiveDelivery(at date: Date, registry: SourceCapabilityRegistry) -> Bool {
        let userStateAllowsDelivery = userDisposition == .unread
            || (userDisposition == .snoozed && snoozedUntil.map { date >= $0 } == true)
        guard resolution == .active,
              freshness == .fresh,
              evidenceClass == .liveVerifiedTransition,
              registry.authorizesActiveDelivery(source: source, type: type, at: date),
              userStateAllowsDelivery else { return false }
        return switch type {
        case .needsApproval, .needsInput, .workLossRiskFailure, .quotaPaused:
            true
        case .recoverableFailure, .longTaskCompleted, .quotaCritical, .sourceDisconnected:
            false
        }
    }

    fileprivate mutating func merge(_ observation: EventObservation) {
        lastObservedAt = max(lastObservedAt, observation.observedAt)
        guard observation.type == type, observation.evidenceClass == evidenceClass else {
            freshness = .sourceConflict
            activeOwner = nil
            return
        }
        freshness = observation.freshness
        if freshness != .fresh { activeOwner = nil }
    }

    fileprivate mutating func claim(_ surface: DeliverySurface, at date: Date, registry: SourceCapabilityRegistry) -> Bool {
        guard surface == .overlayAlert || surface == .notification,
              isEligibleForActiveDelivery(at: date, registry: registry),
              activeOwner == nil else { return false }
        activeOwner = surface
        return true
    }

    fileprivate mutating func transfer(from: DeliverySurface, to: DeliverySurface, at date: Date, registry: SourceCapabilityRegistry) -> Bool {
        guard (from == .overlayAlert || from == .notification),
              (to == .overlayAlert || to == .notification),
              isEligibleForActiveDelivery(at: date, registry: registry),
              activeOwner == from,
              from != to else { return false }
        activeOwner = to
        return true
    }

    fileprivate mutating func release(owner surface: DeliverySurface) -> Bool {
        guard resolution == .active, activeOwner == surface else { return false }
        activeOwner = nil
        return true
    }

    fileprivate mutating func markPresented(on surface: DeliverySurface, at date: Date) -> Bool {
        guard resolution == .active, activeOwner == surface else { return false }
        if userDisposition == .snoozed, snoozedUntil.map({ date >= $0 }) == true {
            userDisposition = .seenPending
            snoozedUntil = nil
        }
        presentationCount += 1
        lastPresentedAt = max(lastPresentedAt ?? date, date)
        return true
    }

    fileprivate mutating func revokeOwnerIfUnauthorized(
        at date: Date,
        registry: SourceCapabilityRegistry
    ) -> DeliverySurface? {
        guard let owner = activeOwner,
              !registry.authorizesActiveDelivery(source: source, type: type, at: date) else {
            return nil
        }
        activeOwner = nil
        return owner
    }

    fileprivate mutating func markOpenRequested(at date: Date) -> Bool {
        guard !isTerminal else { return false }
        openRequestCount += 1
        lastOpenRequestedAt = max(lastOpenRequestedAt ?? date, date)
        return true
    }

    fileprivate mutating func markSeen(at date: Date) -> Bool {
        guard !isTerminal else { return false }
        var changed = false
        if userDisposition == .unread {
            userDisposition = .seenPending
            changed = true
        }
        if activeOwner != nil {
            activeOwner = nil
            changed = true
        }
        return changed
    }

    fileprivate mutating func snooze(at date: Date, until snoozeEnd: Date) -> Bool {
        guard !isTerminal, userDisposition != .userHandled, snoozeEnd > date else { return false }
        userDisposition = .snoozed
        snoozedUntil = snoozeEnd
        activeOwner = nil
        return true
    }

    fileprivate mutating func markUserHandled(at date: Date) -> Bool {
        guard !isTerminal, userDisposition != .userHandled else { return false }
        userDisposition = .userHandled
        snoozedUntil = nil
        activeOwner = nil
        if acknowledgedAt == nil { acknowledgedAt = date }
        resolvedAt = date
        resolution = .resolved
        resolutionKind = .userDisposition
        return true
    }

    fileprivate mutating func acknowledge(at date: Date) -> Bool {
        guard resolution == .active else { return false }
        resolution = .acknowledged
        acknowledgedAt = date
        if userDisposition == .unread { userDisposition = .seenPending }
        activeOwner = nil
        return true
    }

    fileprivate mutating func resolve(at date: Date, kind: EventResolutionKind) -> Bool {
        guard !isTerminal else { return false }
        resolution = .resolved
        resolvedAt = date
        resolutionKind = kind
        activeOwner = nil
        return true
    }

    fileprivate mutating func invalidate(at date: Date, reason: EventInvalidationReason) -> Bool {
        guard !isTerminal else { return false }
        resolution = .invalidated
        invalidatedAt = date
        invalidationReason = reason
        activeOwner = nil
        return true
    }
}

public enum EventObservationResult: Equatable, Sendable {
    case inserted(UUID)
    case updated(UUID)
    case duplicate(UUID)
    case outOfOrder(UUID)
    case identityCollision(UUID)
    case terminalIgnored(UUID)
}

public enum EventCallbackKind: String, Codable, Sendable {
    case openRequested
    case acknowledged
    case snoozed
    case userHandled
}

public struct EventCallback: Codable, Equatable, Sendable {
    public let id: UUID
    public let eventID: UUID
    public let kind: EventCallbackKind
    public let occurredAt: Date
    public let snoozedUntil: Date?

    public init(
        id: UUID,
        eventID: UUID,
        kind: EventCallbackKind,
        occurredAt: Date,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.kind = kind
        self.occurredAt = occurredAt
        self.snoozedUntil = snoozedUntil
    }
}

public enum EventCallbackInitialResult: String, Codable, Equatable, Sendable {
    case applied
    case rejected
}

public enum EventCallbackResult: Equatable, Sendable {
    case applied
    case rejected
    case duplicate(original: EventCallbackInitialResult)
    case identityCollision(original: EventCallbackInitialResult)
}

public struct EventCallbackReceipt: Codable, Equatable, Sendable {
    public let callback: EventCallback
    public let result: EventCallbackInitialResult

    public init(callback: EventCallback, result: EventCallbackInitialResult) {
        self.callback = callback
        self.result = result
    }
}

public enum DeliveryLedgerAction: String, Codable, Sendable {
    case observed
    case sourceUpdated
    case replayWithheld
    case ownerClaimed
    case ownerTransferred
    case ownerReleased
    case ownerRevoked
    case presented
    case openRequested
    case seen
    case acknowledged
    case snoozed
    case userHandled
    case sourceResolved
    case invalidated
    case callbackApplied
    case callbackRejected
    case callbackReplayWithheld
    case callbackIdentityCollision
}

public struct DeliveryAuditEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let eventID: UUID
    public let action: DeliveryLedgerAction
    public let surface: DeliverySurface?
    public let callbackID: UUID?
    public let occurredAt: Date

    public init(
        id: UUID = UUID(),
        eventID: UUID,
        action: DeliveryLedgerAction,
        surface: DeliverySurface? = nil,
        callbackID: UUID? = nil,
        occurredAt: Date
    ) {
        self.id = id
        self.eventID = eventID
        self.action = action
        self.surface = surface
        self.callbackID = callbackID
        self.occurredAt = occurredAt
    }
}

public struct EventLedger: Codable, Equatable, Sendable {
    private var recordsByID: [UUID: WorkEventRecord]
    private var idBySource: [EventSourceIdentity: UUID]
    private var transitionDigestsByEventID: [UUID: Set<Digest32>]
    private var capabilityRegistry: SourceCapabilityRegistry
    private var callbackReceiptsByID: [UUID: EventCallbackReceipt]
    public private(set) var auditEntries: [DeliveryAuditEntry]

    public init(capabilityRegistry: SourceCapabilityRegistry = SourceCapabilityRegistry()) {
        self.recordsByID = [:]
        self.idBySource = [:]
        self.transitionDigestsByEventID = [:]
        self.capabilityRegistry = capabilityRegistry
        self.callbackReceiptsByID = [:]
        self.auditEntries = []
    }

    public var records: [WorkEventRecord] {
        recordsByID.values.sorted {
            if $0.lastObservedAt != $1.lastObservedAt { return $0.lastObservedAt > $1.lastObservedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func record(id: UUID) -> WorkEventRecord? {
        recordsByID[id]
    }

    public var capabilityRegistryRevision: UInt64 {
        capabilityRegistry.revision
    }

    @discardableResult
    public mutating func replaceCapabilityRegistry(
        _ registry: SourceCapabilityRegistry,
        at date: Date = .now
    ) -> Bool {
        guard registry.revision > capabilityRegistry.revision else { return false }
        capabilityRegistry = registry
        _ = reconcileActiveOwners(at: date)
        return true
    }

    @discardableResult
    public mutating func reconcileActiveOwners(at date: Date = .now) -> Int {
        var revoked: [(UUID, DeliverySurface)] = []
        for (id, var record) in recordsByID {
            if let surface = record.revokeOwnerIfUnauthorized(at: date, registry: capabilityRegistry) {
                recordsByID[id] = record
                revoked.append((id, surface))
            }
        }
        for (id, surface) in revoked {
            appendAudit(eventID: id, action: .ownerRevoked, surface: surface, at: date)
        }
        return revoked.count
    }

    @discardableResult
    public mutating func observe(_ observation: EventObservation) -> EventObservationResult {
        if let requestedID = observation.eventID {
            if let mappedID = idBySource[observation.source], mappedID != requestedID {
                appendAudit(eventID: mappedID, action: .replayWithheld, at: observation.observedAt)
                return .identityCollision(mappedID)
            }
            if let existing = recordsByID[requestedID], existing.source != observation.source {
                appendAudit(eventID: requestedID, action: .replayWithheld, at: observation.observedAt)
                return .identityCollision(requestedID)
            }
            if recordsByID[requestedID]?.source == observation.source {
                idBySource[observation.source] = requestedID
            }
        }

        if let id = idBySource[observation.source], var record = recordsByID[id] {
            if record.isTerminal {
                appendAudit(eventID: id, action: .replayWithheld, at: observation.observedAt)
                return .terminalIgnored(id)
            }
            if transitionDigestsByEventID[id, default: []].contains(observation.transitionDigest) {
                appendAudit(eventID: id, action: .replayWithheld, at: observation.observedAt)
                return .duplicate(id)
            }
            if observation.observedAt < record.lastObservedAt {
                appendAudit(eventID: id, action: .replayWithheld, at: observation.observedAt)
                return .outOfOrder(id)
            }
            transitionDigestsByEventID[id, default: []].insert(observation.transitionDigest)
            record.merge(observation)
            recordsByID[id] = record
            appendAudit(eventID: id, action: .sourceUpdated, at: observation.observedAt)
            return .updated(id)
        }

        let record = WorkEventRecord(observation: observation)
        recordsByID[record.id] = record
        idBySource[observation.source] = record.id
        transitionDigestsByEventID[record.id] = [observation.transitionDigest]
        appendAudit(eventID: record.id, action: .observed, at: observation.observedAt)
        return .inserted(record.id)
    }

    @discardableResult
    public mutating func claimOwner(eventID: UUID, surface: DeliverySurface, at date: Date = .now) -> Bool {
        guard var record = recordsByID[eventID], record.claim(surface, at: date, registry: capabilityRegistry) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .ownerClaimed, surface: surface, at: date)
        return true
    }

    @discardableResult
    public mutating func transferOwner(eventID: UUID, from: DeliverySurface, to: DeliverySurface, at date: Date = .now) -> Bool {
        guard var record = recordsByID[eventID], record.transfer(from: from, to: to, at: date, registry: capabilityRegistry) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .ownerTransferred, surface: to, at: date)
        return true
    }

    @discardableResult
    public mutating func releaseOwner(eventID: UUID, surface: DeliverySurface, at date: Date = .now) -> Bool {
        guard var record = recordsByID[eventID], record.release(owner: surface) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .ownerReleased, surface: surface, at: date)
        return true
    }

    @discardableResult
    public mutating func markPresented(eventID: UUID, surface: DeliverySurface, at date: Date) -> Bool {
        guard var record = recordsByID[eventID], record.markPresented(on: surface, at: date) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .presented, surface: surface, at: date)
        return true
    }

    @discardableResult
    public mutating func markOpenRequested(eventID: UUID, at date: Date) -> Bool {
        guard var record = recordsByID[eventID], record.markOpenRequested(at: date) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .openRequested, at: date)
        return true
    }

    @discardableResult
    public mutating func markSeen(eventID: UUID, at date: Date = .now) -> Bool {
        guard var record = recordsByID[eventID], record.markSeen(at: date) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .seen, at: date)
        return true
    }

    @discardableResult
    public mutating func snooze(eventID: UUID, at date: Date = .now, until snoozeEnd: Date) -> Bool {
        guard var record = recordsByID[eventID], record.snooze(at: date, until: snoozeEnd) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .snoozed, at: date)
        return true
    }

    @discardableResult
    public mutating func markUserHandled(eventID: UUID, at date: Date = .now) -> Bool {
        guard var record = recordsByID[eventID], record.markUserHandled(at: date) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .userHandled, at: date)
        return true
    }

    @discardableResult
    public mutating func acknowledge(eventID: UUID, at date: Date) -> Bool {
        guard var record = recordsByID[eventID], record.acknowledge(at: date) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .acknowledged, at: date)
        return true
    }

    @discardableResult
    public mutating func resolve(eventID: UUID, at date: Date, kind: EventResolutionKind = .sourceConfirmed) -> Bool {
        guard var record = recordsByID[eventID], record.resolve(at: date, kind: kind) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .sourceResolved, at: date)
        return true
    }

    @discardableResult
    public mutating func invalidate(eventID: UUID, at date: Date, reason: EventInvalidationReason) -> Bool {
        guard var record = recordsByID[eventID], record.invalidate(at: date, reason: reason) else { return false }
        recordsByID[eventID] = record
        appendAudit(eventID: eventID, action: .invalidated, at: date)
        return true
    }

    @discardableResult
    public mutating func applyCallback(_ callback: EventCallback) -> EventCallbackResult {
        if let receipt = callbackReceiptsByID[callback.id] {
            let action: DeliveryLedgerAction
            let result: EventCallbackResult
            if receipt.callback == callback {
                action = .callbackReplayWithheld
                result = .duplicate(original: receipt.result)
            } else {
                action = .callbackIdentityCollision
                result = .identityCollision(original: receipt.result)
            }
            appendAudit(
                eventID: callback.eventID,
                action: action,
                callbackID: callback.id,
                at: callback.occurredAt
            )
            return result
        }

        let didApply: Bool
        switch callback.kind {
        case .openRequested:
            didApply = markOpenRequested(eventID: callback.eventID, at: callback.occurredAt)
        case .acknowledged:
            didApply = acknowledge(eventID: callback.eventID, at: callback.occurredAt)
        case .snoozed:
            if let snoozedUntil = callback.snoozedUntil, snoozedUntil > callback.occurredAt {
                didApply = snooze(eventID: callback.eventID, at: callback.occurredAt, until: snoozedUntil)
            } else {
                didApply = false
            }
        case .userHandled:
            didApply = markUserHandled(eventID: callback.eventID, at: callback.occurredAt)
        }

        let initialResult: EventCallbackInitialResult = didApply ? .applied : .rejected
        callbackReceiptsByID[callback.id] = EventCallbackReceipt(
            callback: callback,
            result: initialResult
        )
        appendAudit(
            eventID: callback.eventID,
            action: didApply ? .callbackApplied : .callbackRejected,
            callbackID: callback.id,
            at: callback.occurredAt
        )
        return didApply ? .applied : .rejected
    }

    private mutating func appendAudit(
        eventID: UUID,
        action: DeliveryLedgerAction,
        surface: DeliverySurface? = nil,
        callbackID: UUID? = nil,
        at date: Date
    ) {
        auditEntries.append(DeliveryAuditEntry(
            eventID: eventID,
            action: action,
            surface: surface,
            callbackID: callbackID,
            occurredAt: date
        ))
    }
}

public enum EventCTA {
    public static func label(for type: WorkEventType) -> String {
        switch type {
        case .needsApproval: "查看审批边界"
        case .needsInput: "查看输入边界"
        case .workLossRiskFailure: "查看恢复说明"
        case .quotaPaused: "查看额度说明"
        case .recoverableFailure: "查看诊断说明"
        case .longTaskCompleted: "查看结果说明"
        case .quotaCritical: "查看额度说明"
        case .sourceDisconnected: "查看连接说明"
        }
    }
}
