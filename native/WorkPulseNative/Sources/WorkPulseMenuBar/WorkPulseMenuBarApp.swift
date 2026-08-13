import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications
import WidgetKit
import WorkPulseCore

struct NotificationOpenReceipt: Codable, Equatable {
    var requestIdentifier: String
    var actionIdentifier: String
    var route: String
    var result: String
    var openedAt: Date
}

private struct RecentTaskTerminalResult: Codable, Equatable {
    var taskID: String
    var displayName: String?
    var outcome: CodexTaskTerminalOutcome
    var durationLabel: String
    var observedAt: Date
}

enum QuotaConnectionState: Equatable {
    case demo
    case refreshing
    case live
    case unavailable
}

enum TaskMonitorConnectionState: Equatable {
    case loading
    case live
    case unavailable
}

extension AccentPreference {
    var workPulseColor: Color {
        switch self {
        case .ocean: Color(red: 0.36, green: 0.55, blue: 1.00)
        case .violet: Color(red: 0.61, green: 0.43, blue: 0.96)
        case .mint: Color(red: 0.16, green: 0.69, blue: 0.61)
        case .sunset: Color(red: 0.94, green: 0.48, blue: 0.24)
        case .rose: Color(red: 0.91, green: 0.32, blue: 0.54)
        }
    }

    var displayName: String {
        switch self {
        case .ocean: "海洋蓝"
        case .violet: "紫罗兰"
        case .mint: "薄荷青"
        case .sunset: "日落橙"
        case .rose: "玫瑰红"
        }
    }
}

@MainActor
final class WorkPulseModel: ObservableObject {
    private var hasCompletedInitialization = false

    @Published var theme: ThemePreference {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "workpulse.theme")
            guard hasCompletedInitialization else { return }
            updateNotchResident()
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var accentPreference: AccentPreference {
        didSet {
            UserDefaults.standard.set(accentPreference.rawValue, forKey: "workpulse.accent")
            guard hasCompletedInitialization else { return }
            updateNotchResident()
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var privacyMode: Bool {
        didSet {
            UserDefaults.standard.set(privacyMode, forKey: "workpulse.privacy")
            if privacyMode {
                temporaryTaskNameRevealTask?.cancel()
                temporarilyRevealsTaskNames = false
                scrubPersistedTaskNames()
            }
            guard hasCompletedInitialization else { return }
            updateNotchResident()
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var allowRoutineTitle: Bool {
        didSet {
            UserDefaults.standard.set(allowRoutineTitle, forKey: "workpulse.allowRoutineTitle")
            guard hasCompletedInitialization else { return }
            updateNotchResident()
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var routineDisplayTitle: String {
        didSet {
            UserDefaults.standard.set(routineDisplayTitle, forKey: "workpulse.routineDisplayTitle")
            guard hasCompletedInitialization else { return }
            updateNotchResident()
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var overlayEnabled: Bool {
        didSet {
            UserDefaults.standard.set(overlayEnabled, forKey: "workpulse.overlayEnabled")
            guard hasCompletedInitialization else { return }
            updateNotchResident()
        }
    }
    @Published var topAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(topAlertsEnabled, forKey: "workpulse.topAlertsEnabled") }
    }
    @Published var notificationFallbackEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationFallbackEnabled, forKey: "workpulse.notificationFallbackEnabled") }
    }
    @Published var showTaskNamesInNotch: Bool {
        didSet {
            UserDefaults.standard.set(showTaskNamesInNotch, forKey: "workpulse.showTaskNamesInNotch")
            if !showTaskNamesInNotch {
                scrubPersistedTaskNames()
            }
            guard hasCompletedInitialization else { return }
            updateNotchResident()
        }
    }
    @Published private(set) var launchAtLogin = false
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastNotificationOpenAt: Date?
    @Published private(set) var lastNotificationOpenReceipt: NotificationOpenReceipt?
    private var recentTaskTerminalResults: [String: RecentTaskTerminalResult] = [:]
    @Published var eventLedger = EventLedger()
    @Published var selectedEventID: UUID?
    @Published var eventFeedback: String?
    @Published private(set) var eventLedgerReady = true
    private var isRestoringEventLedger = false
    private var eventLedgerRevision: UInt64 = 0
    private let eventLedgerStore: EventLedgerStore
    @Published var eventDemoEnabled = false {
        didSet {
            guard !isRestoringEventLedger, eventLedgerReady else { return }
            if eventDemoEnabled {
                installEventFixtures()
            } else {
                eventLedger = EventLedger()
                selectedEventID = nil
                eventFeedback = nil
                persistEventLedger()
            }
        }
    }
    @Published var verifiedDemoEnabled = false {
        didSet { publishWidgetSnapshotIfAvailable() }
    }
    @Published var targetURLString: String {
        didSet {
            UserDefaults.standard.set(targetURLString, forKey: "workpulse.targetURL")
            feedback = nil
            updateNotchResident()
            guard hasCompletedInitialization else { return }
            publishWidgetSnapshotIfAvailable()
        }
    }
    @Published var feedback: String?
    @Published var quotaConnectionLabel = "演示数据"
    @Published var isRefreshingQuota = false
    @Published var rateLimitBuckets: [RateLimitBucketSnapshot] = []
    @Published var selectedQuotaLimitID: String? {
        didSet {
            if let selectedQuotaLimitID {
                UserDefaults.standard.set(selectedQuotaLimitID, forKey: "workpulse.selectedQuotaLimitID")
            } else {
                UserDefaults.standard.removeObject(forKey: "workpulse.selectedQuotaLimitID")
            }
        }
    }
    @Published var quotaAlertThreshold: Int {
        didSet {
            UserDefaults.standard.set(quotaAlertThreshold, forKey: "workpulse.quotaAlertThreshold")
        }
    }
    @Published private(set) var quotaConnectionState: QuotaConnectionState = .demo
    @Published private(set) var activeCodexTasks: [CodexRunningTaskSnapshot] = []
    @Published private(set) var taskMonitorConnectionState: TaskMonitorConnectionState = .loading
    @Published private(set) var taskMonitorLabel = "正在连接 Codex 任务"
    @Published private(set) var widgetSnapshotError: String?
    @Published private(set) var widgetSnapshotLastWrittenAt: Date?
    private var widgetSnapshotStore: SnapshotStore?
    private var widgetPublishTask: Task<Void, Never>?
    private var quotaRefreshLoop: Task<Void, Never>?
    private var hasCompletedInitialQuotaAttempt = false
    private var taskMonitorLoop: Task<Void, Never>?
    private var taskRefreshInFlight = false
    private var taskMonitorHasBaseline = false
    private var backgroundServicesStarted = false
    private var temporaryTaskNameRevealTask: Task<Void, Never>?
    @Published private(set) var temporarilyRevealsTaskNames = false
    private var quotaAlertedCycles: [String: String]
    private var quotaPreviousRemainingByCycle: [String: Double]

    let manualRoutine: PinnedRoutine
    let verifiedDemoRoutine: PinnedRoutine
    @Published var quota: QuotaSnapshot

    init() {
        self.eventLedgerStore = EventLedgerStore(fileURL: Self.defaultEventLedgerURL())
        let storedTheme = ThemePreference(
            rawValue: UserDefaults.standard.string(forKey: "workpulse.theme") ?? "system"
        ) ?? .light
        self.theme = storedTheme
        self.accentPreference = AccentPreference(
            rawValue: UserDefaults.standard.string(forKey: "workpulse.accent") ?? "ocean"
        ) ?? .ocean
        self.privacyMode = UserDefaults.standard.object(forKey: "workpulse.privacy") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "workpulse.privacy")
        self.allowRoutineTitle = UserDefaults.standard.bool(forKey: "workpulse.allowRoutineTitle")
        self.routineDisplayTitle = UserDefaults.standard.string(forKey: "workpulse.routineDisplayTitle") ?? "每日 Gmail 审查"
        self.targetURLString = UserDefaults.standard.string(forKey: "workpulse.targetURL") ?? ""
        self.overlayEnabled = UserDefaults.standard.object(forKey: "workpulse.overlayEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "workpulse.overlayEnabled")
        self.topAlertsEnabled = UserDefaults.standard.object(forKey: "workpulse.topAlertsEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "workpulse.topAlertsEnabled")
        self.notificationFallbackEnabled = UserDefaults.standard.object(forKey: "workpulse.notificationFallbackEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "workpulse.notificationFallbackEnabled")
        self.showTaskNamesInNotch = UserDefaults.standard.object(forKey: "workpulse.showTaskNamesInNotch") == nil
            ? false
            : UserDefaults.standard.bool(forKey: "workpulse.showTaskNamesInNotch")
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.lastNotificationOpenAt = UserDefaults.standard.object(
            forKey: "workpulse.lastNotificationOpenAt"
        ) as? Date
        self.lastNotificationOpenReceipt = UserDefaults.standard.data(
            forKey: "workpulse.lastNotificationOpenReceipt"
        ).flatMap { try? JSONDecoder().decode(NotificationOpenReceipt.self, from: $0) }
        self.recentTaskTerminalResults = UserDefaults.standard.data(
            forKey: "workpulse.recentTaskTerminalResults"
        ).flatMap { try? JSONDecoder().decode([String: RecentTaskTerminalResult].self, from: $0) } ?? [:]
        self.selectedQuotaLimitID = UserDefaults.standard.string(forKey: "workpulse.selectedQuotaLimitID")
        self.quotaAlertThreshold = UserDefaults.standard.object(forKey: "workpulse.quotaAlertThreshold") == nil
            ? 20
            : UserDefaults.standard.integer(forKey: "workpulse.quotaAlertThreshold")
        self.quotaAlertedCycles = UserDefaults.standard.dictionary(
            forKey: "workpulse.quotaAlertedCycles"
        ) as? [String: String] ?? [:]
        self.quotaPreviousRemainingByCycle = (UserDefaults.standard.dictionary(
            forKey: "workpulse.quotaPreviousRemainingByCycle"
        ) ?? [:]).reduce(into: [:]) { result, pair in
            if let value = pair.value as? NSNumber { result[pair.key] = value.doubleValue }
        }

        let now = Date()
        let routineID: UUID
        if let stored = UserDefaults.standard.string(forKey: "workpulse.routineID"),
           let parsed = UUID(uuidString: stored) {
            routineID = parsed
        } else {
            routineID = UUID()
            UserDefaults.standard.set(routineID.uuidString, forKey: "workpulse.routineID")
        }
        self.manualRoutine = PinnedRoutine(
            id: routineID,
            displayTitle: "每日 Gmail 审查",
            targetURLString: nil,
            lastRunAt: nil,
            nextRunAt: nil,
            attentionCount: 0,
            state: .manual,
            privacyClass: .userApprovedTitle,
            capability: .manualPin
        )
        self.verifiedDemoRoutine = PinnedRoutine(
            id: routineID,
            displayTitle: "每日 Gmail 审查",
            targetURLString: nil,
            lastRunAt: now.addingTimeInterval(-2 * 3_600),
            nextRunAt: now.addingTimeInterval(4 * 3_600),
            attentionCount: 3,
            state: .needsReview,
            privacyClass: .userApprovedTitle,
            capability: .verifiedAdapter,
            sourceLabel: "模拟数据",
            sourceObservedAt: now,
            freshUntil: now.addingTimeInterval(10 * 60),
            fieldSupport: .all
        )
        self.quota = QuotaSnapshot(
            usedPercent: 25,
            windowDurationMinutes: 300,
            resetsAt: Calendar.current.date(byAdding: .hour, value: 3, to: now),
            sourceLabel: "演示数据",
            provenance: .demo,
            generatedAt: now,
            freshUntil: Calendar.current.date(byAdding: .minute, value: 10, to: now)
        )

        if privacyMode || !showTaskNamesInNotch {
            scrubPersistedTaskNames()
        }

        #if DEBUG
        applyDebugScenario(environment: ProcessInfo.processInfo.environment, now: now)
        #endif

        if ProcessInfo.processInfo.environment["WORKPULSE_QA_EVENTS"] != "1" {
            eventLedgerReady = false
            restoreEventLedger()
        }

        NotificationCoordinator.shared.onStatusChange = { [weak self] status in
            self?.notificationAuthorizationStatus = status
        }
        NotificationCoordinator.shared.onOpenNotification = { [weak self] url, title, body, outcome, context in
            self?.handleNotificationOpen(
                url,
                title: title,
                body: body,
                outcome: outcome,
                responseContext: context
            )
        }
        NotificationCenter.default.addObserver(
            forName: .workPulseDeepLink,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let url = note.object as? URL else { return }
            Task { @MainActor in self?.handleDeepLink(url) }
        }
        NotificationCenter.default.addObserver(
            forName: .workPulseOpenPinned,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openRoutine() }
        }
        NotificationCenter.default.addObserver(
            forName: .workPulseRefreshQuota,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshLiveQuota() }
        }
        NotificationCenter.default.addObserver(
            forName: .workPulseNotchAction,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let action = note.object as? NotchExpandedAction else { return }
            Task { @MainActor in self?.handleNotchAction(action) }
        }
        hasCompletedInitialization = true
        Task { @MainActor in
            NotificationCoordinator.shared.refreshAuthorizationStatus()
            updateNotchResident()
            #if DEBUG
            if ProcessInfo.processInfo.environment["WORKPULSE_QA_DISPLAY_PLACEMENT"] == "1" {
                print("WorkPulse display placement: \(NotchOverlayController.shared.placementDiagnostic())")
            }
            if ProcessInfo.processInfo.environment["WORKPULSE_QA_DISPLAY_SEQUENCE"] == "1" {
                print("WorkPulse display resident: \(NotchOverlayController.shared.placementDiagnostic())")
                _ = NotchOverlayController.shared.showAlert(
                    title: notchResidentTitle,
                    detail: notchResidentDetail,
                    systemImage: notchResidentSystemImage,
                    tone: notchResidentTone
                )
                print("WorkPulse display alert: \(NotchOverlayController.shared.placementDiagnostic())")
                NotchOverlayController.shared.toggleExpanded()
                print("WorkPulse display expanded: \(NotchOverlayController.shared.placementDiagnostic())")
                NotchOverlayController.shared.dismissExpanded()
                if ProcessInfo.processInfo.environment["WORKPULSE_QA_EXIT_AFTER_SEQUENCE"] == "1" {
                    NSApp.terminate(nil)
                }
            }
            #endif
            startBackgroundServices()
        }
    }

    private static func defaultEventLedgerURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("WorkPulse", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    private func restoreEventLedger() {
        Task {
            do {
                guard let persisted = try await eventLedgerStore.read() else {
                    eventLedgerReady = true
                    return
                }
                isRestoringEventLedger = true
                eventLedger = persisted.ledger
                eventLedgerRevision = persisted.revision
                eventDemoEnabled = eventLedger.records.contains {
                    $0.source.adapterKind == .controlledFixture
                }
                selectedEventID = needsYouEvents.first?.id
                isRestoringEventLedger = false
                eventLedgerReady = true
            } catch {
                isRestoringEventLedger = false
                eventLedgerReady = true
                eventFeedback = "本地事件记录无法读取；已保持生产提醒关闭，请在诊断中检查存储版本。"
            }
        }
    }

    private func persistEventLedger() {
        guard eventLedgerReady else { return }
        eventLedgerRevision &+= 1
        let snapshot = eventLedger
        let revision = eventLedgerRevision
        Task {
            do {
                _ = try await eventLedgerStore.write(snapshot, revision: revision)
            } catch {
                eventFeedback = "本地事件记录暂时无法保存；重启后处置状态可能丢失。"
            }
        }
    }

    #if DEBUG
    private func applyDebugScenario(environment: [String: String], now: Date) {
        if let rawTheme = environment["WORKPULSE_QA_THEME"],
           let qaTheme = ThemePreference(rawValue: rawTheme) {
            theme = qaTheme
        }
        if let rawAccent = environment["WORKPULSE_QA_ACCENT"],
           let qaAccent = AccentPreference(rawValue: rawAccent) {
            accentPreference = qaAccent
        }
        if environment["WORKPULSE_QA_PRIVACY"] == "1" { privacyMode = true }
        if environment["WORKPULSE_QA_TITLE"] == "1" { allowRoutineTitle = true }
        if environment["WORKPULSE_QA_VERIFIED"] == "1" { verifiedDemoEnabled = true }
        if environment["WORKPULSE_QA_OVERLAY"] == "1" {
            overlayEnabled = true
            topAlertsEnabled = true
        }
        if environment["WORKPULSE_QA_EVENTS"] == "1" {
            eventDemoEnabled = true
        }
        if environment["WORKPULSE_QA_TASKS"] == "one" || environment["WORKPULSE_QA_TASKS"] == "completion" {
            activeCodexTasks = [CodexRunningTaskSnapshot(
                id: "qa-running-task",
                displayName: "完善 WorkPulse 刘海任务状态",
                startedAt: now.addingTimeInterval(-83),
                lastActivityAt: now
            )]
            taskMonitorConnectionState = .live
            taskMonitorLabel = "1 个 Codex 任务正在运行"
            taskMonitorHasBaseline = true
        }

        switch environment["WORKPULSE_QA_STATE"] {
        case "quota-two-bucket":
            let buckets = [
                RateLimitBucketSnapshot(
                    limitID: "codex",
                    displayName: "Codex",
                    usedPercent: 36,
                    windowDurationMinutes: 300,
                    resetsAt: now.addingTimeInterval(2 * 3_600)
                ),
                RateLimitBucketSnapshot(
                    limitID: "weekly",
                    displayName: "Weekly",
                    usedPercent: 12,
                    windowDurationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(5 * 86_400)
                )
            ]
            rateLimitBuckets = buckets
            selectedQuotaLimitID = "codex"
            quota = QuotaSnapshot(
                usedPercent: buckets[0].usedPercent,
                windowDurationMinutes: buckets[0].windowDurationMinutes,
                resetsAt: buckets[0].resetsAt,
                sourceLabel: "确定性 QA fixture",
                provenance: .deterministicFixture,
                generatedAt: now,
                freshUntil: now.addingTimeInterval(5 * 60),
                limitID: buckets[0].limitID
            )
            quotaConnectionLabel = "确定性 QA fixture · 非实时来源"
            quotaConnectionState = .demo
        case "quota-unavailable":
            rateLimitBuckets = []
            selectedQuotaLimitID = nil
            quota = QuotaSnapshot(
                usedPercent: nil,
                windowDurationMinutes: nil,
                resetsAt: nil,
                sourceLabel: "不可用",
                provenance: .unavailable,
                generatedAt: now,
                freshUntil: nil
            )
            quotaConnectionLabel = "不可用"
            quotaConnectionState = .unavailable
        default:
            break
        }
    }
    #endif

    var routine: PinnedRoutine {
        verifiedDemoEnabled ? verifiedDemoRoutine : manualRoutine
    }

    var resolvedColorScheme: ColorScheme? {
        switch theme {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    var visibleRoutineTitle: String {
        guard PresentationPrivacyPolicy.exposesUserTitle(
            privacyMode: privacyMode,
            userOptIn: allowRoutineTitle
        ) else { return routine.genericTitle }
        let title = routineDisplayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? routine.genericTitle : title
    }

    var canShowSensitivePresentation: Bool {
        PresentationPrivacyPolicy.exposesUserTitle(
            privacyMode: privacyMode,
            userOptIn: allowRoutineTitle
        )
    }

    var exposesTaskNames: Bool {
        PresentationPrivacyPolicy.exposesUserTitle(
            privacyMode: privacyMode,
            userOptIn: showTaskNamesInNotch
        )
    }

    var needsYouEvents: [WorkEventRecord] {
        eventLedger.records.filter { $0.isVisibleInNeedsYou(at: Date()) }
    }

    var selectedEvent: WorkEventRecord? {
        selectedEventID.flatMap(eventLedger.record(id:))
    }

    func selectEvent(_ id: UUID) {
        guard eventLedgerReady else {
            eventFeedback = "正在恢复本地提醒记录，请稍候。"
            return
        }
        guard eventLedger.record(id: id) != nil else {
            eventFeedback = "这条提醒已不存在或已被移除。"
            selectedEventID = nil
            return
        }
        if eventLedger.markSeen(eventID: id) { persistEventLedger() }
        selectedEventID = id
        eventFeedback = nil
    }

    func openNeedsYou() {
        guard eventLedgerReady else {
            eventFeedback = "正在恢复本地提醒记录，请稍候。"
            return
        }
        if selectedEventID == nil { selectedEventID = needsYouEvents.first?.id }
        if let id = selectedEventID, eventLedger.markSeen(eventID: id) {
            persistEventLedger()
        }
    }

    func requestEventAction(_ id: UUID) {
        guard eventLedgerReady else {
            eventFeedback = "正在恢复本地提醒记录，请稍候。"
            return
        }
        guard let event = eventLedger.record(id: id) else {
            eventFeedback = "这条提醒已不存在或已被处理。"
            return
        }
        guard eventLedger.markOpenRequested(eventID: id, at: Date()) else {
            eventFeedback = "这条提醒已不存在或已被处理。"
            return
        }
        persistEventLedger()
        eventFeedback = switch event.type {
        case .needsApproval: "审批边界：当前只能查看请求类别；模拟来源不能批准或拒绝。"
        case .needsInput: "输入边界：当前不会收集或提交真实输入。"
        case .workLossRiskFailure: "恢复边界：当前不会重试、回滚或修改文件。"
        case .quotaPaused, .quotaCritical: "额度边界：重置时间来自来源，但不等于任务已经恢复。"
        case .recoverableFailure: "诊断边界：当前只展示本地说明，不会自动重试。"
        case .longTaskCompleted: "结果边界：当前没有真实结果入口，打开请求不等于已阅读。"
        case .sourceDisconnected: "连接边界：断开不等于任务失败；请在来源恢复后确认。"
        }
    }

    func snoozeEvent(_ id: UUID) {
        guard eventLedgerReady else {
            eventFeedback = "正在恢复本地提醒记录，请稍候。"
            return
        }
        let now = Date()
        guard eventLedger.snooze(eventID: id, at: now, until: now.addingTimeInterval(3_600)) else { return }
        persistEventLedger()
        eventFeedback = "已稍后 1 小时；提醒仍未由来源确认解决。"
        selectedEventID = needsYouEvents.first?.id
    }

    func markEventUserHandled(_ id: UUID) {
        guard eventLedgerReady else {
            eventFeedback = "正在恢复本地提醒记录，请稍候。"
            return
        }
        guard eventLedger.markUserHandled(eventID: id, at: Date()) else { return }
        persistEventLedger()
        eventFeedback = "已从 WorkPulse 待处理列表移除；原任务状态未被 WorkPulse 改变。"
        selectedEventID = needsYouEvents.first?.id
    }

    private func installEventFixtures() {
        var ledger = EventLedger()
        let now = Date()
        let fixtureScopeID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let fixtures: [(String, WorkEventType, DataFreshness)] = [
            ("A1111111-1111-4111-8111-111111111111", .needsApproval, .fresh),
            ("B2222222-2222-4222-8222-222222222222", .needsInput, .fresh),
            ("C3333333-3333-4333-8333-333333333333", .workLossRiskFailure, .fresh),
            ("D4444444-4444-4444-8444-444444444444", .quotaPaused, .stale),
            ("E5555555-5555-4555-8555-555555555555", .sourceDisconnected, .offline),
            ("F6666666-6666-4666-8666-666666666666", .needsApproval, .sourceConflict)
        ]
        for (index, fixture) in fixtures.enumerated() {
            let id = UUID(uuidString: fixture.0)!
            _ = ledger.observe(EventObservation(
                eventID: id,
                source: EventSourceIdentity(
                    adapterKind: .controlledFixture,
                    sourceScopeID: fixtureScopeID,
                    sourceObjectDigest: Digest32(repeating: UInt8(index + 1)),
                    resolutionCycleDigest: Digest32(repeating: UInt8(index + 101)),
                    schemaRevision: 1
                ),
                transitionDigest: Digest32(repeating: UInt8(index + 201)),
                type: fixture.1,
                observedAt: now.addingTimeInterval(Double(-index * 120)),
                freshness: fixture.2
            ))
        }
        _ = ledger.markSeen(eventID: UUID(uuidString: fixtures[1].0)!, at: now)
        _ = ledger.snooze(
            eventID: UUID(uuidString: fixtures[2].0)!,
            at: now,
            until: now.addingTimeInterval(3_600)
        )
        eventLedger = ledger
        selectedEventID = needsYouEvents.first?.id
        eventFeedback = "模拟 Needs You · 非实时来源；不会发送系统通知或写入 Widget。"
        persistEventLedger()
    }

    var routineSystemImage: String {
        if privacyMode { return "lock.fill" }
        if !verifiedDemoEnabled { return "link" }
        return canShowSensitivePresentation ? "envelope" : "clock.arrow.circlepath"
    }

    var capabilityLabel: String {
        verifiedDemoEnabled ? "交互演示 · 未连接真实来源" : "手动固定 · 未同步状态"
    }

    var validTargetURL: URL? {
        guard case .valid(let url) = PinnedTargetURLPolicy.validate(targetURLString) else { return nil }
        return url
    }

    var targetURLValidationMessage: String? {
        guard case .invalid = PinnedTargetURLPolicy.validate(targetURLString) else { return nil }
        return "请输入以 https:// 开头的有效链接。"
    }

    var targetActionLabel: String {
        switch PinnedTargetURLPolicy.validate(targetURLString) {
        case .empty: "请先设置 HTTPS 链接"
        case .invalid: "链接格式无效"
        case .valid: "交给系统打开"
        }
    }

    var routineStatusColor: Color {
        verifiedDemoEnabled && routine.attentionCount > 0 ? .orange : .secondary
    }

    var routineStatusSystemImage: String {
        verifiedDemoEnabled && routine.attentionCount > 0 ? "exclamationmark.circle.fill" : "minus.circle"
    }

    var routineStatusAccessibilityLabel: String {
        verifiedDemoEnabled && routine.attentionCount > 0 ? "需要处理 \(routine.attentionCount) 项" : "手动未同步"
    }

    var quotaStatusColor: Color {
        switch quotaConnectionState {
        case .demo, .refreshing, .unavailable: .secondary
        case .live:
            quota.freshness(at: Date()) == .fresh ? .green : .orange
        }
    }

    var quotaStatusSystemImage: String {
        switch quotaConnectionState {
        case .demo: "circle.dashed"
        case .refreshing: "arrow.clockwise.circle"
        case .unavailable: "questionmark.circle"
        case .live: quota.freshness(at: Date()) == .fresh ? "checkmark.circle.fill" : "clock.badge.exclamationmark"
        }
    }

    var quotaStatusAccessibilityLabel: String {
        switch quotaConnectionState {
        case .demo: "额度演示数据，非实时"
        case .refreshing: "正在读取额度"
        case .unavailable: "额度不可用"
        case .live: quota.freshness(at: Date()) == .fresh ? "额度已更新" : "额度可能已过期"
        }
    }

    var quotaStateBadgeLabel: String {
        switch quotaConnectionState {
        case .demo: "演示 · 非实时"
        case .refreshing: "读取中"
        case .unavailable: "不可用"
        case .live: quota.freshness(at: Date()) == .fresh ? "已更新" : "可能已过期"
        }
    }

    var notificationStatusLabel: String {
        switch notificationAuthorizationStatus {
        case .notDetermined: "尚未请求"
        case .denied: "已关闭"
        case .authorized: "已允许"
        case .provisional: "临时允许"
        case .ephemeral: "本次允许"
        @unknown default: "未知"
        }
    }

    func requestNotificationAuthorization() {
        NotificationCoordinator.shared.requestAuthorization()
    }

    func sendNotificationPreview() {
        guard notificationAuthorizationStatus == .authorized || notificationAuthorizationStatus == .provisional else {
            feedback = notificationAuthorizationStatus == .denied
                ? "系统通知已关闭，请在系统设置中为 WorkPulse 开启通知。"
                : "请先允许系统通知。"
            return
        }
        Task {
            do {
                try await NotificationCoordinator.shared.schedulePreview(
                    id: "workpulse.manual-preview.\(UUID().uuidString)"
                )
                feedback = "已请求发送系统通知预览。"
            } catch {
                feedback = "系统通知预览失败：\(error.localizedDescription)"
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            feedback = launchAtLogin ? "WorkPulse 已设为登录时启动。" : "WorkPulse 不再随登录启动。"
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            feedback = "无法更新登录启动设置：\(error.localizedDescription)"
        }
    }

    func showCurrentStatusAlert() {
        configureNotchExpanded()
        NotchOverlayController.shared.showAlert(
            title: notchResidentTitle,
            detail: notchResidentDetail,
            systemImage: notchResidentSystemImage,
            tone: notchResidentTone
        )
    }

    /// The quota Widget and `workpulse://usage` route must always reveal quota,
    /// even while a running task currently owns the resident glance surface.
    func showQuotaStatusAlert() {
        configureQuotaExpanded()
        NotchOverlayController.shared.showAlert(
            title: notchQuotaTitle,
            detail: notchQuotaResetLabel,
            systemImage: quotaStatusSystemImage,
            tone: quotaNotchTone
        )
    }

    @discardableResult
    func showEventAlert(_ event: WorkEventRecord) -> Bool {
        let detail = NotchExpandedContent(
            title: "Needs You",
            primaryLabel: "提醒",
            primaryValue: EventPresentation.title(for: event.type),
            secondaryLabel: "状态",
            secondaryValue: EventPresentation.freshnessLabel(event.freshness),
            source: eventDemoEnabled ? "模拟 fixture · 非实时 · 不会触发生产通知" : "本机可信事件来源",
            primaryAction: .snoozeEvent(event.id),
            secondaryAction: .removeEvent(event.id)
        )
        return NotchOverlayController.shared.showAlert(
            title: EventPresentation.title(for: event.type),
            detail: "\(eventDemoEnabled ? "模拟 · 非实时 · " : "")\(EventPresentation.freshnessLabel(event.freshness))",
            systemImage: EventPresentation.icon(for: event.type),
            tone: eventDemoEnabled ? .neutral : EventPresentation.notchTone(for: event),
            expandedContent: detail
        )
    }

    func attemptActiveDelivery(for eventID: UUID) {
        guard !eventDemoEnabled,
              eventLedgerReady,
              let event = eventLedger.record(id: eventID) else { return }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() ?? ""
        let sourceIsFrontmost = frontmostBundleID.contains("openai")
            || frontmostBundleID.contains("chatgpt")
            || frontmostBundleID.contains("codex")
        let notificationsAuthorized = notificationFallbackEnabled
            && (notificationAuthorizationStatus == .authorized
                || notificationAuthorizationStatus == .provisional)
        let secondsSinceInput = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        )
        let context = DeliveryContext(
            sourceIsFrontmost: sourceIsFrontmost,
            overlayEnabled: topAlertsEnabled,
            overlayReachable: NotchOverlayController.shared.isReachable,
            notificationsAuthorized: notificationsAuthorized,
            userIsActive: secondsSinceInput < 60
        )
        let surfaces = DeliveryPolicy.surfaces(for: event.type, context: context)
        let now = Date()

        if surfaces.contains(.overlayAlert),
           eventLedger.claimOwner(eventID: eventID, surface: .overlayAlert, at: now) {
            persistEventLedger()
            if NotchOverlayController.shared.isReachable,
               showEventAlert(event) {
                if eventLedger.markPresented(eventID: eventID, surface: .overlayAlert, at: Date()) {
                    persistEventLedger()
                }
                return
            } else if eventLedger.releaseOwner(eventID: eventID, surface: .overlayAlert, at: Date()) {
                persistEventLedger()
            }
        }

        guard notificationsAuthorized,
              eventLedger.claimOwner(eventID: eventID, surface: .notification, at: now) else { return }
        persistEventLedger()
        Task {
            do {
                try await NotificationCoordinator.shared.scheduleEventAlert(eventID: eventID)
                eventFeedback = "系统已接收通知请求；是否展示由 macOS 通知设置决定。"
            } catch {
                if eventLedger.releaseOwner(eventID: eventID, surface: .notification, at: Date()) {
                    persistEventLedger()
                }
                eventFeedback = "系统通知调度失败；提醒保留在菜单栏 Needs You。"
            }
        }
    }

    func updateNotchResident() {
        NotchOverlayController.shared.setAppearance(
            theme: theme,
            accent: accentPreference
        )
        configureNotchExpanded()
        NotchOverlayController.shared.setResident(
            enabled: overlayEnabled,
            title: notchResidentTitle,
            detail: notchResidentDetail,
            systemImage: notchResidentSystemImage,
            tone: notchResidentTone
        )
    }

    private var notchResidentTitle: String {
        notchQuotaTitle
    }

    private var notchResidentDetail: String {
        guard !activeCodexTasks.isEmpty else { return notchQuotaResetLabel }
        return "\(notchQuotaResetLabel) · ● \(activeCodexTasks.count)"
    }

    private var notchResidentSystemImage: String {
        quotaStatusSystemImage
    }

    private var notchResidentTone: NotchSurfaceTone {
        quotaNotchTone
    }

    private var quotaNotchTone: NotchSurfaceTone {
        switch quotaConnectionState {
        case .demo, .refreshing, .unavailable: return .neutral
        case .live:
            guard quota.freshness(at: Date()) == .fresh,
                  let remaining = quota.remainingPercent else { return .warning }
            if remaining <= 10 { return .critical }
            if remaining <= 20 { return .warning }
            return .neutral
        }
    }

    private func configureNotchExpanded() {
        configureQuotaExpanded()
    }

    private func configureQuotaExpanded() {
        let currentRemaining = quota.remainingPercent.map { "\(Int($0.rounded()))% 剩余" } ?? "额度不可用"
        let additionalBuckets = rateLimitBuckets
            .filter { $0.limitID != quota.limitID }
            .prefix(3)
            .map { bucket in
                NotchExpandedRow(
                    label: compactWindowLabel(bucket.windowDurationMinutes),
                    value: "\(Int(bucket.remainingPercent.rounded()))% · \(formattedResetTime(bucket.resetsAt)) 重置",
                    systemImage: "gauge.with.dots.needle.50percent"
                )
            }
        let visibleTasks = Array(activeCodexTasks.prefix(4))
        let mayShowTaskNames = !privacyMode && (exposesTaskNames || temporarilyRevealsTaskNames)
        let taskRows = visibleTasks.enumerated().map { index, task in
            let label = "任务 \(String(UnicodeScalar(65 + index)!))"
            let value = mayShowTaskNames
                ? "\(compactTaskName(task.displayName, limit: 22)) · \(taskElapsedLabel(task))"
                : "\(task.startedAt.formatted(date: .omitted, time: .shortened)) 开始 · \(taskElapsedLabel(task))"
            return NotchExpandedRow(label: label, value: value, systemImage: "terminal.fill")
        }
        NotchOverlayController.shared.configureExpanded(NotchExpandedContent(
            title: "Codex 额度",
            primaryLabel: quotaWindowLabel,
            primaryValue: currentRemaining,
            secondaryLabel: "下次重置",
            secondaryValue: notchQuotaResetLabel,
            primarySystemImage: "gauge.with.dots.needle.50percent",
            secondarySystemImage: "clock",
            additionalRows: additionalBuckets + taskRows,
            source: "\(quotaConnectionLabel) · \(activeCodexTasks.isEmpty ? "无运行任务" : "\(activeCodexTasks.count) 个任务运行中")",
            primaryAction: .refreshQuota,
            secondaryAction: !privacyMode && !exposesTaskNames
                && !activeCodexTasks.isEmpty && !temporarilyRevealsTaskNames
                ? .revealTaskNames
                : nil
        ))
    }

    private func compactTaskName(_ value: String, limit: Int = 16) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > limit else { return cleaned.isEmpty ? "Codex 任务" : cleaned }
        return String(cleaned.prefix(limit)) + "…"
    }

    func taskElapsedLabel(_ task: CodexRunningTaskSnapshot, at date: Date = Date()) -> String {
        let seconds = Int(task.elapsed(at: date))
        if seconds < 10 { return "刚刚开始" }
        if seconds < 60 { return "运行 \(seconds) 秒" }
        let minutes = seconds / 60
        if minutes < 60 { return "运行 \(minutes) 分 \(seconds % 60) 秒" }
        return "运行 \(minutes / 60) 小时 \(minutes % 60) 分"
    }

    private func handleNotchAction(_ action: NotchExpandedAction) {
        switch action {
        case .refreshQuota:
            refreshLiveQuota()
        case .openPinned:
            openRoutine()
        case .revealTaskNames:
            revealTaskNamesTemporarily()
        case .snoozeEvent(let id):
            snoozeEvent(id)
            NotchOverlayController.shared.dismissExpanded()
        case .removeEvent(let id):
            markEventUserHandled(id)
            NotchOverlayController.shared.dismissExpanded()
        }
    }

    private func revealTaskNamesTemporarily() {
        guard !privacyMode else { return }
        temporaryTaskNameRevealTask?.cancel()
        temporarilyRevealsTaskNames = true
        configureNotchExpanded()
        temporaryTaskNameRevealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !Task.isCancelled else { return }
            temporarilyRevealsTaskNames = false
            configureNotchExpanded()
        }
    }

    var quotaSummary: String {
        guard quotaConnectionState != .unavailable, let remaining = quota.remainingPercent else {
            return "额度不可用"
        }
        let selected = selectedQuotaLimitID.flatMap { id in
            rateLimitBuckets.first(where: { $0.limitID == id })?.displayName ?? id
        }.map { " · 当前显示 \($0)" } ?? ""
        return "\(Int(remaining.rounded()))% 剩余 · 根据来源用量换算\(selected)"
    }

    private var notchQuotaSummary: String {
        guard let remaining = quota.remainingPercent, quotaConnectionState != .unavailable else {
            return "额度不可用 · 点击刷新"
        }
        return "\(Int(remaining.rounded()))% 剩余 · \(notchQuotaResetLabel)"
    }

    private var notchQuotaTitle: String {
        let sourceName = selectedQuotaDisplayName
        guard let remaining = quota.remainingPercent, quotaConnectionState != .unavailable else {
            return "\(sourceName) 额度不可用"
        }
        switch quotaConnectionState {
        case .demo: return "演示 \(Int(remaining.rounded()))% 剩余"
        case .refreshing: return "\(sourceName) 正在更新"
        case .live:
            guard quota.freshness(at: Date()) == .fresh else { return "\(sourceName) 额度需更新" }
            if rateLimitBuckets.count > 1, let minutes = quota.windowDurationMinutes {
                return "\(compactWindowLabel(minutes)) · \(Int(remaining.rounded()))% 剩余"
            }
            return "\(sourceName) \(Int(remaining.rounded()))% 剩余"
        case .unavailable: return "\(sourceName) 额度不可用"
        }
    }

    private var notchQuotaResetLabel: String {
        switch quotaConnectionState {
        case .demo:
            return "演示 · 非实时"
        case .refreshing:
            return "正在读取最新额度"
        case .unavailable:
            return "点击刷新"
        case .live:
            guard quota.freshness(at: Date()) == .fresh else {
                return "可能过期 · 点击刷新"
            }
            guard let reset = quota.resetsAt else { return "重置时间未知" }
            guard reset > Date() else { return "等待来源更新" }
            return "\(formattedResetTime(reset)) 重置"
        }
    }

    private var selectedQuotaDisplayName: String {
        guard let id = selectedQuotaLimitID else { return "Codex" }
        if let name = rateLimitBuckets.first(where: { $0.limitID == id })?.displayName,
           !name.isEmpty {
            return name
        }
        return id.lowercased() == "codex" ? "Codex" : id
    }

    private func formattedResetTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        if date.timeIntervalSinceNow < 7 * 86_400 {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func compactWindowLabel(_ minutes: Int) -> String {
        if minutes % 10_080 == 0 { return "\(minutes / 10_080 * 7) 天" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时" }
        return "\(minutes) 分钟"
    }

    func selectQuotaBucket(_ limitID: String) {
        guard let bucket = rateLimitBuckets.first(where: { $0.limitID == limitID }) else { return }
        selectedQuotaLimitID = bucket.limitID
        quota = QuotaSnapshot(
            usedPercent: bucket.usedPercent,
            windowDurationMinutes: bucket.windowDurationMinutes,
            resetsAt: bucket.resetsAt,
            sourceLabel: quota.sourceLabel,
            provenance: quota.provenance,
            generatedAt: quota.generatedAt,
            freshUntil: quota.freshUntil,
            limitID: bucket.limitID
        )
        updateNotchResident()
        publishWidgetSnapshotIfAvailable()
    }

    func startBackgroundServices() {
        guard !backgroundServicesStarted else { return }
        backgroundServicesStarted = true
        let environment = ProcessInfo.processInfo.environment

        if environment["WORKPULSE_QA_STATE"] == nil {
            refreshLiveQuota()
            quotaRefreshLoop = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(240))
                    guard !Task.isCancelled else { break }
                    self?.refreshLiveQuota()
                }
            }
        }

        if environment["WORKPULSE_QA_TASKS"] == nil {
            refreshRunningTasks()
            taskMonitorLoop = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    try? await Task.sleep(for: .seconds(taskMonitorPollingInterval()))
                    guard !Task.isCancelled else { break }
                    refreshRunningTasks()
                }
            }
        }

        if environment["WORKPULSE_QA_REQUEST_NOTIFICATIONS"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if notificationAuthorizationStatus == .notDetermined {
                    NotificationCoordinator.shared.requestAuthorization()
                }
            }
        }

        if environment["WORKPULSE_QA_NOTIFICATION_PREVIEW"] == "1" {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                NotificationCoordinator.shared.refreshAuthorizationStatus()
                try? await Task.sleep(for: .milliseconds(400))
                let status = notificationAuthorizationStatus
                print("WorkPulse notification QA authorization=\(status.rawValue)")
                func writeDiagnostic(_ diagnostic: NotificationCoordinator.DiagnosticSnapshot) {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    if let data = try? encoder.encode(diagnostic) {
                        try? data.write(
                            to: URL(fileURLWithPath: "/tmp/workpulse-notification-qa.json"),
                            options: .atomic
                        )
                    }
                }
                writeDiagnostic(await NotificationCoordinator.shared.diagnosticSnapshot())
                guard status == .authorized || status == .provisional else {
                    print("WorkPulse notification QA skipped: authorization unavailable")
                    return
                }
                do {
                    try await NotificationCoordinator.shared.schedulePreview(
                        id: "workpulse.qa-preview.\(UUID().uuidString)"
                    )
                    print("WorkPulse notification QA scheduled")
                } catch {
                    print("WorkPulse notification QA failed: \(error.localizedDescription)")
                }
                try? await Task.sleep(for: .seconds(1))
                writeDiagnostic(await NotificationCoordinator.shared.diagnosticSnapshot())
            }
        }
        if environment["WORKPULSE_QA_TASK_NOTIFICATION_PREVIEW"] == "1" {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                NotificationCoordinator.shared.refreshAuthorizationStatus()
                try? await Task.sleep(for: .milliseconds(400))
                let status = notificationAuthorizationStatus
                guard status == .authorized || status == .provisional else {
                    print("WorkPulse task notification QA skipped: authorization unavailable")
                    return
                }
                let taskID = "workpulse-qa-task-\(UUID().uuidString)"
                let observedAt = Date()
                recentTaskTerminalResults[taskID] = RecentTaskTerminalResult(
                    taskID: taskID,
                    displayName: nil,
                    outcome: .completed,
                    durationLabel: "运行 2 分钟",
                    observedAt: observedAt
                )
                persistRecentTaskTerminalResults()
                do {
                    try await NotificationCoordinator.shared.scheduleTaskTerminalAlert(
                        id: "qa.\(UUID().uuidString)",
                        taskID: taskID,
                        detail: "运行 2 分钟。打开 WorkPulse 查看这条任务结果。",
                        outcome: .completed
                    )
                    print("WorkPulse task notification QA scheduled taskID=\(taskID)")
                } catch {
                    print("WorkPulse task notification QA failed: \(error.localizedDescription)")
                }
                try? await Task.sleep(for: .seconds(1))
                let diagnostic = await NotificationCoordinator.shared.diagnosticSnapshot()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(diagnostic) {
                    try? data.write(
                        to: URL(fileURLWithPath: "/tmp/workpulse-task-notification-qa.json"),
                        options: .atomic
                    )
                }
            }
        }
        #if DEBUG
        if environment["WORKPULSE_QA_TASKS"] == "completion",
           let fixture = activeCodexTasks.first {
            taskMonitorLoop = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                activeCodexTasks = []
                taskMonitorLabel = "未发现正在运行的 Codex 任务"
                updateNotchResident()
                showTaskTerminalAlert(fixture, outcome: .completed)
            }
        }
        #endif

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLiveQuota()
                self?.refreshRunningTasks()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshRunningTasks() }
        }
    }

    private func taskMonitorPollingInterval() -> TimeInterval {
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
           session["CGSSessionScreenIsLocked"] as? Bool == true {
            return 120
        }
        let secondsSinceInput = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        )
        if secondsSinceInput >= 5 * 60 { return activeCodexTasks.isEmpty ? 60 : 30 }
        return activeCodexTasks.isEmpty ? 10 : 5
    }

    func refreshRunningTasks() {
        guard !taskRefreshInFlight else { return }
        taskRefreshInFlight = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let tasks = try await Task.detached(priority: .utility) {
                    try CodexRunningTaskReader.read()
                }.value
                let previousTasks = activeCodexTasks
                let previousTaskCount = previousTasks.count
                let previousTaskState = taskMonitorConnectionState
                activeCodexTasks = tasks
                taskMonitorConnectionState = .live
                taskMonitorLabel = tasks.isEmpty
                    ? "未发现正在运行的 Codex 任务"
                    : "\(tasks.count) 个 Codex 任务正在运行"

                var terminalTasks: [(CodexRunningTaskSnapshot, CodexTaskTerminalOutcome)] = []
                if taskMonitorHasBaseline {
                    let currentIDs = Set(tasks.map(\.id))
                    for disappeared in previousTasks where !currentIDs.contains(disappeared.id) {
                        if let outcome = CodexRunningTaskReader.terminalOutcome(for: disappeared) {
                            terminalTasks.append((disappeared, outcome))
                        }
                    }
                } else {
                    taskMonitorHasBaseline = true
                }
                updateNotchResident()
                // Widget surfaces expose only task availability and count. A rollout
                // file mtime can change lastActivityAt every poll without changing
                // anything visible in a Widget, so do not spend WidgetKit reload
                // budget on those host-only timestamp updates.
                if previousTaskCount != tasks.count || previousTaskState != .live {
                    publishWidgetSnapshotIfAvailable()
                }
                showTaskTerminalAlerts(terminalTasks)
            } catch {
                let hadTasks = !activeCodexTasks.isEmpty
                let previousTaskState = taskMonitorConnectionState
                activeCodexTasks = []
                taskMonitorConnectionState = .unavailable
                taskMonitorLabel = "Codex 任务状态暂不可用"
                updateNotchResident()
                if hadTasks || previousTaskState != .unavailable {
                    publishWidgetSnapshotIfAvailable()
                }
            }
            taskRefreshInFlight = false
        }
    }

    private func showTaskTerminalAlert(
        _ task: CodexRunningTaskSnapshot,
        outcome: CodexTaskTerminalOutcome,
        forceNotification: Bool = false
    ) {
        recordTaskTerminalResult(task, outcome: outcome)
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() ?? ""
        let sourceIsFrontmost = frontmostBundleID.contains("openai")
            || frontmostBundleID.contains("chatgpt")
            || frontmostBundleID.contains("codex")
        let notificationsAuthorized = notificationFallbackEnabled
            && (notificationAuthorizationStatus == .authorized
                || notificationAuthorizationStatus == .provisional)
        let secondsSinceInput = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        )
        let context = DeliveryContext(
            sourceIsFrontmost: sourceIsFrontmost,
            overlayEnabled: topAlertsEnabled,
            overlayReachable: NotchOverlayController.shared.isReachable,
            notificationsAuthorized: notificationsAuthorized,
            userIsActive: secondsSinceInput < 60
        )
        let surfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: context)
        let taskName = exposesTaskNames ? compactTaskName(task.displayName, limit: 22) : "Codex 任务"
        let presentation = switch outcome {
        case .completed: ("\(taskName) 已完成", "checkmark.circle.fill", NotchSurfaceTone.success)
        case .cancelled: ("\(taskName) 已取消", "xmark.circle.fill", NotchSurfaceTone.neutral)
        case .failed: ("\(taskName) 运行失败", "exclamationmark.triangle.fill", NotchSurfaceTone.critical)
        case .aborted: ("\(taskName) 已中止", "stop.circle.fill", NotchSurfaceTone.warning)
        }
        let title = presentation.0
        let detail = taskElapsedLabel(task, at: task.lastActivityAt)
        let expandedContent = NotchExpandedContent(
            title: "Codex 任务结果",
            primaryLabel: "任务",
            primaryValue: exposesTaskNames ? taskName : "名称已隐藏",
            secondaryLabel: "结果",
            secondaryValue: taskOutcomeLabel(outcome),
            primarySystemImage: "terminal.fill",
            secondarySystemImage: presentation.1,
            additionalRows: [
                NotchExpandedRow(
                    label: "运行时长",
                    value: detail,
                    systemImage: "clock"
                )
            ],
            source: "本机明确生命周期事件 · 不读取对话正文"
        )

        if !forceNotification, surfaces.contains(.overlayAlert),
           NotchOverlayController.shared.showAlert(
               title: title,
               detail: detail,
               systemImage: presentation.1,
               tone: presentation.2,
               expandedContent: expandedContent
           ) {
            return
        }

        guard notificationsAuthorized,
              forceNotification || surfaces.contains(.notification) || surfaces.contains(.overlayAlert) else { return }
        let requestID = "\(task.id).\(Int(task.lastActivityAt.timeIntervalSince1970))"
        Task {
            do {
                try await NotificationCoordinator.shared.scheduleTaskTerminalAlert(
                    id: requestID,
                    taskID: task.id,
                    detail: "\(detail)。打开 WorkPulse 查看这条任务结果。",
                    outcome: outcome
                )
                feedback = "系统已接收任务状态通知请求。"
            } catch {
                feedback = "任务状态通知调度失败：\(error.localizedDescription)"
            }
        }
    }

    private func showTaskTerminalAlerts(
        _ tasks: [(CodexRunningTaskSnapshot, CodexTaskTerminalOutcome)]
    ) {
        guard !tasks.isEmpty else { return }
        for (task, outcome) in tasks {
            recordTaskTerminalResult(task, outcome: outcome)
        }
        guard tasks.count > 1 else {
            showTaskTerminalAlert(tasks[0].0, outcome: tasks[0].1)
            return
        }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() ?? ""
        let sourceIsFrontmost = frontmostBundleID.contains("openai")
            || frontmostBundleID.contains("chatgpt")
            || frontmostBundleID.contains("codex")
        let context = DeliveryContext(
            sourceIsFrontmost: sourceIsFrontmost,
            overlayEnabled: topAlertsEnabled,
            overlayReachable: NotchOverlayController.shared.isReachable,
            notificationsAuthorized: notificationFallbackEnabled
                && (notificationAuthorizationStatus == .authorized
                    || notificationAuthorizationStatus == .provisional),
            userIsActive: CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: .null
            ) < 60
        )
        let surfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: context)
        if surfaces.contains(.overlayAlert) {
            let rows = tasks.prefix(4).enumerated().map { index, item in
                let label = "任务 \(String(UnicodeScalar(65 + index)!))"
                let name = exposesTaskNames ? compactTaskName(item.0.displayName, limit: 18) : "名称已隐藏"
                return NotchExpandedRow(
                    label: label,
                    value: "\(name) · \(taskOutcomeLabel(item.1))",
                    systemImage: taskOutcomeSystemImage(item.1)
                )
            }
            let detail = tasks.prefix(2).enumerated().map { index, item in
                "任务 \(String(UnicodeScalar(65 + index)!))\(taskOutcomeLabel(item.1))"
            }.joined(separator: " · ")
            if NotchOverlayController.shared.showAlert(
                title: "\(tasks.count) 个 Codex 任务已更新",
                detail: detail,
                systemImage: "checkmark.circle.badge.questionmark",
                tone: .neutral,
                expandedContent: NotchExpandedContent(
                    title: "Codex 任务结果",
                    primaryLabel: "本轮更新",
                    primaryValue: "\(tasks.count) 个任务",
                    secondaryLabel: "隐私",
                    secondaryValue: privacyMode ? "名称已隐藏" : "按当前偏好显示",
                    primarySystemImage: "terminal.fill",
                    secondarySystemImage: privacyMode ? "lock.fill" : "eye.fill",
                    additionalRows: rows,
                    source: "本机明确生命周期事件 · 不读取对话正文"
                )
            ) {
                return
            }
        }

        guard context.notificationsAuthorized,
              surfaces.contains(.notification) || surfaces.contains(.overlayAlert) else { return }
        for task in tasks {
            showTaskTerminalAlert(task.0, outcome: task.1, forceNotification: true)
        }
    }

    private func recordTaskTerminalResult(
        _ task: CodexRunningTaskSnapshot,
        outcome: CodexTaskTerminalOutcome
    ) {
        let now = Date()
        recentTaskTerminalResults = recentTaskTerminalResults.filter {
            now.timeIntervalSince($0.value.observedAt) < 7 * 24 * 60 * 60
        }
        recentTaskTerminalResults[task.id] = RecentTaskTerminalResult(
            taskID: task.id,
            displayName: exposesTaskNames ? compactTaskName(task.displayName, limit: 48) : nil,
            outcome: outcome,
            durationLabel: taskElapsedLabel(task, at: task.lastActivityAt),
            observedAt: now
        )
        if recentTaskTerminalResults.count > 20 {
            let keep = recentTaskTerminalResults.values
                .sorted { $0.observedAt > $1.observedAt }
                .prefix(20)
            recentTaskTerminalResults = Dictionary(uniqueKeysWithValues: keep.map { ($0.taskID, $0) })
        }
        persistRecentTaskTerminalResults()
    }

    private func scrubPersistedTaskNames() {
        guard recentTaskTerminalResults.values.contains(where: { $0.displayName != nil }) else { return }
        recentTaskTerminalResults = recentTaskTerminalResults.mapValues { result in
            RecentTaskTerminalResult(
                taskID: result.taskID,
                displayName: nil,
                outcome: result.outcome,
                durationLabel: result.durationLabel,
                observedAt: result.observedAt
            )
        }
        persistRecentTaskTerminalResults()
    }

    private func persistRecentTaskTerminalResults() {
        if let data = try? JSONEncoder().encode(recentTaskTerminalResults) {
            UserDefaults.standard.set(data, forKey: "workpulse.recentTaskTerminalResults")
        }
    }

    var quotaWindowLabel: String {
        guard let minutes = quota.windowDurationMinutes else { return "Codex 额度" }
        if minutes % 10_080 == 0 { return "Codex \(minutes / 10_080 * 7) 天窗口" }
        if minutes % 1_440 == 0 { return "Codex \(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "Codex \(minutes / 60) 小时窗口" }
        return "Codex \(minutes) 分钟窗口"
    }

    func openRoutine() {
        guard let url = validTargetURL else { return }
        feedback = "已发送打开请求；WorkPulse 尚未确认是否到达对应对话。"
        NSWorkspace.shared.open(url)
    }

    func removeLocalRoutine() {
        targetURLString = ""
        routineDisplayTitle = ""
        allowRoutineTitle = false
        feedback = "已移除 WorkPulse 本地入口；没有删除 ChatGPT 内容或 Scheduled task。"
        publishWidgetSnapshotIfAvailable()
    }

    func handleDeepLink(_ url: URL) {
        guard let route = DeepLinkRouter.route(for: url) else {
            feedback = "这个 WorkPulse 链接无效或不受支持。"
            return
        }
        switch route {
        case .inbox:
            openNeedsYou()
            if let event = selectedEvent { showEventAlert(event) }
            else {
                NotchOverlayController.shared.showAlert(
                    title: "Needs You",
                    detail: eventDemoEnabled ? "暂无模拟事件" : "尚未连接可信事件来源",
                    systemImage: "tray"
                )
            }
            feedback = "已在顶部状态层显示 Needs You。"
        case .usage:
            showQuotaStatusAlert()
            feedback = "已在顶部状态层显示 Codex 额度；数值以当前来源和 freshness 为准。"
        case .notificationPreview:
            feedback = "通知预览链接已打开；只有 macOS 通知回调会被记录为点击回流。"
            NotchOverlayController.shared.showAlert(
                title: "WorkPulse 通知预览",
                detail: "请从 macOS 通知中心点按预览以完成回流验收",
                systemImage: "bell"
            )
        case .routine(let id):
            guard id == routine.id else {
                feedback = "这个固定例程链接已过期或不属于本机配置。"
                return
            }
            if validTargetURL != nil {
                openRoutine()
            } else {
                feedback = "请从菜单栏打开 WorkPulse，并设置有效的 HTTPS 对话链接。"
                NotchOverlayController.shared.showAlert(
                    title: "固定入口尚未设置",
                    detail: "请在菜单栏 WorkPulse 中填写 HTTPS 链接",
                    systemImage: "link.badge.plus"
                )
            }
        case .routineSetup:
            feedback = "请从右上角 WorkPulse 菜单打开控制中心，并在“固定入口”中填写 HTTPS 链接。"
            NotchOverlayController.shared.showAlert(
                title: "设置固定入口",
                detail: "打开右上角 WorkPulse → 控制 → 固定入口",
                systemImage: "link.badge.plus"
            )
        case .event(let id):
            guard eventLedger.record(id: id) != nil else {
                selectedEventID = nil
                eventFeedback = "这条提醒已不存在或已被移除。"
                feedback = eventFeedback
                return
            }
            selectEvent(id)
            if let event = selectedEvent { showEventAlert(event) }
            feedback = "已在顶部状态层显示本机事件；模拟事件不会触发真实通知。"
        case .task:
            showTaskNotificationReturn(
                title: "Codex 任务状态已更新",
                detail: "这条任务通知没有可恢复的具体结果；请查看 Codex 当前任务列表。",
                outcome: nil
            )
        }
    }

    private func handleNotificationOpen(
        _ url: URL,
        title: String,
        body: String,
        outcome: CodexTaskTerminalOutcome?,
        responseContext: NotificationCoordinator.ResponseContext
    ) {
        let now = Date()
        lastNotificationOpenAt = now
        UserDefaults.standard.set(now, forKey: "workpulse.lastNotificationOpenAt")
        let result: String
        guard let route = DeepLinkRouter.route(for: url) else {
            feedback = "系统通知已打开，但其中的 WorkPulse 链接无效。"
            persistNotificationOpenReceipt(
                context: responseContext,
                route: url,
                result: "invalid-route",
                openedAt: now
            )
            return
        }
        if case .task(let taskID) = route {
            let localResult = recentTaskTerminalResults[taskID]
            let resolvedOutcome = localResult?.outcome ?? outcome
            let resolvedTitle = localResult.map {
                taskOutcomeTitle(
                    taskName: exposesTaskNames ? ($0.displayName ?? "Codex 任务") : "Codex 任务",
                    outcome: resolvedOutcome
                )
            } ?? title
            showTaskNotificationReturn(
                title: resolvedTitle,
                detail: localResult?.durationLabel ?? body,
                outcome: resolvedOutcome,
                taskDisplayName: localResult?.displayName
            )
            result = "task-result"
        } else if route == .notificationPreview {
            showNotificationReturnAlert()
            result = "preview-return"
        } else {
            handleDeepLink(url)
            result = "deep-link"
        }
        persistNotificationOpenReceipt(
            context: responseContext,
            route: url,
            result: result,
            openedAt: now
        )
    }

    private func persistNotificationOpenReceipt(
        context: NotificationCoordinator.ResponseContext,
        route: URL,
        result: String,
        openedAt: Date
    ) {
        let receipt = NotificationOpenReceipt(
            requestIdentifier: context.requestIdentifier,
            actionIdentifier: context.actionIdentifier,
            route: route.absoluteString,
            result: result,
            openedAt: openedAt
        )
        lastNotificationOpenReceipt = receipt
        if let data = try? JSONEncoder().encode(receipt) {
            UserDefaults.standard.set(data, forKey: "workpulse.lastNotificationOpenReceipt")
        }
    }

    private func showNotificationReturnAlert() {
        feedback = "已从 macOS 系统通知成功回到 WorkPulse。"
        NotchOverlayController.shared.showAlert(
            title: "通知回流成功",
            detail: "这次点击来自你手动触发的本机通知预览",
            systemImage: "checkmark.circle.fill",
            tone: .success,
            expandedContent: NotchExpandedContent(
                title: "系统通知",
                primaryLabel: "回流",
                primaryValue: "已到达 WorkPulse",
                secondaryLabel: "时间",
                secondaryValue: Date().formatted(date: .omitted, time: .standard),
                primarySystemImage: "bell.badge.fill",
                secondarySystemImage: "clock",
                source: "macOS UserNotifications 回调 · 本机预览"
            )
        )
    }

    private func showTaskNotificationReturn(
        title: String,
        detail: String,
        outcome: CodexTaskTerminalOutcome?,
        taskDisplayName: String? = nil
    ) {
        let mayExposeName = exposesTaskNames && taskDisplayName != nil
        let safeTitle = mayExposeName
            ? title
            : taskOutcomeTitle(taskName: "Codex 任务", outcome: outcome)
        let result = taskOutcomeLabel(outcome)
        let safeDetail = detail
            .replacingOccurrences(of: "。打开 WorkPulse 查看当前状态。", with: "")
            .replacingOccurrences(of: "打开 WorkPulse 查看当前状态。", with: "")
            .replacingOccurrences(of: "。打开 WorkPulse 查看这条任务结果。", with: "")
            .replacingOccurrences(of: "打开 WorkPulse 查看这条任务结果。", with: "")
        feedback = "已从系统通知打开这条 Codex 任务结果。"
        NotchOverlayController.shared.showAlert(
            title: safeTitle,
            detail: safeDetail,
            systemImage: taskOutcomeSystemImage(outcome),
            tone: taskOutcomeTone(outcome),
            expandedContent: NotchExpandedContent(
                title: "Codex 任务结果",
                primaryLabel: "任务",
                primaryValue: mayExposeName ? (taskDisplayName ?? "Codex 任务") : "任务名称已隐藏",
                secondaryLabel: "结果",
                secondaryValue: result,
                primarySystemImage: "terminal.fill",
                secondarySystemImage: taskOutcomeSystemImage(outcome),
                source: "来自 macOS 系统通知 · 不读取对话正文"
            )
        )
    }

    private func taskOutcomeTitle(
        taskName: String,
        outcome: CodexTaskTerminalOutcome?
    ) -> String {
        switch outcome {
        case .completed: "\(taskName) 已完成"
        case .cancelled: "\(taskName) 已取消"
        case .failed: "\(taskName) 运行失败"
        case .aborted: "\(taskName) 已中止"
        case nil: "\(taskName) 状态已更新"
        }
    }

    private func taskOutcomeLabel(_ outcome: CodexTaskTerminalOutcome?) -> String {
        switch outcome {
        case .completed: "已完成"
        case .cancelled: "已取消"
        case .failed: "运行失败"
        case .aborted: "已中止"
        case nil: "状态已更新"
        }
    }

    private func taskOutcomeSystemImage(_ outcome: CodexTaskTerminalOutcome?) -> String {
        switch outcome {
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .aborted: "stop.circle.fill"
        case nil: "info.circle.fill"
        }
    }

    private func taskOutcomeTone(_ outcome: CodexTaskTerminalOutcome?) -> NotchSurfaceTone {
        switch outcome {
        case .completed: .success
        case .cancelled, nil: .neutral
        case .failed: .critical
        case .aborted: .warning
        }
    }

    func refreshLiveQuota() {
        guard !isRefreshingQuota else { return }
        isRefreshingQuota = true
        quotaConnectionState = .refreshing
        feedback = nil

        Task {
            do {
                let buckets = try await Task.detached(priority: .userInitiated) {
                    try CodexRateLimitReader.read()
                }.value
                let preferredID = selectedQuotaLimitID
                guard let primary = preferredID.flatMap({ id in buckets.first(where: { $0.limitID == id }) })
                    ?? buckets.first(where: { $0.limitID == "codex" })
                    ?? buckets.first else {
                    throw CodexRateLimitReaderError.rateLimitsUnavailable
                }
                let now = Date()
                quota = QuotaSnapshot(
                    usedPercent: primary.usedPercent,
                    windowDurationMinutes: primary.windowDurationMinutes,
                    resetsAt: primary.resetsAt,
                    sourceLabel: "Codex App Server",
                    provenance: .liveCodexAppServer,
                    generatedAt: now,
                    freshUntil: now.addingTimeInterval(5 * 60),
                    limitID: primary.limitID
                )
                quotaConnectionLabel = "Codex App Server 读取成功 · \(now.formatted(date: .omitted, time: .shortened))"
                rateLimitBuckets = buckets
                selectedQuotaLimitID = primary.limitID
                quotaConnectionState = .live
                hasCompletedInitialQuotaAttempt = true
                feedback = "已读取本机 Codex 额度；额度刷新未读取消息正文或 Gmail 内容。"
                updateNotchResident()
                publishWidgetSnapshotIfAvailable()
                await deliverQuotaThresholdAlertIfNeeded(buckets: buckets)
            } catch {
                quotaConnectionLabel = "不可用"
                quotaConnectionState = .unavailable
                hasCompletedInitialQuotaAttempt = true
                rateLimitBuckets = []
                selectedQuotaLimitID = nil
                let now = Date()
                quota = QuotaSnapshot(
                    usedPercent: nil,
                    windowDurationMinutes: nil,
                    resetsAt: nil,
                    sourceLabel: "不可用",
                    provenance: .unavailable,
                    generatedAt: now,
                    freshUntil: nil
                )
                feedback = (error as? LocalizedError)?.errorDescription ?? "读取 Codex 额度失败。"
                updateNotchResident()
                publishWidgetSnapshotIfAvailable()
            }
            isRefreshingQuota = false
        }
    }

    func publishWidgetSnapshotIfAvailable() {
        #if DEBUG
        if ProcessInfo.processInfo.environment.keys.contains(where: { $0.hasPrefix("WORKPULSE_QA_") }) {
            widgetSnapshotError = "QA 场景不会向系统桌面组件发布任何模拟状态。"
            return
        }
        #endif
        guard Bundle.main.object(forInfoDictionaryKey: "WorkPulseWidgetRuntimeEnabled") as? Bool == true else {
            widgetSnapshotError = "桌面组件等待 Apple Development 团队签名；菜单栏、刘海与通知仍可使用。"
            return
        }
        // Keep the last verified Widget timeline intact while the first live
        // App Server read is still pending. Otherwise the faster task monitor
        // can briefly replace a valid quota snapshot with an empty one.
        guard hasCompletedInitialQuotaAttempt else { return }
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WorkPulseRuntimeConfiguration.appGroupIdentifier()
        ) else {
            widgetSnapshotError = "Widget App Group 尚未配置；当前开发包不会发布桌面小组件。"
            return
        }

        if widgetSnapshotStore == nil {
            widgetSnapshotStore = SnapshotStore(fileURL: container.appendingPathComponent("widget.json"))
        }
        guard let store = widgetSnapshotStore else { return }

        // External surfaces must never receive simulated, fixture, or unavailable quota.
        let liveQuota = QuotaExternalPolicy.publishable(quota)
        let externalQuotaBuckets: [QuotaSnapshot]
        if (quotaConnectionState == .live || quotaConnectionState == .refreshing), liveQuota != nil {
            externalQuotaBuckets = rateLimitBuckets.map { bucket in
                QuotaSnapshot(
                    usedPercent: bucket.usedPercent,
                    windowDurationMinutes: bucket.windowDurationMinutes,
                    resetsAt: bucket.resetsAt,
                    sourceLabel: quota.sourceLabel,
                    provenance: .liveCodexAppServer,
                    generatedAt: quota.generatedAt,
                    freshUntil: quota.freshUntil,
                    limitID: bucket.limitID
                )
            }
        } else {
            externalQuotaBuckets = []
        }
        let now = Date()
        let runningTasks = taskMonitorConnectionState == .live
            ? RunningTaskSummary(
                count: activeCodexTasks.count,
                observedAt: now,
                freshUntil: now.addingTimeInterval(5 * 60)
            )
            : nil
        let snapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: manualRoutine,
            quota: liveQuota,
            generatedAt: now,
            freshUntil: liveQuota?.freshUntil,
            needsYou: nil,
            // WidgetKit may retain a rendered timeline briefly after a reload.
            // Keep desktop surfaces generic even when the user allows a title
            // inside the actively opened WorkPulse control surfaces.
            approvedRoutineTitle: nil,
            hasValidPinnedTarget: validTargetURL != nil,
            quotaBuckets: externalQuotaBuckets,
            runningTasks: runningTasks,
            themePreference: theme,
            accentPreference: accentPreference
        )
        let previous = widgetPublishTask
        widgetPublishTask = Task {
            if let previous { await previous.value }
            do {
                _ = try await store.writeNext(snapshot)
                widgetSnapshotError = nil
                widgetSnapshotLastWrittenAt = Date()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                widgetSnapshotError = "Widget 快照写入失败：\(error.localizedDescription)"
            }
        }
    }

    private func deliverQuotaThresholdAlertIfNeeded(buckets: [RateLimitBucketSnapshot]) async {
        let candidates = QuotaAlertPolicy.candidates(
            buckets: buckets,
            threshold: quotaAlertThreshold,
            alertedCycles: quotaAlertedCycles,
            previousRemainingByCycle: quotaPreviousRemainingByCycle
        )
        let currentObservations = QuotaAlertPolicy.observations(for: buckets)
        guard !candidates.isEmpty else {
            quotaPreviousRemainingByCycle = currentObservations
            UserDefaults.standard.set(currentObservations, forKey: "workpulse.quotaPreviousRemainingByCycle")
            return
        }

        let detail: String
        if candidates.count == 1, let candidate = candidates.first {
            detail = "\(compactWindowLabel(candidate.windowDurationMinutes)) · \(Int(candidate.remainingPercent.rounded()))% 剩余 · \(formattedResetTime(candidate.resetsAt)) 重置"
        } else {
            let summaries = candidates.prefix(2).map { candidate in
                "\(compactWindowLabel(candidate.windowDurationMinutes)) \(Int(candidate.remainingPercent.rounded()))%（\(formattedResetTime(candidate.resetsAt)) 重置）"
            }
            let remainder = candidates.count > 2 ? "；另有 \(candidates.count - 2) 个窗口" : ""
            detail = summaries.joined(separator: "；") + remainder
        }

        var delivered = false
        let userIsActive = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        ) < 60
        if userIsActive, topAlertsEnabled, NotchOverlayController.shared.isReachable {
            delivered = NotchOverlayController.shared.showAlert(
                title: "Codex 额度提醒",
                detail: detail,
                systemImage: "gauge.with.dots.needle.50percent",
                tone: .warning
            )
        }
        if !delivered,
           notificationFallbackEnabled,
           (notificationAuthorizationStatus == .authorized
                || notificationAuthorizationStatus == .provisional) {
            let requestID = candidates
                .map { "\($0.limitID)-\($0.cycleKey)" }
                .joined(separator: "-")
            do {
                try await NotificationCoordinator.shared.scheduleQuotaAlert(id: requestID, detail: detail)
                delivered = true
            } catch {
                delivered = false
                feedback = "低额度系统通知调度失败：\(error.localizedDescription)"
            }
        }

        guard delivered else {
            var retryableObservations = currentObservations
            for candidate in candidates {
                if let previous = quotaPreviousRemainingByCycle[candidate.observationKey] {
                    retryableObservations[candidate.observationKey] = previous
                } else {
                    retryableObservations.removeValue(forKey: candidate.observationKey)
                }
            }
            quotaPreviousRemainingByCycle = retryableObservations
            UserDefaults.standard.set(retryableObservations, forKey: "workpulse.quotaPreviousRemainingByCycle")
            return
        }
        quotaAlertedCycles = QuotaAlertPolicy.recording(candidates, in: quotaAlertedCycles)
        UserDefaults.standard.set(quotaAlertedCycles, forKey: "workpulse.quotaAlertedCycles")
        quotaPreviousRemainingByCycle = currentObservations
        UserDefaults.standard.set(currentObservations, forKey: "workpulse.quotaPreviousRemainingByCycle")
    }
}

private enum EventPresentation {
    static func title(for type: WorkEventType) -> String {
        switch type {
        case .needsApproval: "需要你的确认"
        case .needsInput: "需要补充信息"
        case .workLossRiskFailure: "任务可能无法继续"
        case .quotaPaused: "任务因额度暂停"
        case .recoverableFailure: "一项任务需要检查"
        case .longTaskCompleted: "一个长任务已完成"
        case .quotaCritical: "额度接近阈值"
        case .sourceDisconnected: "一个来源已断开"
        }
    }

    static func typeLabel(for type: WorkEventType) -> String {
        switch type {
        case .needsApproval: "需要确认"
        case .needsInput: "需要输入"
        case .workLossRiskFailure: "高风险失败"
        case .quotaPaused: "额度暂停"
        case .recoverableFailure: "可恢复失败"
        case .longTaskCompleted: "已完成"
        case .quotaCritical: "额度状态"
        case .sourceDisconnected: "连接断开"
        }
    }

    static func icon(for type: WorkEventType) -> String {
        switch type {
        case .needsApproval: "checkmark.shield"
        case .needsInput: "text.bubble"
        case .workLossRiskFailure: "exclamationmark.triangle"
        case .quotaPaused, .quotaCritical: "gauge.with.dots.needle.50percent"
        case .recoverableFailure: "wrench.and.screwdriver"
        case .longTaskCompleted: "checkmark.circle"
        case .sourceDisconnected: "bolt.slash"
        }
    }

    static func explanation(for type: WorkEventType) -> String {
        switch type {
        case .needsApproval: "模拟来源报告一项任务等待确认。WorkPulse 只展示请求范围，不会代替你批准或拒绝。"
        case .needsInput: "模拟来源报告一项任务需要补充信息。打开详情不等于已经提交输入。"
        case .workLossRiskFailure: "这是受控的高风险失败 fixture，用于检查恢复说明；并不代表真实工作已经丢失。"
        case .quotaPaused: "模拟任务因为额度暂停。重置时间到达也不能直接证明该任务已经恢复。"
        case .recoverableFailure: "这项失败可在来源中继续检查；WorkPulse 不会自动重试。"
        case .longTaskCompleted: "WorkPulse 只保存结果入口；打开入口不等于已经阅读结果。"
        case .quotaCritical: "这是被动额度状态，不进入主动 Needs You 投递。"
        case .sourceDisconnected: "当前只保留本机记录；断开来源不等于任务失败。"
        }
    }

    static func notchTone(for event: WorkEventRecord) -> NotchSurfaceTone {
        guard event.freshness == .fresh else { return .neutral }
        return switch event.type {
        case .workLossRiskFailure: .critical
        case .needsApproval, .needsInput, .quotaPaused, .recoverableFailure, .quotaCritical: .warning
        case .longTaskCompleted: .success
        case .sourceDisconnected: .neutral
        }
    }

    static func freshnessLabel(_ freshness: DataFreshness) -> String {
        switch freshness {
        case .fresh: "刚刚观察"
        case .cached: "缓存记录"
        case .stale: "可能已过期"
        case .offline: "离线"
        case .unsupported: "不支持"
        case .notLoaded: "未载入"
        case .sourceConflict: "来源冲突"
        }
    }
}

@main
struct WorkPulseMenuBarApp: App {
    @NSApplicationDelegateAdaptor(WorkPulseAppDelegate.self) private var appDelegate
    @StateObject private var model = WorkPulseModel()

    var body: some Scene {
        MenuBarExtra {
            WorkPulseControlCenter()
                .environmentObject(model)
                .preferredColorScheme(model.resolvedColorScheme)
                .onOpenURL(perform: model.handleDeepLink)
                .task { model.publishWidgetSnapshotIfAvailable() }
        } label: {
            HStack(spacing: 4) {
                Image("WorkPulseLogo")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 15, height: 15)
                    .overlay(alignment: .bottomTrailing) {
                        if !model.activeCodexTasks.isEmpty {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1))
                                .offset(x: 2, y: 2)
                        }
                    }
                if model.quotaConnectionState == .live,
                   model.quota.freshness(at: Date()) == .fresh,
                   let remaining = model.quota.remainingPercent {
                    Text("\(Int(remaining.rounded()))%")
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        #if DEBUG
        Window("WorkPulse Design QA", id: "workpulse-design-qa") {
            WorkPulseControlCenter()
                .environmentObject(model)
                .preferredColorScheme(model.resolvedColorScheme)
                .task { model.publishWidgetSnapshotIfAvailable() }
        }
        .windowResizability(.contentSize)
        #endif
    }

    private var menuBarAccessibilityLabel: String {
        let task = model.activeCodexTasks.isEmpty
            ? "没有运行中的任务"
            : "\(model.activeCodexTasks.count) 个任务正在运行"
        return "WorkPulse，\(model.quotaSummary)，\(task)"
    }
}

private struct RoutineMenuView: View {
    @EnvironmentObject private var model: WorkPulseModel
    @State private var showConfiguration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: model.routineSystemImage)
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.visibleRoutineTitle)
                        .font(.headline)
                    Text(model.capabilityLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: model.routineStatusSystemImage)
                    .foregroundStyle(model.routineStatusColor)
                    .accessibilityLabel(model.routineStatusAccessibilityLabel)
            }

            Divider()

            if !model.activeCodexTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("\(model.activeCodexTasks.count) 个 Codex 任务正在运行", systemImage: "bolt.horizontal.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                        Spacer()
                        Text("实时")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.activeCodexTasks.prefix(3))) { task in
                        HStack(spacing: 9) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.green)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.exposesTaskNames ? task.displayName : "Codex 任务")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(model.taskElapsedLabel(task))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("来自本机 Codex 任务生命周期；不读取消息正文。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Divider()
            }

            if !model.needsYouEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Label(model.eventDemoEnabled ? "Needs You · 模拟" : "Needs You", systemImage: "tray.full")
                                .font(.caption.weight(.semibold))
                            if model.eventDemoEnabled {
                                Text("非实时 fixture · 不会发送系统通知")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(model.needsYouEvents.count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                model.eventDemoEnabled ? Color.secondary.opacity(0.14) : Color.orange.opacity(0.18),
                                in: Capsule()
                            )
                            .accessibilityLabel(model.eventDemoEnabled
                                ? "\(model.needsYouEvents.count) 项模拟提醒，非实时"
                                : "\(model.needsYouEvents.count) 项需要处理")
                    }
                    ForEach(Array(model.needsYouEvents.prefix(3))) { event in
                        Button {
                            model.selectEvent(event.id)
                            model.showEventAlert(event)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: eventIcon(event.type))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(eventTitle(event.type))
                                        .font(.caption.weight(.semibold))
                                    Text("\(model.eventDemoEnabled ? "模拟 · " : "")\(eventTypeLabel(event.type)) · \(freshnessLabel(event.freshness))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(model.eventDemoEnabled ? "模拟提醒，非实时，" : "")\(eventTitle(event.type))，\(eventTypeLabel(event.type))，\(freshnessLabel(event.freshness))，按下查看详情")
                    }
                    if model.needsYouEvents.count > 3 {
                        Button("在顶部显示下一项") {
                            model.openNeedsYou()
                            if let event = model.selectedEvent { model.showEventAlert(event) }
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                    }
                }
                Divider()
            }

            if model.verifiedDemoEnabled {
                HStack(spacing: 0) {
                    metric("上次运行", value: time(model.routine.lastRunAt), detail: "演示")
                    Divider().frame(height: 54)
                    metric("需要处理", value: "\(model.routine.attentionCount)", detail: "项", tint: .orange)
                    Divider().frame(height: 54)
                    metric("下次运行", value: time(model.routine.nextRunAt), detail: "演示")
                }
            } else {
                Label("固定入口只保存链接；Codex 任务状态来自本机生命周期元数据。", systemImage: "hand.raised")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: model.openRoutine) {
                Label(model.targetActionLabel, systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(model.validTargetURL == nil)

            HStack {
                Image(systemName: model.quotaStatusSystemImage)
                    .foregroundStyle(model.quotaStatusColor)
                    .accessibilityLabel(model.quotaStatusAccessibilityLabel)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.quotaWindowLabel).font(.caption).fontWeight(.semibold)
                    Text(model.quotaSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.quotaStateBadgeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button(action: model.refreshLiveQuota) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isRefreshingQuota)
                .accessibilityLabel("刷新 Codex 额度")
            }

            if model.rateLimitBuckets.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("额度窗口")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(model.rateLimitBuckets) { bucket in
                        Button {
                            model.selectQuotaBucket(bucket.limitID)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: model.selectedQuotaLimitID == bucket.limitID
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .foregroundStyle(model.selectedQuotaLimitID == bucket.limitID ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(bucket.displayName ?? bucket.limitID)
                                        .font(.caption.weight(.semibold))
                                    Text("\(bucketWindowLabel(bucket.windowDurationMinutes)) · \(bucket.resetsAt.formatted(date: .omitted, time: .shortened)) 重置")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(bucket.remainingPercent.rounded()))%")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            model.selectedQuotaLimitID == bucket.limitID
                                ? Color.green.opacity(0.08)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .accessibilityLabel("\(bucket.displayName ?? bucket.limitID)，剩余 \(Int(bucket.remainingPercent.rounded()))%，\(bucketWindowLabel(bucket.windowDurationMinutes))")
                    }
                }
            }

            if let feedback = model.feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let widgetError = model.widgetSnapshotError {
                Label(widgetError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("桌面组件同步失败，\(widgetError)")
            } else if let writtenAt = model.widgetSnapshotLastWrittenAt {
                Label(
                    "桌面组件已同步 · \(writtenAt.formatted(date: .omitted, time: .shortened))",
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            DisclosureGroup("设置与预览", isExpanded: $showConfiguration) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("外观", selection: $model.theme) {
                        Text("跟随系统").tag(ThemePreference.system)
                        Text("浅色").tag(ThemePreference.light)
                        Text("深色").tag(ThemePreference.dark)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Privacy Mode", isOn: $model.privacyMode)
                    Toggle("刘海和菜单栏显示任务名称", isOn: $model.showTaskNamesInNotch)
                        .disabled(model.privacyMode)
                    Toggle("在组件和菜单栏显示入口名称", isOn: $model.allowRoutineTitle)
                        .disabled(model.privacyMode)
                    Toggle("顶部常驻状态", isOn: $model.overlayEnabled)
                    Toggle("一次性顶部提醒", isOn: $model.topAlertsEnabled)
                    Toggle("系统通知兜底", isOn: $model.notificationFallbackEnabled)

                    Picker("低额度提醒", selection: $model.quotaAlertThreshold) {
                        Text("关闭").tag(0)
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("30%").tag(30)
                    }
                    .accessibilityHint("每个额度窗口周期最多提醒一次；优先显示顶部提醒，关闭顶部状态时使用系统通知")

                    TextField("入口名称", text: $model.routineDisplayTitle)
                    TextField("HTTPS 对话链接", text: $model.targetURLString)
                        .accessibilityHint("仅接受以 https:// 开头的有效链接")
                    if let validationMessage = model.targetURLValidationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    HStack {
                        Label("通知：\(model.notificationStatusLabel)", systemImage: "bell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if model.notificationAuthorizationStatus == .notDetermined {
                            Button("允许") { model.requestNotificationAuthorization() }
                        } else {
                            Button("测试") { model.sendNotificationPreview() }
                            .disabled(model.notificationAuthorizationStatus == .denied)
                        }
                    }
                    if let receipt = model.lastNotificationOpenReceipt {
                        Label(
                            "上次通知点击已回流 · \(receipt.openedAt.formatted(date: .omitted, time: .shortened))",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption2)
                        .foregroundStyle(.green)
                    } else {
                        Text("尚未记录系统通知点击")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("预览一次性顶部提醒") { model.showCurrentStatusAlert() }
                        Spacer()
                        Button("退出") { NSApp.terminate(nil) }
                    }
                    .font(.caption)
                }
                .padding(.top, 10)
            }
            .font(.callout)
            }
            .padding(18)
        }
        .frame(width: 410)
        .frame(maxHeight: 720)
    }

    private func metric(_ label: String, value: String, detail: String, tint: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3).fontWeight(.semibold).foregroundStyle(tint)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func time(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func freshnessLabel(_ freshness: DataFreshness) -> String {
        switch freshness {
        case .fresh: "已更新"
        case .cached: "缓存"
        case .stale: "可能已过期"
        case .offline: "离线"
        case .unsupported: "不支持"
        case .notLoaded: "未载入"
        case .sourceConflict: "来源冲突"
        }
    }

    private func bucketWindowLabel(_ minutes: Int) -> String {
        if minutes % 10_080 == 0 { return "\(minutes / 10_080 * 7) 天窗口" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时窗口" }
        return "\(minutes) 分钟窗口"
    }

    private func eventTitle(_ type: WorkEventType) -> String { EventPresentation.title(for: type) }
    private func eventTypeLabel(_ type: WorkEventType) -> String { EventPresentation.typeLabel(for: type) }
    private func eventIcon(_ type: WorkEventType) -> String { EventPresentation.icon(for: type) }
}

// MARK: - WorkPulse control center

private enum ControlCenterPage: String, CaseIterable, Identifiable {
    case overview = "概览"
    case controls = "控制"

    var id: Self { self }
}

private enum PulseStyle {
    static let accent = Color(red: 0.36, green: 0.55, blue: 1.00)
    static let cyan = Color(red: 0.49, green: 0.83, blue: 0.99)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.52)
    static let warning = Color(red: 0.94, green: 0.61, blue: 0.20)
    static let critical = Color(red: 0.91, green: 0.31, blue: 0.35)
}

private struct WorkPulseControlCenter: View {
    @EnvironmentObject private var model: WorkPulseModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page: ControlCenterPage = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Picker("控制中心页面", selection: $page) {
                    ForEach(ControlCenterPage.allCases) { page in
                        Text(page.rawValue).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if page == .overview {
                    overview
                } else {
                    controls
                }

                footer
            }
            .padding(16)
        }
        .frame(
            minWidth: dynamicTypeSize.isAccessibilitySize ? 460 : 388,
            idealWidth: dynamicTypeSize.isAccessibilitySize ? 520 : 430,
            maxWidth: dynamicTypeSize.isAccessibilitySize ? 560 : 460
        )
        .frame(maxHeight: 680)
        .background(controlCenterBackground)
        .tint(accentColor)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image("WorkPulseLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)
                .accessibilityLabel("WorkPulse 标志")

            VStack(alignment: .leading, spacing: 3) {
                Text("WorkPulse")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 7, height: 7)
                    Text(connectionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: model.refreshLiveQuota) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .background(cardFill, in: Circle())
            .disabled(model.isRefreshingQuota)
            .accessibilityLabel(model.isRefreshingQuota ? "正在刷新 Codex 额度" : "刷新 Codex 额度")
        }
    }

    @ViewBuilder
    private var overview: some View {
        quotaCard

        if !model.activeCodexTasks.isEmpty {
            runningTasksCard
        } else {
            compactStatusCard(
                icon: model.taskMonitorConnectionState == .unavailable ? "bolt.slash" : "checkmark.circle",
                title: model.taskMonitorConnectionState == .loading ? "正在连接任务状态" : "当前没有运行中的 Codex 任务",
                detail: "仅读取本机任务生命周期，不读取对话正文。"
            )
        }

        pinnedRoutineCard
        widgetStatusCard

        if let feedback = model.feedback {
            Label(feedback, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var quotaCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CODEX 额度")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Text(model.quotaWindowLabel.replacingOccurrences(of: "Codex ", with: ""))
                        .font(.headline)
                }
                Spacer()
                Text(model.quotaStateBadgeLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(connectionColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(connectionColor.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .center, spacing: 16) {
                quotaGauge
                VStack(alignment: .leading, spacing: 6) {
                    Label(resetLabel, systemImage: "clock")
                        .font(.callout.weight(.semibold))
                    Text(quotaSourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if model.quotaConnectionState == .live,
               model.quota.freshness(at: Date()) == .fresh,
               let remaining = model.quota.remainingPercent {
                ProgressView(value: remaining, total: 100)
                    .progressViewStyle(.linear)
                    .tint(quotaTint(remaining))
                    .accessibilityLabel("Codex 剩余额度")
                    .accessibilityValue("百分之 \(Int(remaining.rounded()))")
            }

            if model.rateLimitBuckets.count > 1 {
                VStack(spacing: 6) {
                    ForEach(model.rateLimitBuckets) { bucket in
                        quotaBucketRow(bucket)
                    }
                }
            }
        }
        .pulseCard()
    }

    private var quotaGauge: some View {
        let remaining = model.quota.remainingPercent
        let displayValue = remaining.map { "\(Int($0.rounded()))%" } ?? "--"
        let progress = max(0, min(1, (remaining ?? 0) / 100))
        let tint = quotaTint(remaining ?? 0)

        return ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(displayValue)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("剩余")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 82, height: 82)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(remaining.map { "剩余额度百分之 \(Int($0.rounded()))" } ?? "剩余额度不可用")
    }

    private func quotaBucketRow(_ bucket: RateLimitBucketSnapshot) -> some View {
        let selected = model.selectedQuotaLimitID == bucket.limitID
        return Button {
            model.selectQuotaBucket(bucket.limitID)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(quotaTint(bucket.remainingPercent))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bucket.displayName ?? bucket.limitID)
                        .font(.caption.weight(.semibold))
                    Text("\(bucketWindowLabel(bucket.windowDurationMinutes)) · \(bucket.resetsAt.formatted(date: .omitted, time: .shortened)) 重置")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(bucket.remainingPercent.rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? accentColor : Color.secondary.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selected ? accentColor.opacity(0.10) : cardFill.opacity(0.72), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityLabel("\(bucket.displayName ?? bucket.limitID)，剩余百分之 \(Int(bucket.remainingPercent.rounded()))，\(bucketWindowLabel(bucket.windowDurationMinutes))")
        .accessibilityValue(selected ? "已选择" : "未选择")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var runningTasksCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("正在运行", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseStyle.cyan)
                Spacer()
                Text("\(model.activeCodexTasks.count) 个任务")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(model.activeCodexTasks.prefix(3))) { task in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(accentColor.opacity(0.16))
                        Image(systemName: "terminal.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                    .frame(width: 29, height: 29)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.exposesTaskNames ? task.displayName : "任务名称已隐藏")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text(model.taskElapsedLabel(task))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(PulseStyle.success)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel("正在运行")
                }
                .accessibilityElement(children: .combine)
            }

            Text("任务名称受隐私模式控制，不读取对话正文。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .pulseCard()
    }

    private var pinnedRoutineCard: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.14))
                Image(systemName: model.privacyMode ? "lock.fill" : "pin.fill")
                    .foregroundStyle(accentColor)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("固定入口")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(model.visibleRoutineTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(model.validTargetURL == nil ? "在控制页设置 HTTPS 对话链接" : "手动入口 · 不推断运行状态")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: model.openRoutine) {
                Image(systemName: "arrow.up.forward")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .background(accentColor.opacity(0.12), in: Circle())
            .disabled(model.validTargetURL == nil)
            .accessibilityLabel("打开固定入口")
        }
        .pulseCard()
    }

    private var widgetStatusCard: some View {
        HStack(spacing: 11) {
            Image(systemName: model.widgetSnapshotError == nil ? "rectangle.3.group.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(model.widgetSnapshotError == nil ? accentColor : PulseStyle.warning)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("桌面小组件")
                    .font(.callout.weight(.semibold))
                Text(widgetStatusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("添加：桌面右键 → 编辑小组件 → 搜索 WorkPulse")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(model.isRefreshingQuota ? "更新中" : "刷新额度") { model.refreshLiveQuota() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isRefreshingQuota)
                .accessibilityHint("重新读取 Codex 额度并更新已经添加到桌面的 WorkPulse 小组件；不会自动添加新组件")
        }
        .pulseCard()
    }

    private func compactStatusCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pulseCard()
    }

    @ViewBuilder
    private var controls: some View {
        controlSection("顶部显示", subtitle: "常驻状态、一次性提醒和系统通知相互独立。") {
            PulseToggleRow(
                icon: "rectangle.topthird.inset.filled",
                title: "刘海常驻状态",
                detail: "始终显示额度窗口、剩余比例和重置时间；运行任务仅显示数量。",
                isOn: $model.overlayEnabled
            )
            PulseToggleRow(
                icon: "sparkles.rectangle.stack",
                title: "一次性顶部提醒",
                detail: "仅在任务完成或额度跨越阈值时弹出。",
                isOn: $model.topAlertsEnabled
            )
            PulseToggleRow(
                icon: "bell.badge",
                title: "系统通知兜底",
                detail: "顶部提醒不可用时才尝试通知，不是桌面小组件。",
                isOn: $model.notificationFallbackEnabled
            )
            VStack(alignment: .leading, spacing: 7) {
                Text("低额度提醒")
                    .font(.caption.weight(.semibold))
                Picker("提醒阈值", selection: $model.quotaAlertThreshold) {
                    Text("关闭").tag(0)
                    Text("10%").tag(10)
                    Text("20%").tag(20)
                    Text("30%").tag(30)
                }
                .pickerStyle(.segmented)
                .accessibilityHint("每个额度窗口周期最多提醒一次")
            }
        }

        controlSection("隐私", subtitle: "默认只展示运行元数据，不读取对话正文。") {
            PulseToggleRow(
                icon: "hand.raised.fill",
                title: "隐私模式",
                detail: "隐藏固定入口和其他可识别标题。",
                isOn: $model.privacyMode
            )
            PulseToggleRow(
                icon: "text.redaction",
                title: "显示任务名称",
                detail: model.privacyMode ? "隐私模式已强制隐藏任务名称。" : "关闭后刘海与控制中心只显示任务数量。",
                isOn: $model.showTaskNamesInNotch,
                disabled: model.privacyMode
            )
            PulseToggleRow(
                icon: "pin",
                title: "显示固定入口名称",
                detail: "仅展示你明确保存的名称。",
                isOn: $model.allowRoutineTitle,
                disabled: model.privacyMode
            )
        }

        controlSection("外观与启动") {
            VStack(alignment: .leading, spacing: 7) {
                Text("外观")
                    .font(.caption.weight(.semibold))
                Picker("外观", selection: $model.theme) {
                    Text("跟随系统").tag(ThemePreference.system)
                    Text("浅色").tag(ThemePreference.light)
                    Text("深色").tag(ThemePreference.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("内置刘海上的灵动岛始终使用深色外壳，以贴合屏幕刘海；该选项调整控制中心、组件与无刘海屏幕上的浮动胶囊。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("强调色")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 10) {
                    ForEach(AccentPreference.allCases, id: \.self) { preference in
                        Button {
                            model.accentPreference = preference
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(preference.workPulseColor)
                                    .frame(width: 26, height: 26)
                                if model.accentPreference == preference {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle()
                                    .stroke(
                                        model.accentPreference == preference
                                            ? preference.workPulseColor
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                                    .padding(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preference.displayName)
                        .accessibilityValue(model.accentPreference == preference ? "已选择" : "未选择")
                    }
                }
            }

            PulseToggleRow(
                icon: "power",
                title: "登录时启动",
                detail: "登录 Mac 后自动运行 WorkPulse。",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
        }

        controlSection("固定入口", subtitle: "只保存入口，不推断 Gmail、Scheduled 或任务状态。") {
            TextField("入口名称", text: $model.routineDisplayTitle)
                .textFieldStyle(.roundedBorder)
            TextField("HTTPS 对话链接", text: $model.targetURLString)
                .textFieldStyle(.roundedBorder)
                .accessibilityHint("仅接受以 https:// 开头的有效链接")
            if let validationMessage = model.targetURLValidationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.warning)
            }
        }

        controlSection("系统通知") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.notificationStatusLabel)
                            .font(.callout.weight(.semibold))
                        Text("系统横幅与桌面小组件是两个不同入口。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.notificationAuthorizationStatus == .notDetermined {
                        Button("允许") { model.requestNotificationAuthorization() }
                    } else {
                        Button("测试") { model.sendNotificationPreview() }
                            .disabled(model.notificationAuthorizationStatus == .denied)
                    }
                }
                if let receipt = model.lastNotificationOpenReceipt {
                    Label(
                        "上次点击已回流 · \(receipt.openedAt.formatted(date: .omitted, time: .shortened))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(PulseStyle.success)
                } else {
                    Text("尚未记录系统通知点击")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let feedback = model.feedback {
            Label(feedback, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func controlSection<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .pulseCard()
    }

    private var footer: some View {
        HStack {
            Text("WorkPulse \(versionLabel)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("预览顶部提醒") { model.showCurrentStatusAlert() }
                .buttonStyle(.link)
                .font(.caption)
            Button("退出") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 2)
    }

    private var connectionLabel: String {
        switch model.quotaConnectionState {
        case .live: "Codex 已连接"
        case .refreshing: "正在连接 Codex"
        case .demo: "演示模式 · 非实时"
        case .unavailable: "Codex 连接不可用"
        }
    }

    private var connectionColor: Color {
        switch model.quotaConnectionState {
        case .live: PulseStyle.success
        case .refreshing: accentColor
        case .demo: .secondary
        case .unavailable: PulseStyle.warning
        }
    }

    private var resetLabel: String {
        guard model.quotaConnectionState == .live else {
            return model.quotaConnectionState == .refreshing ? "正在读取重置时间" : "重置时间不可用"
        }
        guard model.quota.freshness(at: Date()) == .fresh else { return "额度快照需要更新" }
        guard let reset = model.quota.resetsAt, reset > Date() else { return "等待来源更新" }
        if Calendar.current.isDateInToday(reset) {
            return "今天 \(reset.formatted(date: .omitted, time: .shortened)) 重置"
        }
        return "\(reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())) 重置"
    }

    private var quotaSourceLabel: String {
        switch model.quotaConnectionState {
        case .live:
            "来自 Codex App Server · \(model.quota.generatedAt.formatted(date: .omitted, time: .shortened)) 观察"
        case .refreshing:
            "正在读取本机额度状态"
        case .demo:
            "演示数据不会写入桌面小组件"
        case .unavailable:
            "点击右上角刷新重新连接"
        }
    }

    private var widgetStatusLabel: String {
        if let error = model.widgetSnapshotError { return error }
        if let writtenAt = model.widgetSnapshotLastWrittenAt {
            return "已同步 · \(writtenAt.formatted(date: .omitted, time: .shortened))"
        }
        return "等待首次同步"
    }

    private var versionLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
    }

    private func quotaTint(_ remaining: Double) -> Color {
        if remaining <= 10 { return PulseStyle.critical }
        if remaining <= 20 { return PulseStyle.warning }
        return accentColor
    }

    private func bucketWindowLabel(_ minutes: Int) -> String {
        if minutes % 10_080 == 0 { return "\(minutes / 10_080 * 7) 天窗口" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时窗口" }
        return "\(minutes) 分钟窗口"
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.065) : Color.black.opacity(0.045)
    }

    private var controlCenterBackground: some View {
        ZStack {
            (colorScheme == .dark
                ? Color(red: 0.055, green: 0.075, blue: 0.12)
                : Color(red: 0.965, green: 0.973, blue: 0.99))
            Circle()
                .fill(accentColor.opacity(colorScheme == .dark ? 0.10 : 0.065))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 155, y: -260)
        }
    }

    private var accentColor: Color {
        model.accentPreference.workPulseColor
    }
}

private struct PulseToggleRow: View {
    let icon: String
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var disabled = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .opacity(disabled ? 0.48 : 1)
        .disabled(disabled)
        .accessibilityElement(children: .combine)
    }
}

private struct PulseCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(13)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.055),
                        lineWidth: 1
                    )
            }
    }
}

private extension View {
    func pulseCard() -> some View {
        modifier(PulseCardModifier())
    }
}
