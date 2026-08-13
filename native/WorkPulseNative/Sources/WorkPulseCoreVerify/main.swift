import Foundation
import SQLite3
import WorkPulseCore

enum VerificationFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): "Verification failed: \(message)"
        }
    }
}

@main
struct WorkPulseCoreVerify {
    static func main() async throws {
        var checks = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw VerificationFailure.failed(message) }
            checks += 1
        }

        let now = Date(timeIntervalSince1970: 1_000)
        let displayCandidates = [
            DisplayPlacementCandidate(displayID: 10, isBuiltIn: false, hasNotch: false, isMain: true),
            DisplayPlacementCandidate(displayID: 20, isBuiltIn: true, hasNotch: true, isMain: false)
        ]
        try expect(
            DisplayPlacementPolicy.preferredDisplayID(from: displayCandidates) == 20,
            "top overlay must prefer the built-in notched display even when an external display is main"
        )
        try expect(
            DisplayPlacementPolicy.preferredDisplayID(from: [displayCandidates[0]]) == 10,
            "clamshell mode should fall back to the available main external display"
        )
        try expect(
            DisplayPlacementPolicy.preferredDisplayID(from: [
                DisplayPlacementCandidate(displayID: 30, isBuiltIn: true, hasNotch: false, isMain: false),
                displayCandidates[0]
            ]) == 30,
            "a built-in display without a notch should still be preferred over an external display"
        )
        try expect(
            DisplayPlacementPolicy.preferredDisplayID(from: []) == nil,
            "display placement should fail safely when no screens are available"
        )
        let taskStartedLine = Data(#"{"timestamp":"2026-08-12T10:25:10.763Z","type":"event_msg","payload":{"type":"task_started"}}"#.utf8)
        let taskCompletedLine = Data(#"{"timestamp":"2026-08-12T10:26:10.763Z","type":"event_msg","payload":{"type":"task_complete"}}"#.utf8)
        let taskNoiseLine = Data(#"{"timestamp":"2026-08-12T10:25:30.000Z","type":"response_item","payload":{"type":"message"}}"#.utf8)
        let runningState = CodexTaskLifecycleDetector.state(fromNewestLines: [taskNoiseLine, taskStartedLine])
        if case .running(let startedAt) = runningState {
            try expect(abs(startedAt.timeIntervalSince1970 - 1_786_530_310.763) < 0.001, "task monitor must preserve the task start timestamp")
        } else {
            throw VerificationFailure.failed("latest lifecycle boundary should detect a running task")
        }
        try expect(
            CodexTaskLifecycleDetector.state(fromNewestLines: [taskCompletedLine, taskStartedLine]) == .inactive,
            "a newer completion marker must stop the running task"
        )
        try expect(
            CodexTaskLifecycleDetector.terminalOutcome(fromNewestLines: [taskCompletedLine, taskStartedLine]) == .completed,
            "an explicit completion marker must preserve the completed outcome"
        )
        let taskFailedLine = Data(#"{"timestamp":"2026-08-12T10:26:10.763Z","type":"event_msg","payload":{"type":"task_failed"}}"#.utf8)
        let taskCancelledLine = Data(#"{"timestamp":"2026-08-12T10:26:10.763Z","type":"event_msg","payload":{"type":"task_cancelled"}}"#.utf8)
        let taskAbortedLine = Data(#"{"timestamp":"2026-08-12T10:26:10.763Z","type":"event_msg","payload":{"type":"turn_aborted"}}"#.utf8)
        try expect(
            CodexTaskLifecycleDetector.terminalOutcome(fromNewestLines: [taskFailedLine, taskStartedLine]) == .failed,
            "a failed task must not be presented as completed"
        )
        try expect(
            CodexTaskLifecycleDetector.terminalOutcome(fromNewestLines: [taskCancelledLine, taskStartedLine]) == .cancelled,
            "a cancelled task must not be presented as completed"
        )
        try expect(
            CodexTaskLifecycleDetector.terminalOutcome(fromNewestLines: [taskAbortedLine, taskStartedLine]) == .aborted,
            "an aborted turn must not be presented as completed"
        )
        try expect(
            CodexTaskLifecycleDetector.terminalOutcome(fromNewestLines: [taskStartedLine, taskCompletedLine]) == nil,
            "a newer task start must suppress an older terminal marker"
        )
        try expect(
            CodexTaskLifecycleDetector.state(fromNewestLines: [taskNoiseLine]) == .unknown,
            "unrelated message records must not invent task state"
        )
        let elapsedTask = CodexRunningTaskSnapshot(
            id: "task",
            displayName: "Test",
            startedAt: now,
            lastActivityAt: now
        )
        try expect(elapsedTask.elapsed(at: now.addingTimeInterval(75)) == 75, "task elapsed time must use the lifecycle start")
        try expect(elapsedTask.elapsed(at: now.addingTimeInterval(-1)) == 0, "task elapsed time must clamp clock skew at zero")

        let taskReaderHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("workpulse-task-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: taskReaderHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: taskReaderHome) }
        let activeRollout = taskReaderHome.appendingPathComponent("active.jsonl")
        let internalRollout = taskReaderHome.appendingPathComponent("internal.jsonl")
        let completedRollout = taskReaderHome.appendingPathComponent("completed.jsonl")
        try taskStartedLine.write(to: activeRollout)
        try taskStartedLine.write(to: internalRollout)
        var completedLifecycle = taskStartedLine
        completedLifecycle.append(Data("\n".utf8))
        completedLifecycle.append(taskCompletedLine)
        try completedLifecycle.write(to: completedRollout)
        var taskDatabase: OpaquePointer?
        guard sqlite3_open(taskReaderHome.appendingPathComponent("state_5.sqlite").path, &taskDatabase) == SQLITE_OK,
              let taskDatabase else {
            throw VerificationFailure.failed("task reader fixture database should open")
        }
        defer { sqlite3_close(taskDatabase) }
        let taskRecency = Int64(Date().timeIntervalSince1970 * 1_000)
        let taskSQL = """
        CREATE TABLE threads (
            id TEXT, rollout_path TEXT, name TEXT, title TEXT, cwd TEXT,
            recency_at_ms INTEGER, archived INTEGER, source TEXT
        );
        INSERT INTO threads VALUES (
            'active-user', '\(activeRollout.path)', NULL, '排查磁盘空间不足', '/tmp/project', \(taskRecency), 0, 'vscode'
        );
        INSERT INTO threads VALUES (
            'internal-guardian', '\(internalRollout.path)', NULL, 'internal approval review', '/tmp/project', \(taskRecency), 0, '{"subagent":{"other":"guardian"}}'
        );
        INSERT INTO threads VALUES (
            'completed-user', '\(completedRollout.path)', NULL, '已完成任务', '/tmp/project', \(taskRecency), 0, 'vscode'
        );
        """
        guard sqlite3_exec(taskDatabase, taskSQL, nil, nil, nil) == SQLITE_OK else {
            throw VerificationFailure.failed("task reader fixture schema should be created")
        }
        let detectedTasks = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(detectedTasks.count == 1, "task reader must exclude completed and internal subagent tasks")
        try expect(detectedTasks.first?.id == "active-user", "task reader must preserve the active top-level task identity")
        try expect(detectedTasks.first?.displayName == "排查磁盘空间不足", "task reader must prefer the Codex task title over the working-directory name")
        if let handle = try? FileHandle(forWritingTo: activeRollout) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\n".utf8))
            try handle.write(contentsOf: taskCompletedLine)
            try handle.close()
        }
        let tasksAfterIncrementalTerminal = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(tasksAfterIncrementalTerminal.isEmpty, "task reader cache must notice a terminal event appended after the initial scan")
        if let handle = try? FileHandle(forWritingTo: activeRollout) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\n".utf8))
            try handle.write(contentsOf: taskStartedLine)
            try handle.close()
        }
        let tasksAfterIncrementalRestart = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(tasksAfterIncrementalRestart.count == 1, "task reader cache must notice a newer start event without rescanning old rollout data")

        let irrelevantLifecycle = Data("{\"timestamp\":\"2026-08-11T12:10:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"irrelevant\"}}\n".utf8)
        try irrelevantLifecycle.write(to: activeRollout, options: .atomic)
        let tasksAfterTruncate = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(tasksAfterTruncate.isEmpty, "task reader cache must not resurrect an old start after rollout truncation")

        var restartedAfterTruncate = irrelevantLifecycle
        restartedAfterTruncate.append(taskStartedLine)
        try restartedAfterTruncate.write(to: activeRollout)
        let tasksAfterTruncateRestart = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(tasksAfterTruncateRestart.count == 1, "task reader must recognize a new start after rollout truncation")

        let replacementRollout = taskReaderHome.appendingPathComponent("replacement.jsonl")
        var sameSizedReplacement = irrelevantLifecycle
        if sameSizedReplacement.count < restartedAfterTruncate.count {
            sameSizedReplacement.append(Data(repeating: 0x20, count: restartedAfterTruncate.count - sameSizedReplacement.count))
        }
        try sameSizedReplacement.write(to: replacementRollout)
        try FileManager.default.removeItem(at: activeRollout)
        try FileManager.default.moveItem(at: replacementRollout, to: activeRollout)
        let tasksAfterPathReplacement = try CodexRunningTaskReader.read(codexHome: taskReaderHome, now: Date())
        try expect(tasksAfterPathReplacement.isEmpty, "task reader cache must reject a prior event when the rollout path now identifies a new file")

        let sourceScopeID = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
        func eventSource(_ byte: UInt8, adapterKind: SourceAdapterKind = .controlledFixture) -> EventSourceIdentity {
            EventSourceIdentity(
                adapterKind: adapterKind,
                sourceScopeID: sourceScopeID,
                sourceObjectDigest: Digest32(repeating: byte),
                resolutionCycleDigest: Digest32(repeating: byte &+ 64),
                schemaRevision: 1
            )
        }
        let quota = QuotaSnapshot(
            usedPercent: 125,
            windowDurationMinutes: 300,
            resetsAt: nil,
            sourceLabel: "test",
            provenance: .deterministicFixture,
            generatedAt: now,
            freshUntil: now.addingTimeInterval(60),
            limitID: "codex"
        )
        try expect(quota.remainingPercent == 0, "remaining quota must clamp at zero")
        try expect(quota.freshness(at: now) == .fresh, "quota should be fresh before freshUntil")
        try expect(quota.freshness(at: now.addingTimeInterval(61)) == .stale, "quota should become stale")

        let routine = PinnedRoutine(
            displayTitle: "每日 Gmail 审查",
            lastRunAt: now,
            nextRunAt: now.addingTimeInterval(3_600),
            attentionCount: 3,
            state: .needsReview,
            privacyClass: .userApprovedTitle,
            capability: .verifiedAdapter,
            sourceLabel: "fixture",
            sourceObservedAt: now,
            freshUntil: now.addingTimeInterval(60),
            fieldSupport: .all
        )
        let genericSnapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: routine,
            quota: quota,
            generatedAt: now,
            freshUntil: now.addingTimeInterval(600),
            revision: 1
        )
        try expect(genericSnapshot.routineTitle == "每日例程", "external snapshot must default to generic title")
        try expect(genericSnapshot.privacyClass == .generic, "external snapshot must be generic")
        try expect(genericSnapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion, "widget snapshot must use the current schema")
        try expect(genericSnapshot.routineCapability == .verifiedAdapter, "widget snapshot must preserve explicit capability")
        try expect(genericSnapshot.routineSourceLabel == "fixture", "widget snapshot must preserve source provenance")
        try expect(genericSnapshot.routineFreshness == .fresh, "widget snapshot must carry computed routine freshness")
        try expect(!genericSnapshot.hasValidPinnedTarget, "Widget snapshot must not imply a configured pinned target by default")
        try expect(genericSnapshot.quota?.limitID == "codex", "widget quota must preserve selected bucket identity")
        try expect(genericSnapshot.needsYou == nil, "routine attention must not be reused as a live Needs You summary")
        try expect(QuotaExternalPolicy.publishable(quota) == nil, "deterministic quota fixture must never be eligible for Widget publication")
        var liveQuota = quota
        liveQuota.provenance = .liveCodexAppServer
        try expect(QuotaExternalPolicy.publishable(liveQuota) == liveQuota, "only typed live App Server quota may be published externally")
        var weeklyQuota = liveQuota
        weeklyQuota.limitID = "codex-weekly"
        weeklyQuota.windowDurationMinutes = 10_080
        weeklyQuota.resetsAt = now.addingTimeInterval(7 * 24 * 3_600)
        let runningSummary = RunningTaskSummary(
            count: 2,
            observedAt: now,
            freshUntil: now.addingTimeInterval(300)
        )
        let overviewSnapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: routine,
            quota: liveQuota,
            generatedAt: now,
            freshUntil: liveQuota.freshUntil,
            hasValidPinnedTarget: true,
            quotaBuckets: [liveQuota, weeklyQuota],
            runningTasks: runningSummary,
            themePreference: .system,
            accentPreference: .violet
        )
        try expect(overviewSnapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion, "multi-size Widget data must use the current schema")
        try expect(overviewSnapshot.themePreference == .system, "Widget snapshot must preserve the three-state appearance preference")
        try expect(overviewSnapshot.accentPreference == .violet, "Widget snapshot must preserve the selected accent palette")
        try expect(overviewSnapshot.quotaBuckets.map(\.limitID) == ["codex", "codex-weekly"], "large Widget must preserve every live quota bucket identity")
        try expect(overviewSnapshot.runningTasks?.count == 2, "large Widget must carry only the running-task count")
        try expect(overviewSnapshot.hasValidPinnedTarget, "Widget snapshot must explicitly preserve a validated pinned target state")
        try expect(overviewSnapshot.runningTasks?.freshness(at: now.addingTimeInterval(301)) == .stale, "running-task Widget summary must expire")
        try expect(
            WorkPulseRuntimeConfiguration.appGroupIdentifier(plistValue: nil) == WorkPulseRuntimeConfiguration.legacyLocalAppGroup,
            "ad-hoc builds must use the explicit local App Group fallback"
        )
        try expect(
            WorkPulseRuntimeConfiguration.appGroupIdentifier(plistValue: "$(WORKPULSE_APP_GROUP)") == WorkPulseRuntimeConfiguration.legacyLocalAppGroup,
            "an unresolved Xcode App Group placeholder must fail back safely"
        )
        try expect(
            WorkPulseRuntimeConfiguration.appGroupIdentifier(plistValue: "ABCDE12345.com.workpulse.shared") == "ABCDE12345.com.workpulse.shared",
            "team-signed builds must use the resolved team-scoped App Group"
        )
        try expect(
            PresentationPrivacyPolicy.exposesUserTitle(privacyMode: false, userOptIn: true),
            "an approved title may be exposed only when privacy mode is off"
        )
        try expect(
            !PresentationPrivacyPolicy.exposesUserTitle(privacyMode: true, userOptIn: true),
            "privacy mode must override a previously enabled title preference"
        )
        try expect(
            !PresentationPrivacyPolicy.exposesUserTitle(privacyMode: false, userOptIn: false),
            "an opted-out title must remain hidden even when privacy mode is off"
        )

        let alertBucket = RateLimitBucketSnapshot(
            limitID: "codex",
            displayName: "Codex",
            usedPercent: 82,
            windowDurationMinutes: 300,
            resetsAt: now.addingTimeInterval(3_600)
        )
        var aboveThresholdBucket = alertBucket
        aboveThresholdBucket.usedPercent = 75
        let previousQuotaObservations = QuotaAlertPolicy.observations(for: [aboveThresholdBucket])
        try expect(
            QuotaAlertPolicy.candidates(
                buckets: [alertBucket],
                threshold: 0,
                alertedCycles: [:],
                previousRemainingByCycle: previousQuotaObservations
            ).isEmpty,
            "disabled quota alerts must never produce a candidate"
        )
        try expect(
            QuotaAlertPolicy.candidates(
                buckets: [alertBucket],
                threshold: 20,
                alertedCycles: [:],
                previousRemainingByCycle: [:]
            ).isEmpty,
            "the first observation below a threshold must establish a baseline instead of alerting"
        )
        let quotaAlertCandidates = QuotaAlertPolicy.candidates(
            buckets: [alertBucket],
            threshold: 20,
            alertedCycles: [:],
            previousRemainingByCycle: previousQuotaObservations
        )
        try expect(quotaAlertCandidates.count == 1, "crossing from above to below the threshold should produce one alert candidate")
        try expect(quotaAlertCandidates.first?.windowDurationMinutes == 300, "quota alert must carry the affected window identity")
        try expect(quotaAlertCandidates.first?.resetsAt == alertBucket.resetsAt, "quota alert must carry the next reset time")
        let recordedAlertCycles = QuotaAlertPolicy.recording(quotaAlertCandidates, in: [:])
        try expect(
            QuotaAlertPolicy.candidates(
                buckets: [alertBucket],
                threshold: 20,
                alertedCycles: recordedAlertCycles,
                previousRemainingByCycle: previousQuotaObservations
            ).isEmpty,
            "the same quota cycle must not alert twice"
        )
        var nextCycleBucket = alertBucket
        nextCycleBucket.resetsAt = alertBucket.resetsAt.addingTimeInterval(3_600)
        var nextCycleAboveThreshold = nextCycleBucket
        nextCycleAboveThreshold.usedPercent = 75
        try expect(
            QuotaAlertPolicy.candidates(
                buckets: [nextCycleBucket],
                threshold: 20,
                alertedCycles: recordedAlertCycles,
                previousRemainingByCycle: QuotaAlertPolicy.observations(for: [nextCycleAboveThreshold])
            ).count == 1,
            "a new reset cycle should be eligible for a new quota alert"
        )

        let secondExternalSnapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: routine,
            quota: quota,
            generatedAt: now,
            freshUntil: now.addingTimeInterval(600)
        )
        try expect(secondExternalSnapshot.routineTitle == "每日例程", "external snapshot must remain generic without explicit Widget title approval")
        try expect(secondExternalSnapshot.privacyClass == .generic, "external surfaces must not infer title permission")
        let titleOptInSnapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: routine,
            quota: nil,
            generatedAt: now,
            freshUntil: nil,
            approvedRoutineTitle: "每日 Gmail 审查"
        )
        try expect(titleOptInSnapshot.routineTitle == "每日 Gmail 审查", "widget may expose a routine title only after explicit user approval")
        try expect(titleOptInSnapshot.privacyClass == .userApprovedTitle, "approved widget title must carry user-approved privacy provenance")

        let manualRoutine = PinnedRoutine(
            displayTitle: "每日 Gmail 审查",
            lastRunAt: nil,
            nextRunAt: nil,
            attentionCount: 0,
            state: .manual,
            privacyClass: .userApprovedTitle,
            capability: .manualPin
        )
        try expect(manualRoutine.capability == .manualPin, "manual pin must be explicit")
        try expect(manualRoutine.lastRunAt == nil && manualRoutine.nextRunAt == nil, "manual pin must not invent run times")
        let manualSnapshot = SnapshotFactory.makeWidgetSnapshot(
            routine: manualRoutine,
            quota: nil,
            generatedAt: now,
            freshUntil: nil
        )
        try expect(manualSnapshot.routineFreshness == .unsupported, "manual snapshot must expose unsupported automatic status")
        try expect(manualSnapshot.attentionCount == 0 && manualSnapshot.nextRunAt == nil, "manual snapshot must suppress automatic fields")

        try expect(PinnedTargetURLPolicy.validate("   ") == .empty, "blank pinned target should stay empty instead of reporting a malformed URL")
        try expect(PinnedTargetURLPolicy.validate("not-a-url") == .invalid, "malformed pinned target must be rejected")
        try expect(PinnedTargetURLPolicy.validate("http://chatgpt.com/c/test") == .invalid, "pinned target must require HTTPS")
        let validPinnedURL = URL(string: "https://chatgpt.com/c/test")!
        try expect(PinnedTargetURLPolicy.validate("  \(validPinnedURL.absoluteString)  ") == .valid(validPinnedURL), "valid HTTPS pinned target should trim surrounding whitespace")

        let invalidManualInput = PinnedRoutine(
            displayTitle: "Should sanitize",
            lastRunAt: now,
            nextRunAt: now.addingTimeInterval(60),
            attentionCount: 99,
            state: .completed,
            capability: .manualPin,
            fieldSupport: .all
        )
        try expect(invalidManualInput.state == .manual, "manual capability must force manual state")
        try expect(invalidManualInput.attentionCount == 0, "manual capability must reject automatic attention")
        try expect(invalidManualInput.lastRunAt == nil && invalidManualInput.nextRunAt == nil, "manual capability must reject automatic run times")

        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://inbox")!) == .inbox, "inbox deep link should route")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://usage")!) == .usage, "usage deep link should route")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://notification-preview")!) == .notificationPreview, "notification preview deep link should route")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://routine/setup")!) == .routineSetup, "pinned Widget recovery must route to routine setup guidance")
        try expect(DeepLinkRouter.route(for: URL(string: "https://example.com")!) == nil, "external URL must not enter internal router")
        let routeID = UUID(uuidString: "5B32DE41-391F-4FA1-9496-F4042A3AF154")!
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://routine/\(routeID.uuidString)")!) == .routine(routeID), "routine deep link must require a UUID")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://event/\(routeID.uuidString)")!) == .event(routeID), "event deep link must require a UUID")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://task/task-123_abc")!) == .task("task-123_abc"), "task notification deep link should preserve a safe opaque identifier")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://task/task%2Funsafe")!) == nil, "task deep link must reject path separators after decoding")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://task/任务")!) == .task("任务"), "task deep link should preserve a bounded local Unicode identifier")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://routine/not-a-uuid")!) == nil, "bad routine UUID must be rejected")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://routine/\(routeID.uuidString)/extra")!) == nil, "extra path segments must be rejected")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://inbox?unsafe=1")!) == nil, "query parameters must be rejected")
        try expect(DeepLinkRouter.route(for: URL(string: "workpulse://usage#fragment")!) == nil, "fragments must be rejected")

        var framer = JSONLFramer(maximumLineBytes: 32, maximumBufferBytes: 64)
        let first = try framer.append(Data("{\"id\":1}".utf8))
        try expect(first.isEmpty, "partial JSONL frame must remain buffered")
        let second = try framer.append(Data("\n{\"id\":2}\r\n".utf8))
        try expect(second.count == 2, "framer should emit two complete lines")
        try expect(String(decoding: second[1], as: UTF8.self) == "{\"id\":2}", "framer should trim CRLF")

        var whitespaceFramer = JSONLFramer(maximumLineBytes: 32, maximumBufferBytes: 64)
        let whitespaceLines = try whitespaceFramer.append(Data(" \t\n\r\n".utf8))
        try expect(whitespaceLines.isEmpty, "whitespace-only lines should be ignored")
        let cleanEOF = try whitespaceFramer.finish()
        try expect(cleanEOF == nil, "clean EOF should not emit a frame")

        var truncatedFramer = JSONLFramer(maximumLineBytes: 32, maximumBufferBytes: 64)
        _ = try truncatedFramer.append(Data("{\"partial\":".utf8))
        do {
            _ = try truncatedFramer.finish()
            throw VerificationFailure.failed("incomplete EOF should fail")
        } catch JSONLFramerError.truncatedFrame {
            checks += 1
        }

        var oversizedFramer = JSONLFramer(maximumLineBytes: 4, maximumBufferBytes: 8)
        do {
            _ = try oversizedFramer.append(Data("12345".utf8))
            throw VerificationFailure.failed("oversized frame should fail")
        } catch JSONLFramerError.lineTooLarge {
            checks += 1
        }

        let reconnect = ReconnectPolicy(baseDelay: 0.5, maximumDelay: 4)
        try expect(reconnect.delay(forAttempt: 0) == 0, "first connection should not wait")
        try expect(reconnect.delay(forAttempt: 4) == 4, "reconnect delay should cap")

        let rateLimitFixture = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"limitName":null,"primary":{"usedPercent":125.0,"windowDurationMins":300,"resetsAt":2000.0}},"spark":{"limitName":"Fast","primary":{"usedPercent":7.0,"windowDurationMins":10080,"resetsAt":3000.0}}}}}"#.utf8)
        let buckets = try CodexRateLimitReader.decodeRateLimitsResponse(rateLimitFixture)
        try expect(buckets.count == 2, "rate-limit parser should preserve multiple buckets")
        try expect(buckets.first(where: { $0.limitID == "codex" })?.remainingPercent == 0, "rate-limit values must clamp")
        try expect(buckets.first(where: { $0.limitID == "spark" })?.windowDurationMinutes == 10_080, "window duration must come from the source")

        let singleBucketFixture = Data(#"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":"Codex","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":2000}},"rateLimitsByLimitId":null}}"#.utf8)
        let singleBucket = try CodexRateLimitReader.decodeRateLimitsResponse(singleBucketFixture)
        try expect(singleBucket.count == 1, "rate-limit parser should support the backward-compatible single-bucket view")
        try expect(singleBucket[0].limitID == "codex" && singleBucket[0].remainingPercent == 75, "single-bucket identity and remaining value must survive decoding")

        let resultEnvelope = try RPCEnvelopeClassifier.classify(Data(#"{"id":1,"result":{}}"#.utf8))
        try expect(resultEnvelope == .response(id: .integer(1), isError: false), "RPC result response should classify")
        let requestEnvelope = try RPCEnvelopeClassifier.classify(Data(#"{"id":"approval-1","method":"item/requestApproval","params":{}}"#.utf8))
        try expect(requestEnvelope == .serverRequest(id: .string("approval-1"), method: "item/requestApproval"), "RPC server request should classify")
        let notificationEnvelope = try RPCEnvelopeClassifier.classify(Data(#"{"method":"thread/status/changed","params":{}}"#.utf8))
        try expect(notificationEnvelope == .notification(method: "thread/status/changed"), "RPC notification should classify")
        do {
            _ = try RPCEnvelopeClassifier.classify(Data(#"{"id":1,"result":{},"error":{}}"#.utf8))
            throw VerificationFailure.failed("ambiguous RPC response should fail")
        } catch RPCEnvelopeError.invalidEnvelope {
            checks += 1
        }
        try expect(AppServerSessionTransition.isAllowed(from: .stopped, to: .starting), "session should start from stopped")
        try expect(AppServerSessionTransition.isAllowed(from: .initializing, to: .ready), "initialized session should become ready")
        try expect(!AppServerSessionTransition.isAllowed(from: .stopped, to: .ready), "session must not skip initialization")

        let blockingContext = DeliveryContext(
            sourceIsFrontmost: false,
            overlayEnabled: true,
            overlayReachable: true,
            notificationsAuthorized: true,
            userIsActive: true
        )
        let blockingSurfaces = DeliveryPolicy.surfaces(for: .needsApproval, context: blockingContext)
        try expect(blockingSurfaces.contains(.overlayAlert), "approval should use reachable overlay")
        try expect(!blockingSurfaces.contains(.notification), "approval must not duplicate overlay and notification")

        var unreachableOverlayContext = blockingContext
        unreachableOverlayContext.overlayReachable = false
        let notificationFallbackSurfaces = DeliveryPolicy.surfaces(for: .needsApproval, context: unreachableOverlayContext)
        try expect(notificationFallbackSurfaces.contains(.notification), "an unreachable top alert must route an approval to notification fallback")
        try expect(!notificationFallbackSurfaces.contains(.overlayAlert), "an unreachable top alert must not claim overlay delivery")

        var inactiveBlockingContext = blockingContext
        inactiveBlockingContext.userIsActive = false
        let inactiveBlockingSurfaces = DeliveryPolicy.surfaces(for: .needsApproval, context: inactiveBlockingContext)
        try expect(inactiveBlockingSurfaces.contains(.notification), "an inactive user should receive notification fallback for blocking work")
        try expect(!inactiveBlockingSurfaces.contains(.overlayAlert), "an inactive user must not lose blocking work to a transient overlay")

        var sourceFrontmostContext = blockingContext
        sourceFrontmostContext.sourceIsFrontmost = true
        let sourceFrontmostSurfaces = DeliveryPolicy.surfaces(for: .needsApproval, context: sourceFrontmostContext)
        try expect(!sourceFrontmostSurfaces.contains(.overlayAlert) && !sourceFrontmostSurfaces.contains(.notification), "the source already in front must suppress duplicate active interruption")

        let activeCompletionSurfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: blockingContext)
        try expect(activeCompletionSurfaces.contains(.overlayAlert), "an active user should see a reachable top alert when a long task completes")
        try expect(!activeCompletionSurfaces.contains(.notification), "task completion must not duplicate a reachable top alert with a notification")

        var inactiveCompletionContext = blockingContext
        inactiveCompletionContext.userIsActive = false
        let inactiveCompletionSurfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: inactiveCompletionContext)
        try expect(inactiveCompletionSurfaces.contains(.notification), "an inactive user should receive notification fallback for a completed task")
        try expect(!inactiveCompletionSurfaces.contains(.overlayAlert), "an inactive user should not lose completion feedback to an ambient top alert")

        var disabledCompletionOverlayContext = blockingContext
        disabledCompletionOverlayContext.overlayEnabled = false
        let disabledCompletionOverlaySurfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: disabledCompletionOverlayContext)
        try expect(disabledCompletionOverlaySurfaces.contains(.notification), "notification fallback should remain available when completion overlays are disabled")

        let sourceFrontmostCompletionSurfaces = DeliveryPolicy.surfaces(for: .longTaskCompleted, context: sourceFrontmostContext)
        try expect(!sourceFrontmostCompletionSurfaces.contains(.overlayAlert) && !sourceFrontmostCompletionSurfaces.contains(.notification), "the frontmost source should suppress duplicate completion interruptions")

        let passiveSurfaces = DeliveryPolicy.surfaces(for: .quotaCritical, context: blockingContext)
        try expect(passiveSurfaces == [.menuBar, .widget], "quota critical should stay passive")

        let alertEventID = UUID(uuidString: "AE111111-1111-4111-8111-111111111111")!
        let alertTypes: [WorkEventType] = [
            .needsApproval, .needsInput, .workLossRiskFailure, .recoverableFailure,
            .quotaPaused, .longTaskCompleted, .quotaCritical, .sourceDisconnected
        ]
        let alertPayloads = alertTypes.compactMap {
            ExternalAlertPayloadFactory.make(eventID: alertEventID, type: $0, surface: .overlayAlert)
        }
        try expect(alertPayloads.count == alertTypes.count, "every normalized type should have a generic overlay presentation contract")
        try expect(Set(alertPayloads.map(\.title)) == ["WorkPulse 需要你的处理"], "external alert titles must remain generic across event types")
        try expect(Set(alertPayloads.map(\.body)) == ["一个任务正在等待操作。打开 WorkPulse 查看。"], "external alert bodies must not leak event-specific content")
        try expect(Set(alertPayloads.map(\.primaryActionLabel)) == ["查看提醒"], "external alert CTA must route to WorkPulse instead of claiming source action")
        try expect(alertPayloads.allSatisfy { $0.deepLink.absoluteString == "workpulse://event/\(alertEventID.uuidString)" }, "external alert deep links must target only the normalized local event")
        try expect(ExternalAlertPayloadFactory.make(eventID: alertEventID, type: .needsApproval, surface: .menuBar) == nil, "passive surfaces must not receive an active alert payload")

        let fixtureRegistry = SourceCapabilityRegistry(revision: 1, activeDeliveryGrants: [
            ActiveDeliveryGrant(
                adapterKind: .controlledFixture,
                sourceScopeID: sourceScopeID,
                allowedEventTypes: [.needsApproval, .needsInput, .workLossRiskFailure, .quotaPaused],
                validUntil: now.addingTimeInterval(86_400)
            )
        ])
        var eventLedger = EventLedger(capabilityRegistry: fixtureRegistry)
        let fixtureSource = eventSource(1)
        guard case .inserted(let fixtureID) = eventLedger.observe(EventObservation(source: fixtureSource, transitionDigest: Digest32(repeating: 10), type: .needsApproval, observedAt: now, freshness: .fresh)) else {
            throw VerificationFailure.failed("fixture event should be stored for UI testing")
        }
        checks += 1
        try expect(eventLedger.record(id: fixtureID)?.isEligibleForActiveDelivery(at: now, registry: fixtureRegistry) == false, "fixture evidence must never be eligible for active delivery")
        try expect(!eventLedger.claimOwner(eventID: fixtureID, surface: .notification, at: now), "fixture event must never send a production notification")

        var productionDefaultLedger = EventLedger()
        let unregisteredSource = eventSource(2, adapterKind: .codexAppServer)
        guard case .inserted(let unregisteredID) = productionDefaultLedger.observe(EventObservation(
            source: unregisteredSource,
            transitionDigest: Digest32(repeating: 11),
            type: .needsApproval,
            observedAt: now,
            freshness: .fresh,
            evidenceClass: .liveVerifiedTransition
        )) else {
            throw VerificationFailure.failed("unregistered event should remain available for passive diagnostics")
        }
        checks += 1
        try expect(!productionDefaultLedger.claimOwner(eventID: unregisteredID, surface: .notification, at: now), "empty production capability registry must deny active delivery")

        let source = eventSource(3)
        let observation = EventObservation(source: source, transitionDigest: Digest32(repeating: 12), type: .needsApproval, observedAt: now, freshness: .fresh, evidenceClass: .liveVerifiedTransition)
        guard case .inserted(let eventID) = eventLedger.observe(observation) else {
            throw VerificationFailure.failed("first observation should insert an event")
        }
        checks += 1
        try expect(eventLedger.record(id: eventID)?.isEligibleForActiveDelivery(at: now, registry: fixtureRegistry) == true, "fresh approval should be eligible for active delivery")
        try expect(eventLedger.records.count == 2, "ledger should contain the fixture and one normalized live event")
        try expect(eventLedger.observe(observation) == .duplicate(eventID), "duplicate transition digest must be withheld instead of updating or replaying")
        try expect(eventLedger.records.count == 2, "duplicate observation must not create a second event")
        try expect(eventLedger.claimOwner(eventID: eventID, surface: .overlayAlert, at: now), "first active owner should be claimed")
        try expect(!eventLedger.claimOwner(eventID: eventID, surface: .menuBar, at: now), "passive menu-bar presence must never claim active ownership")
        try expect(!eventLedger.claimOwner(eventID: eventID, surface: .notification, at: now), "a second active owner must be rejected")
        try expect(eventLedger.auditEntries.filter { $0.eventID == eventID && $0.action == .ownerClaimed }.count == 1, "rejected owner must not append a false claim")
        try expect(!eventLedger.markPresented(eventID: eventID, surface: .notification, at: now), "a non-owner surface must not mark presentation")
        try expect(eventLedger.markPresented(eventID: eventID, surface: .overlayAlert, at: now), "the owner should mark presentation")
        try expect(eventLedger.markOpenRequested(eventID: eventID, at: now.addingTimeInterval(1)), "open request should be recorded")
        try expect(eventLedger.record(id: eventID)?.resolution == .active, "open request must not acknowledge or resolve the event")
        try expect(eventLedger.markSeen(eventID: eventID, at: now.addingTimeInterval(1.5)), "opening detail should mark an unread event as seen")
        try expect(eventLedger.record(id: eventID)?.userDisposition == .seenPending, "seen event must remain pending")
        try expect(eventLedger.record(id: eventID)?.resolution == .active, "opening detail must not claim source acknowledgement")
        try expect(eventLedger.auditEntries.contains { $0.eventID == eventID && $0.action == .seen }, "local seen evidence must use its own audit action")
        try expect(eventLedger.acknowledge(eventID: eventID, at: now.addingTimeInterval(2)), "explicit acknowledgement should remain separate from local seen")
        try expect(!eventLedger.acknowledge(eventID: eventID, at: now.addingTimeInterval(2.5)), "acknowledgement must be monotonic")
        try expect(eventLedger.record(id: eventID)?.activeOwner == nil, "acknowledgement must clear the active owner")
        try expect(!eventLedger.claimOwner(eventID: eventID, surface: .notification, at: now), "acknowledged event must not reactivate delivery")
        try expect(eventLedger.resolve(eventID: eventID, at: now.addingTimeInterval(3)), "acknowledged event should resolve")
        try expect(eventLedger.record(id: eventID)?.resolutionKind == .sourceConfirmed, "normal resolution must require source confirmation")
        try expect(eventLedger.observe(observation) == .terminalIgnored(eventID), "resolved source replay must remain terminal")
        try expect(eventLedger.record(id: eventID)?.resolution == .resolved, "resolved event must be monotonic")

        let staleSource = eventSource(4)
        guard case .inserted(let staleID) = eventLedger.observe(EventObservation(source: staleSource, transitionDigest: Digest32(repeating: 13), type: .needsInput, observedAt: now, freshness: .stale, evidenceClass: .liveVerifiedTransition)) else {
            throw VerificationFailure.failed("stale observation should still be stored")
        }
        checks += 1
        try expect(eventLedger.record(id: staleID)?.isEligibleForActiveDelivery(at: now, registry: fixtureRegistry) == false, "stale event must not trigger active delivery")
        try expect(!eventLedger.claimOwner(eventID: staleID, surface: .notification, at: now), "stale event cannot claim an active owner")

        let conflictSource = eventSource(5)
        guard case .inserted(let conflictID) = eventLedger.observe(EventObservation(source: conflictSource, transitionDigest: Digest32(repeating: 14), type: .needsInput, observedAt: now, freshness: .fresh, evidenceClass: .liveVerifiedTransition)) else {
            throw VerificationFailure.failed("conflict fixture should insert")
        }
        checks += 1
        _ = eventLedger.observe(EventObservation(source: conflictSource, transitionDigest: Digest32(repeating: 15), type: .needsApproval, observedAt: now.addingTimeInterval(1), freshness: .fresh, evidenceClass: .liveVerifiedTransition))
        try expect(eventLedger.record(id: conflictID)?.freshness == .sourceConflict, "type mismatch for one source identity must become sourceConflict")
        try expect(!eventLedger.claimOwner(eventID: conflictID, surface: .overlayAlert, at: now), "sourceConflict must suppress active delivery")

        let collisionSource = eventSource(21)
        let recordsBeforeCollision = eventLedger.records.count
        let collisionResult = eventLedger.observe(EventObservation(
            eventID: conflictID,
            source: collisionSource,
            transitionDigest: Digest32(repeating: 21),
            type: .needsApproval,
            observedAt: now.addingTimeInterval(2),
            freshness: .fresh,
            evidenceClass: .liveVerifiedTransition
        ))
        try expect(collisionResult == .identityCollision(conflictID), "caller-provided event ID collision must fail closed")
        try expect(eventLedger.records.count == recordsBeforeCollision, "event ID collision must not overwrite or add a record")
        try expect(eventLedger.record(id: conflictID)?.source == conflictSource, "event ID collision must preserve the original source identity")

        let orderedSource = eventSource(22)
        guard case .inserted(let orderedID) = eventLedger.observe(EventObservation(
            source: orderedSource,
            transitionDigest: Digest32(repeating: 22),
            type: .needsInput,
            observedAt: now.addingTimeInterval(20),
            freshness: .fresh,
            evidenceClass: .liveVerifiedTransition
        )) else {
            throw VerificationFailure.failed("ordered event fixture should insert")
        }
        checks += 1
        let outOfOrderResult = eventLedger.observe(EventObservation(
            source: orderedSource,
            transitionDigest: Digest32(repeating: 23),
            type: .needsInput,
            observedAt: now.addingTimeInterval(10),
            freshness: .stale,
            evidenceClass: .liveVerifiedTransition
        ))
        try expect(outOfOrderResult == .outOfOrder(orderedID), "older transition must be withheld without a source cursor")
        try expect(eventLedger.record(id: orderedID)?.freshness == .fresh, "older transition must not regress current freshness")

        let transferSource = eventSource(6)
        guard case .inserted(let transferID) = eventLedger.observe(EventObservation(source: transferSource, transitionDigest: Digest32(repeating: 16), type: .quotaPaused, observedAt: now, freshness: .fresh, evidenceClass: .liveVerifiedTransition)) else {
            throw VerificationFailure.failed("transfer fixture should insert")
        }
        checks += 1
        try expect(eventLedger.claimOwner(eventID: transferID, surface: .overlayAlert, at: now), "transfer fixture should claim overlay")
        try expect(eventLedger.transferOwner(eventID: transferID, from: .overlayAlert, to: .notification, at: now), "owner should transfer atomically to fallback")
        try expect(eventLedger.record(id: transferID)?.activeOwner == .notification, "fallback should be the only active owner")
        try expect(!eventLedger.replaceCapabilityRegistry(fixtureRegistry, at: now), "capability registry must reject a replayed revision")
        let revokedRegistry = SourceCapabilityRegistry(revision: 2)
        try expect(eventLedger.replaceCapabilityRegistry(revokedRegistry, at: now.addingTimeInterval(1)), "newer capability registry should replace the current grants")
        try expect(eventLedger.capabilityRegistryRevision == 2, "ledger should expose the active registry revision for diagnostics")
        try expect(eventLedger.record(id: transferID)?.activeOwner == nil, "grant revocation must clear an existing active owner")
        try expect(eventLedger.auditEntries.contains { $0.eventID == transferID && $0.action == .ownerRevoked }, "grant revocation must append owner-revoked audit evidence")
        let renewedRegistry = SourceCapabilityRegistry(revision: 3, activeDeliveryGrants: [
            ActiveDeliveryGrant(
                adapterKind: .controlledFixture,
                sourceScopeID: sourceScopeID,
                allowedEventTypes: [.quotaPaused],
                validUntil: now.addingTimeInterval(100)
            )
        ])
        try expect(eventLedger.replaceCapabilityRegistry(renewedRegistry, at: now.addingTimeInterval(2)), "newer scoped grant should renew active delivery")
        try expect(eventLedger.claimOwner(eventID: transferID, surface: .overlayAlert, at: now.addingTimeInterval(2)), "renewed scoped grant should allow the matching event to claim an owner")
        try expect(eventLedger.reconcileActiveOwners(at: now.addingTimeInterval(101)) == 1, "expired grant should revoke an already active owner")
        try expect(eventLedger.record(id: transferID)?.activeOwner == nil, "expired capability must not retain active ownership")
        let restoredFixtureRegistry = SourceCapabilityRegistry(revision: 4, activeDeliveryGrants: [
            ActiveDeliveryGrant(
                adapterKind: .controlledFixture,
                sourceScopeID: sourceScopeID,
                allowedEventTypes: [.needsApproval, .needsInput, .workLossRiskFailure, .quotaPaused],
                validUntil: now.addingTimeInterval(86_400)
            )
        ])
        try expect(eventLedger.replaceCapabilityRegistry(restoredFixtureRegistry, at: now.addingTimeInterval(102)), "test ledger should restore the scoped fixture grants for later cases")
        try expect(EventCTA.label(for: .needsInput) == "查看输入边界", "local CTA must be event-specific without claiming an external action")

        let snoozeSource = eventSource(7)
        guard case .inserted(let snoozeID) = eventLedger.observe(EventObservation(source: snoozeSource, transitionDigest: Digest32(repeating: 17), type: .needsInput, observedAt: now, freshness: .fresh, evidenceClass: .liveVerifiedTransition)) else {
            throw VerificationFailure.failed("snooze fixture should insert")
        }
        checks += 1
        let snoozeUntil = now.addingTimeInterval(3_600)
        try expect(eventLedger.markSeen(eventID: snoozeID, at: now), "opening the snooze fixture should only mark it seen")
        try expect(!eventLedger.snooze(eventID: snoozeID, at: now, until: now), "direct snooze must reject a non-future deadline")
        try expect(eventLedger.snooze(eventID: snoozeID, at: now, until: snoozeUntil), "pending event should snooze")
        try expect(eventLedger.record(id: snoozeID)?.isVisibleInNeedsYou(at: now) == false, "snoozed event must leave the active Inbox")
        try expect(eventLedger.record(id: snoozeID)?.resolution == .active, "snooze must remain a user disposition instead of changing source lifecycle")
        try expect(eventLedger.record(id: snoozeID)?.effectiveUserDisposition(at: snoozeUntil) == .seenPending, "expired snooze should return to pending")
        try expect(eventLedger.record(id: snoozeID)?.isVisibleInNeedsYou(at: snoozeUntil) == true, "expired snooze must restore the same event ID")
        try expect(eventLedger.claimOwner(eventID: snoozeID, surface: .notification, at: snoozeUntil), "expired snooze should become eligible for active delivery again")
        try expect(eventLedger.record(id: snoozeID)?.userDisposition == .snoozed, "claim alone must not consume an expired snooze before presentation succeeds")
        try expect(eventLedger.transferOwner(eventID: snoozeID, from: .notification, to: .overlayAlert, at: snoozeUntil), "a scheduling failure should be able to transfer the expired-snooze delivery")
        try expect(eventLedger.releaseOwner(eventID: snoozeID, surface: .overlayAlert, at: snoozeUntil), "a failed fallback should release ownership for retry")
        try expect(eventLedger.claimOwner(eventID: snoozeID, surface: .notification, at: snoozeUntil), "released expired-snooze delivery should be reclaimable")
        try expect(eventLedger.markPresented(eventID: snoozeID, surface: .notification, at: snoozeUntil), "successful presentation should consume the expired snooze")
        try expect(eventLedger.record(id: snoozeID)?.userDisposition == .seenPending, "successful re-delivery should normalize the local disposition")
        try expect(eventLedger.record(id: snoozeID)?.snoozedUntil == nil, "successful re-delivery should clear the expired deadline")
        try expect(eventLedger.auditEntries.contains { $0.eventID == snoozeID && $0.action == .ownerReleased }, "failed scheduling should leave release audit evidence")

        let handledSource = eventSource(8)
        guard case .inserted(let handledID) = eventLedger.observe(EventObservation(source: handledSource, transitionDigest: Digest32(repeating: 18), type: .recoverableFailure, observedAt: now, freshness: .fresh)) else {
            throw VerificationFailure.failed("handled fixture should insert")
        }
        checks += 1
        try expect(eventLedger.markUserHandled(eventID: handledID, at: now), "user should be able to hide a local event")
        try expect(eventLedger.record(id: handledID)?.userDisposition == .userHandled, "handled state must be explicitly user-reported")
        try expect(eventLedger.record(id: handledID)?.resolution == .resolved, "user disposition should end the local unresolved cycle")
        try expect(eventLedger.record(id: handledID)?.resolutionKind == .userDisposition, "user-handled must not claim source resolution")
        try expect(eventLedger.record(id: handledID)?.isVisibleInNeedsYou(at: now) == false, "user-handled event must leave default Inbox")

        let invalidatedSource = eventSource(9)
        let invalidatedObservation = EventObservation(
            source: invalidatedSource,
            transitionDigest: Digest32(repeating: 19),
            type: .needsApproval,
            observedAt: now,
            freshness: .fresh,
            evidenceClass: .liveVerifiedTransition
        )
        guard case .inserted(let invalidatedID) = eventLedger.observe(invalidatedObservation) else {
            throw VerificationFailure.failed("invalidation fixture should insert")
        }
        checks += 1
        try expect(eventLedger.invalidate(eventID: invalidatedID, at: now, reason: .normalizationRejected), "valid event should be invalidatable when evidence is disproven")
        try expect(eventLedger.record(id: invalidatedID)?.resolution == .invalidated, "invalidated must be a distinct terminal state")
        try expect(eventLedger.record(id: invalidatedID)?.invalidationReason == .normalizationRejected, "invalidation must preserve a typed reason")
        try expect(eventLedger.observe(invalidatedObservation) == .terminalIgnored(invalidatedID), "invalidated replay must never reactivate")
        try expect(eventLedger.auditEntries.contains { $0.eventID == invalidatedID && $0.action == .replayWithheld }, "terminal replay should remain visible in append-only audit")

        let ledgerData = try JSONEncoder().encode(eventLedger)
        let decodedLedger = try JSONDecoder().decode(EventLedger.self, from: ledgerData)
        try expect(decodedLedger == eventLedger, "event ledger should persist without free-text payloads")
        let ledgerString = String(decoding: ledgerData, as: UTF8.self)
        try expect(!ledgerString.localizedCaseInsensitiveContains("sourceEventID"), "event ledger must not persist raw source event IDs")
        try expect(eventLedger.auditEntries.contains { $0.eventID == eventID && $0.action == .openRequested }, "open request must append audit evidence")
        try expect(eventLedger.auditEntries.contains { $0.eventID == eventID && $0.action == .sourceResolved }, "source resolution must append typed audit evidence")

        var callbackLedger = EventLedger(capabilityRegistry: fixtureRegistry)
        let callbackSource = eventSource(10)
        guard case .inserted(let callbackEventID) = callbackLedger.observe(EventObservation(
            source: callbackSource,
            transitionDigest: Digest32(repeating: 20),
            type: .needsInput,
            observedAt: now,
            freshness: .fresh,
            evidenceClass: .liveVerifiedTransition
        )) else {
            throw VerificationFailure.failed("callback fixture should insert")
        }
        checks += 1
        let callbackID = UUID(uuidString: "CA111111-1111-4111-8111-111111111111")!
        let callback = EventCallback(
            id: callbackID,
            eventID: callbackEventID,
            kind: .openRequested,
            occurredAt: now.addingTimeInterval(4)
        )
        try expect(callbackLedger.applyCallback(callback) == .applied, "first callback delivery should apply")
        try expect(callbackLedger.applyCallback(callback) == .duplicate(original: .applied), "callback retry must return the stored first outcome")
        try expect(callbackLedger.record(id: callbackEventID)?.openRequestCount == 1, "duplicate callback must not apply the side effect twice")
        try expect(callbackLedger.auditEntries.filter { $0.callbackID == callbackID && $0.action == .callbackApplied }.count == 1, "only the first callback may be recorded as applied")
        try expect(callbackLedger.auditEntries.filter { $0.callbackID == callbackID && $0.action == .callbackReplayWithheld }.count == 1, "callback retry should remain auditable")

        let callbackCollision = EventCallback(
            id: callbackID,
            eventID: callbackEventID,
            kind: .userHandled,
            occurredAt: now.addingTimeInterval(6)
        )
        try expect(callbackLedger.applyCallback(callbackCollision) == .identityCollision(original: .applied), "same callback ID with different payload must fail closed")
        try expect(callbackLedger.record(id: callbackEventID)?.userDisposition != .userHandled, "callback ID collision must not apply a different side effect")
        try expect(callbackLedger.auditEntries.contains { $0.callbackID == callbackID && $0.action == .callbackIdentityCollision }, "callback identity collision must remain auditable")

        let invalidSnoozeCallback = EventCallback(
            id: UUID(uuidString: "CA222222-2222-4222-8222-222222222222")!,
            eventID: callbackEventID,
            kind: .snoozed,
            occurredAt: now.addingTimeInterval(5),
            snoozedUntil: now.addingTimeInterval(4)
        )
        try expect(callbackLedger.applyCallback(invalidSnoozeCallback) == .rejected, "expired snooze callback must be rejected")
        try expect(callbackLedger.applyCallback(invalidSnoozeCallback) == .duplicate(original: .rejected), "rejected callback retry must keep the original outcome")
        let callbackData = try JSONEncoder().encode(callbackLedger)
        let decodedCallbackLedger = try JSONDecoder().decode(EventLedger.self, from: callbackData)
        try expect(decodedCallbackLedger == callbackLedger, "callback receipts must survive ledger persistence")
        do {
            _ = try Digest32(bytes: Data(repeating: 0, count: 31))
            throw VerificationFailure.failed("short digest should fail")
        } catch DigestValidationError.invalidLength {
            checks += 1
        }

        let telemetry = TelemetryEnvelope(
            eventID: eventID,
            recordedAt: now,
            name: .surfacePresented,
            workEventType: .needsApproval,
            surface: .overlayAlert,
            resolution: .active,
            freshness: .fresh
        )
        let telemetryData = try TelemetryExporter.encode(telemetry)
        let telemetryString = String(decoding: telemetryData, as: UTF8.self)
        try expect(TelemetryExporter.containsOnlyAllowedKeys(telemetryData), "typed telemetry must pass the field allowlist")
        try expect(!telemetryString.localizedCaseInsensitiveContains("title"), "telemetry must not include titles")
        try expect(!telemetryString.localizedCaseInsensitiveContains("sourceEventID"), "telemetry must not include source event identities")

        let retention = TelemetryRetentionPolicy(retentionDays: 14)
        try expect(!retention.shouldDelete(recordedAt: now.addingTimeInterval(-13 * 86_400), now: now), "13-day telemetry should remain")
        try expect(retention.shouldDelete(recordedAt: now.addingTimeInterval(-15 * 86_400), now: now), "15-day telemetry should be deleted")

        var safety = PilotSafetyMonitor()
        try expect(!safety.shouldStop, "pilot safety monitor should start clear")
        safety.record(.wrongTarget)
        try expect(safety.shouldStop && safety.reasons == [.wrongTarget], "wrong target must stop the pilot immediately")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("workpulse-verify-\(UUID().uuidString)", isDirectory: true)
        let store = SnapshotStore(fileURL: directory.appendingPathComponent("widget.json"))
        try await store.write(genericSnapshot)
        let loaded = try await store.read()
        try expect(loaded == genericSnapshot, "snapshot store should round-trip atomically")
        var olderWidgetSnapshot = genericSnapshot
        olderWidgetSnapshot.generatedAt = now.addingTimeInterval(-1)
        olderWidgetSnapshot.revision = 99
        let rejectedOlderWidgetWrite = try await store.write(olderWidgetSnapshot)
        try expect(!rejectedOlderWidgetWrite, "Widget store must reject an older generatedAt even when its proposed revision is larger")
        var newerWidgetSnapshot = genericSnapshot
        newerWidgetSnapshot.generatedAt = now.addingTimeInterval(1)
        newerWidgetSnapshot.revision = 0
        let acceptedNewerWidgetWrite = try await store.write(newerWidgetSnapshot)
        try expect(acceptedNewerWidgetWrite, "Widget store should accept a newer host snapshot")
        let loadedNewerWidgetSnapshot = try await store.read()
        try expect(loadedNewerWidgetSnapshot?.generatedAt == newerWidgetSnapshot.generatedAt, "newest Widget generatedAt should remain durable")
        try expect(loadedNewerWidgetSnapshot?.revision == 2, "Widget store should assign the next durable revision")
        var clockRollbackSnapshot = genericSnapshot
        clockRollbackSnapshot.generatedAt = now.addingTimeInterval(-3_600)
        let storedClockRollbackSnapshot = try await store.writeNext(clockRollbackSnapshot)
        try expect(storedClockRollbackSnapshot.revision == 3, "serialized host publisher should advance causal revision despite wall-clock rollback")
        let widgetAfterClockRollback = try await store.read()
        try expect(widgetAfterClockRollback?.revision == 3, "causal Widget revision should remain durable after clock rollback")
        let oldWidgetURL = directory.appendingPathComponent("old-widget.json")
        try Data(#"{"schemaVersion":2}"#.utf8).write(to: oldWidgetURL, options: [.atomic])
        let oldWidgetStore = SnapshotStore(fileURL: oldWidgetURL)
        do {
            _ = try await oldWidgetStore.read()
            throw VerificationFailure.failed("old Widget schema should be classified before full payload decode")
        } catch SnapshotStoreError.unsupportedSchema(2) {
            checks += 1
        }
        let migratedWidgetSnapshot = try await oldWidgetStore.writeNext(overviewSnapshot)
        try expect(migratedWidgetSnapshot.revision == 1, "a host update must replace its own unsupported Widget schema")
        let loadedMigratedWidgetSnapshot = try await oldWidgetStore.read()
        try expect(loadedMigratedWidgetSnapshot == migratedWidgetSnapshot, "migrated Widget schema must become immediately readable")

        let corruptWidgetDirectory = directory.appendingPathComponent("corrupt-widget", isDirectory: true)
        try FileManager.default.createDirectory(at: corruptWidgetDirectory, withIntermediateDirectories: true)
        let corruptWidgetURL = corruptWidgetDirectory.appendingPathComponent("widget.json")
        let corruptWidgetData = Data(
            "{\"schemaVersion\":\(WidgetSnapshot.currentSchemaVersion),\"generatedAt\":\"broken\"}".utf8
        )
        try corruptWidgetData.write(to: corruptWidgetURL, options: [.atomic])
        let corruptWidgetStore = SnapshotStore(fileURL: corruptWidgetURL)
        let repairedWidgetSnapshot = try await corruptWidgetStore.writeNext(overviewSnapshot)
        try expect(repairedWidgetSnapshot.revision == 1, "a corrupt Widget snapshot must recover from revision one")
        let loadedRepairedWidgetSnapshot = try await corruptWidgetStore.read()
        try expect(loadedRepairedWidgetSnapshot == repairedWidgetSnapshot, "a repaired Widget snapshot must become immediately readable")
        let corruptBackups = try FileManager.default.contentsOfDirectory(
            at: corruptWidgetDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("widget.json.corrupt-") }
        try expect(corruptBackups.count == 1, "Widget recovery must preserve exactly one corrupt diagnostic copy")
        let quarantinedCorruptWidgetData = try Data(contentsOf: corruptBackups[0])
        try expect(quarantinedCorruptWidgetData == corruptWidgetData, "Widget recovery must preserve the original corrupt bytes")

        let ledgerStore = EventLedgerStore(fileURL: directory.appendingPathComponent("events.json"))
        try await ledgerStore.write(callbackLedger, revision: 2, at: now)
        let persistedLedger = try await ledgerStore.read()
        try expect(persistedLedger?.ledger == callbackLedger, "event ledger store should preserve callback receipts and audit history")
        try expect(persistedLedger?.writtenAt == now, "event ledger store should preserve the evidence write time")
        try expect(persistedLedger?.revision == 2, "event ledger store should preserve a monotonic host revision")
        let rejectedOlderWrite = try await ledgerStore.write(EventLedger(), revision: 1, at: now.addingTimeInterval(1))
        try expect(!rejectedOlderWrite, "event ledger store must reject an older snapshot that arrives after a newer one")
        let rejectedEqualRevisionWrite = try await ledgerStore.write(EventLedger(), revision: 2, at: now.addingTimeInterval(2))
        try expect(!rejectedEqualRevisionWrite, "event ledger store must reject a different snapshot with the same revision")
        let acceptedIdempotentWrite = try await ledgerStore.write(callbackLedger, revision: 2, at: now.addingTimeInterval(3))
        try expect(acceptedIdempotentWrite, "event ledger store may accept an idempotent retry with the same revision and ledger")
        let ledgerAfterRejectedWrite = try await ledgerStore.read()
        try expect(ledgerAfterRejectedWrite?.revision == 2, "rejected older snapshot must not replace the newest durable state")

        let unsupportedLedger = PersistedEventLedger(schemaVersion: 99, writtenAt: now, ledger: callbackLedger)
        let unsupportedLedgerEncoder = JSONEncoder()
        unsupportedLedgerEncoder.dateEncodingStrategy = .iso8601
        let unsupportedLedgerData = try unsupportedLedgerEncoder.encode(unsupportedLedger)
        try unsupportedLedgerData.write(to: directory.appendingPathComponent("unsupported-events.json"), options: [.atomic])
        let unsupportedLedgerStore = EventLedgerStore(fileURL: directory.appendingPathComponent("unsupported-events.json"))
        do {
            _ = try await unsupportedLedgerStore.read()
            throw VerificationFailure.failed("unsupported event ledger schema should fail closed")
        } catch EventLedgerStoreError.unsupportedSchema(99) {
            checks += 1
        }
        let legacyLedgerURL = directory.appendingPathComponent("legacy-events.json")
        try Data(#"{"schemaVersion":0}"#.utf8).write(to: legacyLedgerURL, options: [.atomic])
        let legacyLedgerStore = EventLedgerStore(fileURL: legacyLedgerURL)
        do {
            _ = try await legacyLedgerStore.read()
            throw VerificationFailure.failed("legacy event ledger schema should be classified before full payload decode")
        } catch EventLedgerStoreError.unsupportedSchema(0) {
            checks += 1
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedSnapshot = try encoder.encode(genericSnapshot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSnapshot = try decoder.decode(WidgetSnapshot.self, from: encodedSnapshot)
        try expect(decodedSnapshot == genericSnapshot, "host and Widget ISO8601 snapshot contracts must round-trip")

        if ProcessInfo.processInfo.environment["WORKPULSE_VERIFY_LIVE_TASK_READER"] == "1" {
            var durations: [Double] = []
            var observedCount = 0
            for _ in 0..<30 {
                let started = ContinuousClock.now
                observedCount = try CodexRunningTaskReader.read().count
                let components = started.duration(to: .now).components
                durations.append(
                    Double(components.seconds) * 1_000
                        + Double(components.attoseconds) / 1e15
                )
            }
            let sortedDurations = durations.sorted()
            let average = durations.reduce(0, +) / Double(durations.count)
            let p95 = sortedDurations[Int(Double(sortedDurations.count - 1) * 0.95)]
            print(String(format: "Live task reader: tasks=%d avg=%.2fms p95=%.2fms", observedCount, average, p95))
        }

        print("WorkPulseCore verification passed: \(checks) checks")
    }
}
