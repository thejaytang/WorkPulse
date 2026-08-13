import Foundation

public enum ThemePreference: String, Codable, CaseIterable, Sendable {
    case light
    case dark
    case system
}

public enum AccentPreference: String, Codable, CaseIterable, Sendable {
    case ocean
    case violet
    case mint
    case sunset
    case rose
}

public enum DataFreshness: String, Codable, Sendable {
    case fresh
    case cached
    case stale
    case offline
    case unsupported
    case notLoaded
    case sourceConflict
}

public enum RoutineRunState: String, Codable, Sendable {
    case manual
    case scheduled
    case running
    case needsReview
    case completed
    case failed
    case disconnected
}

public enum RoutineCapability: String, Codable, Sendable {
    case manualPin
    case verifiedAdapter
    case unavailable
}

public struct RoutineFieldSupport: Codable, Equatable, Sendable {
    public var lastRun: Bool
    public var nextRun: Bool
    public var attention: Bool

    public init(lastRun: Bool, nextRun: Bool, attention: Bool) {
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.attention = attention
    }

    public static let none = RoutineFieldSupport(lastRun: false, nextRun: false, attention: false)
    public static let all = RoutineFieldSupport(lastRun: true, nextRun: true, attention: true)
}

public enum PrivacyClass: String, Codable, Sendable {
    case generic
    case userApprovedTitle
}

public enum PresentationPrivacyPolicy {
    public static func exposesUserTitle(privacyMode: Bool, userOptIn: Bool) -> Bool {
        !privacyMode && userOptIn
    }
}

public enum HTTPSURLValidation: Equatable, Sendable {
    case empty
    case invalid
    case valid(URL)
}

public enum PinnedTargetURLPolicy {
    public static func validate(_ rawValue: String) -> HTTPSURLValidation {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return .invalid
        }
        return .valid(url)
    }
}

public enum QuotaProvenance: String, Codable, Sendable {
    case demo
    case deterministicFixture
    case liveCodexAppServer
    case unavailable
}

public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public var usedPercent: Double?
    public var windowDurationMinutes: Int?
    public var resetsAt: Date?
    public var sourceLabel: String
    public var provenance: QuotaProvenance
    public var generatedAt: Date
    public var freshUntil: Date?
    public var limitID: String?

    public init(
        usedPercent: Double?,
        windowDurationMinutes: Int?,
        resetsAt: Date?,
        sourceLabel: String,
        provenance: QuotaProvenance = .demo,
        generatedAt: Date,
        freshUntil: Date?,
        limitID: String? = nil
    ) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
        self.sourceLabel = sourceLabel
        self.provenance = provenance
        self.generatedAt = generatedAt
        self.freshUntil = freshUntil
        self.limitID = limitID
    }

    public var remainingPercent: Double? {
        usedPercent.map { max(0, min(100, 100 - $0)) }
    }

    public func freshness(at date: Date) -> DataFreshness {
        guard let freshUntil else { return .cached }
        return date <= freshUntil ? .fresh : .stale
    }
}

public enum QuotaExternalPolicy {
    public static func publishable(_ quota: QuotaSnapshot) -> QuotaSnapshot? {
        quota.provenance == .liveCodexAppServer ? quota : nil
    }
}

public enum WorkPulseRuntimeConfiguration {
    public static let legacyLocalAppGroup = "group.com.workpulse.prototype"

    public static func appGroupIdentifier(plistValue: String?) -> String {
        let candidate = plistValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !candidate.isEmpty, !candidate.contains("$(") else {
            return legacyLocalAppGroup
        }
        return candidate
    }

    public static func appGroupIdentifier(in bundle: Bundle = .main) -> String {
        appGroupIdentifier(
            plistValue: bundle.object(forInfoDictionaryKey: "WorkPulseAppGroupIdentifier") as? String
        )
    }
}

public struct NeedsYouSummary: Codable, Equatable, Sendable {
    public var count: Int
    public var observedAt: Date
    public var freshUntil: Date

    public init(count: Int, observedAt: Date, freshUntil: Date) {
        self.count = max(0, count)
        self.observedAt = observedAt
        self.freshUntil = freshUntil
    }

    public func freshness(at date: Date) -> DataFreshness {
        date <= freshUntil ? .fresh : .stale
    }
}

public struct RunningTaskSummary: Codable, Equatable, Sendable {
    public var count: Int
    public var observedAt: Date
    public var freshUntil: Date

    public init(count: Int, observedAt: Date, freshUntil: Date) {
        self.count = max(0, count)
        self.observedAt = observedAt
        self.freshUntil = freshUntil
    }

    public func freshness(at date: Date) -> DataFreshness {
        date <= freshUntil ? .fresh : .stale
    }
}

public struct PinnedRoutine: Codable, Equatable, Identifiable, Sendable {
    public private(set) var id: UUID
    public private(set) var displayTitle: String
    public private(set) var genericTitle: String
    public private(set) var targetURLString: String?
    public private(set) var lastRunAt: Date?
    public private(set) var nextRunAt: Date?
    public private(set) var attentionCount: Int
    public private(set) var state: RoutineRunState
    public private(set) var privacyClass: PrivacyClass
    public private(set) var capability: RoutineCapability
    public private(set) var sourceLabel: String?
    public private(set) var sourceObservedAt: Date?
    public private(set) var freshUntil: Date?
    public private(set) var fieldSupport: RoutineFieldSupport

    public init(
        id: UUID = UUID(),
        displayTitle: String,
        genericTitle: String = "每日例程",
        targetURLString: String? = nil,
        lastRunAt: Date?,
        nextRunAt: Date?,
        attentionCount: Int,
        state: RoutineRunState,
        privacyClass: PrivacyClass = .generic,
        capability: RoutineCapability = .manualPin,
        sourceLabel: String? = nil,
        sourceObservedAt: Date? = nil,
        freshUntil: Date? = nil,
        fieldSupport: RoutineFieldSupport = .none
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.genericTitle = genericTitle
        self.targetURLString = targetURLString
        self.privacyClass = privacyClass
        self.capability = capability
        self.sourceLabel = sourceLabel
        self.sourceObservedAt = sourceObservedAt
        self.freshUntil = freshUntil
        self.fieldSupport = capability == .verifiedAdapter ? fieldSupport : .none

        switch capability {
        case .manualPin:
            self.lastRunAt = nil
            self.nextRunAt = nil
            self.attentionCount = 0
            self.state = .manual
        case .verifiedAdapter:
            self.lastRunAt = fieldSupport.lastRun ? lastRunAt : nil
            self.nextRunAt = fieldSupport.nextRun ? nextRunAt : nil
            self.attentionCount = fieldSupport.attention ? max(0, attentionCount) : 0
            self.state = state
        case .unavailable:
            self.lastRunAt = lastRunAt
            self.nextRunAt = nil
            self.attentionCount = 0
            self.state = .disconnected
        }
    }

    public var targetURL: URL? {
        targetURLString.flatMap(URL.init(string:))
    }

    public func freshness(at date: Date) -> DataFreshness {
        switch capability {
        case .manualPin: return .unsupported
        case .unavailable: return .offline
        case .verifiedAdapter:
            guard let freshUntil else { return .cached }
            return date <= freshUntil ? .fresh : .stale
        }
    }
}

public enum WorkPulseRoute: Equatable, Sendable {
    case inbox
    case usage
    case notificationPreview
    case routine(UUID)
    case routineSetup
    case event(UUID)
    case task(String)
}

public enum DeepLinkRouter {
    public static func route(for url: URL) -> WorkPulseRoute? {
        guard url.scheme?.lowercased() == "workpulse" else { return nil }
        guard url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil,
              let destination = url.host?.lowercased() else { return nil }

        let segments = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        switch destination {
        case "inbox":
            return segments.isEmpty ? .inbox : nil
        case "usage":
            return segments.isEmpty ? .usage : nil
        case "notification-preview":
            return segments.isEmpty ? .notificationPreview : nil
        case "routine":
            if segments == ["setup"] { return .routineSetup }
            guard segments.count == 1, let id = UUID(uuidString: segments[0]) else { return nil }
            return .routine(id)
        case "event":
            guard segments.count == 1, let id = UUID(uuidString: segments[0]) else { return nil }
            return .event(id)
        case "task":
            guard segments.count == 1,
                  isSafeOpaqueIdentifier(segments[0]) else { return nil }
            return .task(segments[0])
        default:
            return nil
        }
    }

    private static func isSafeOpaqueIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 128 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0)
        }
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 6

    public var schemaVersion: Int
    public var revision: UInt64
    public var generatedAt: Date
    public var freshUntil: Date?
    public var privacyClass: PrivacyClass
    public var routineCapability: RoutineCapability
    public var routineSourceLabel: String
    public var routineObservedAt: Date?
    public var routineFreshness: DataFreshness
    public var routineID: UUID
    public var routineTitle: String
    public var hasValidPinnedTarget: Bool
    public var attentionCount: Int
    public var lastRunAt: Date?
    public var nextRunAt: Date?
    public var routineState: RoutineRunState
    public var quota: QuotaSnapshot?
    public var quotaBuckets: [QuotaSnapshot]
    public var runningTasks: RunningTaskSummary?
    public var needsYou: NeedsYouSummary?
    public var themePreference: ThemePreference
    public var accentPreference: AccentPreference

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        revision: UInt64 = 0,
        generatedAt: Date,
        freshUntil: Date?,
        privacyClass: PrivacyClass,
        routineCapability: RoutineCapability,
        routineSourceLabel: String,
        routineObservedAt: Date?,
        routineFreshness: DataFreshness,
        routineID: UUID,
        routineTitle: String,
        hasValidPinnedTarget: Bool,
        attentionCount: Int,
        lastRunAt: Date?,
        nextRunAt: Date?,
        routineState: RoutineRunState,
        quota: QuotaSnapshot?,
        quotaBuckets: [QuotaSnapshot] = [],
        runningTasks: RunningTaskSummary? = nil,
        needsYou: NeedsYouSummary? = nil,
        themePreference: ThemePreference = .system,
        accentPreference: AccentPreference = .ocean
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.generatedAt = generatedAt
        self.freshUntil = freshUntil
        self.privacyClass = privacyClass
        self.routineCapability = routineCapability
        self.routineSourceLabel = routineSourceLabel
        self.routineObservedAt = routineObservedAt
        self.routineFreshness = routineFreshness
        self.routineID = routineID
        self.routineTitle = routineTitle
        self.hasValidPinnedTarget = hasValidPinnedTarget
        self.attentionCount = max(0, attentionCount)
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.routineState = routineState
        self.quota = quota
        self.quotaBuckets = quotaBuckets
        self.runningTasks = runningTasks
        self.needsYou = needsYou
        self.themePreference = themePreference
        self.accentPreference = accentPreference
    }
}

public enum SnapshotFactory {
    public static func makeWidgetSnapshot(
        routine: PinnedRoutine,
        quota: QuotaSnapshot?,
        generatedAt: Date,
        freshUntil: Date?,
        revision: UInt64 = 0,
        needsYou: NeedsYouSummary? = nil,
        approvedRoutineTitle: String? = nil,
        hasValidPinnedTarget: Bool = false,
        quotaBuckets: [QuotaSnapshot] = [],
        runningTasks: RunningTaskSummary? = nil,
        themePreference: ThemePreference = .system,
        accentPreference: AccentPreference = .ocean
    ) -> WidgetSnapshot {
        let approvedTitle = approvedRoutineTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let exposesApprovedTitle = approvedTitle?.isEmpty == false
        return WidgetSnapshot(
            revision: revision,
            generatedAt: generatedAt,
            freshUntil: freshUntil,
            privacyClass: exposesApprovedTitle ? .userApprovedTitle : .generic,
            routineCapability: routine.capability,
            routineSourceLabel: routine.sourceLabel ?? (routine.capability == .manualPin ? "手动固定" : "来源不可用"),
            routineObservedAt: routine.sourceObservedAt,
            routineFreshness: routine.freshness(at: generatedAt),
            routineID: routine.id,
            routineTitle: exposesApprovedTitle ? (approvedTitle ?? routine.genericTitle) : routine.genericTitle,
            hasValidPinnedTarget: hasValidPinnedTarget,
            attentionCount: routine.attentionCount,
            lastRunAt: routine.lastRunAt,
            nextRunAt: routine.nextRunAt,
            routineState: routine.state,
            quota: quota,
            quotaBuckets: quotaBuckets,
            runningTasks: runningTasks,
            needsYou: needsYou,
            themePreference: themePreference,
            accentPreference: accentPreference
        )
    }
}
