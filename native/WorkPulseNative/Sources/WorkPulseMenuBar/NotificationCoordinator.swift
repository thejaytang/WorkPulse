import AppKit
import Foundation
import UserNotifications
import WorkPulseCore

enum WorkPulseNotificationError: LocalizedError {
    case unavailableOutsideAppBundle
    case invalidTaskIdentifier

    var errorDescription: String? {
        switch self {
        case .unavailableOutsideAppBundle:
            "系统通知只在 WorkPulse.app 中可用；SwiftPM 可执行文件仅用于开发验证。"
        case .invalidTaskIdentifier:
            "任务标识不能安全地写入 WorkPulse 通知链接。"
        }
    }
}

@MainActor
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    struct ResponseContext: Equatable, Sendable {
        var requestIdentifier: String
        var actionIdentifier: String
    }

    struct DiagnosticSnapshot: Codable {
        var authorizationStatus: Int
        var alertSetting: Int
        var notificationCenterSetting: Int
        var soundSetting: Int
        var deliveredRequestIDs: [String]
    }
    static let shared = NotificationCoordinator()

    private var center: UNUserNotificationCenter?
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var onStatusChange: ((UNAuthorizationStatus) -> Void)?
    var onOpenNotification: ((URL, String, String, CodexTaskTerminalOutcome?, ResponseContext) -> Void)?

    func configure() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            authorizationStatus = .denied
            onStatusChange?(.denied)
            return
        }
        let center = UNUserNotificationCenter.current()
        self.center = center
        center.delegate = self
        let open = UNNotificationAction(identifier: "OPEN", title: "查看", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "WORKPULSE_NEEDS_YOU",
                actions: [open],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "WORKPULSE_QUOTA",
                actions: [open],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "WORKPULSE_TASK_TERMINAL",
                actions: [open],
                intentIdentifiers: [],
                options: []
            )
        ])
        removeLegacyTaskNotificationsIfNeeded(using: center)
        refreshAuthorizationStatus()
    }

    private func removeLegacyTaskNotificationsIfNeeded(using center: UNUserNotificationCenter) {
        let migrationKey = "workpulse.notificationPrivacyMigration"
        guard UserDefaults.standard.integer(forKey: migrationKey) < 21 else { return }
        let cleanupGroup = DispatchGroup()
        cleanupGroup.enter()
        center.getDeliveredNotifications { notifications in
            let identifiers = notifications.map(\.request.identifier).filter {
                $0.hasPrefix("workpulse.task-terminal.")
            }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            cleanupGroup.leave()
        }
        cleanupGroup.enter()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter {
                $0.hasPrefix("workpulse.task-terminal.")
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            cleanupGroup.leave()
        }
        cleanupGroup.notify(queue: .main) {
            UserDefaults.standard.set(21, forKey: migrationKey)
        }
    }

    func refreshAuthorizationStatus() {
        guard let center else { return }
        center.getNotificationSettings { [weak self] settings in
            let rawStatus = settings.authorizationStatus.rawValue
            Task { @MainActor in
                guard let status = UNAuthorizationStatus(rawValue: rawStatus) else { return }
                self?.authorizationStatus = status
                self?.onStatusChange?(status)
            }
        }
    }

    func diagnosticSnapshot() async -> DiagnosticSnapshot {
        guard let center else {
            return DiagnosticSnapshot(
                authorizationStatus: UNAuthorizationStatus.denied.rawValue,
                alertSetting: UNNotificationSetting.disabled.rawValue,
                notificationCenterSetting: UNNotificationSetting.disabled.rawValue,
                soundSetting: UNNotificationSetting.disabled.rawValue,
                deliveredRequestIDs: []
            )
        }
        let settings: (authorization: Int, alert: Int, notificationCenter: Int, sound: Int) = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: (
                    settings.authorizationStatus.rawValue,
                    settings.alertSetting.rawValue,
                    settings.notificationCenterSetting.rawValue,
                    settings.soundSetting.rawValue
                ))
            }
        }
        let deliveredRequestIDs: [String] = await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications.map { $0.request.identifier }.sorted())
            }
        }
        return DiagnosticSnapshot(
            authorizationStatus: settings.authorization,
            alertSetting: settings.alert,
            notificationCenterSetting: settings.notificationCenter,
            soundSetting: settings.sound,
            deliveredRequestIDs: deliveredRequestIDs
        )
    }

    func requestAuthorization() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAuthorizationStatus() }
        }
    }

    func scheduleEventAlert(eventID: UUID, delay: TimeInterval? = nil) async throws {
        try await scheduleGenericAlert(
            id: "workpulse.event.\(eventID.uuidString)",
            title: "WorkPulse 需要你的处理",
            body: "一个任务正在等待操作。打开 WorkPulse 查看。",
            deepLink: URL(string: "workpulse://event/\(eventID.uuidString)")!,
            delay: delay
        )
    }

    func schedulePreview(id: String, delay: TimeInterval? = nil) async throws {
        try await scheduleGenericAlert(
            id: id,
            title: "WorkPulse 通知预览",
            body: "这是由你手动触发的本机预览，不代表真实 ChatGPT 任务状态。",
            deepLink: URL(string: "workpulse://notification-preview")!,
            delay: delay
        )
    }

    func scheduleQuotaAlert(id: String, detail: String) async throws {
        try await scheduleGenericAlert(
            id: "workpulse.quota.\(id)",
            title: "Codex 额度提醒",
            body: detail,
            deepLink: URL(string: "workpulse://usage")!,
            categoryIdentifier: "WORKPULSE_QUOTA"
        )
    }

    func scheduleTaskTerminalAlert(
        id: String,
        taskID: String,
        detail: String,
        outcome: CodexTaskTerminalOutcome
    ) async throws {
        guard let deepLink = URL(string: "workpulse://task/\(taskID)"),
              DeepLinkRouter.route(for: deepLink) == .task(taskID) else {
            throw WorkPulseNotificationError.invalidTaskIdentifier
        }
        let genericTitle = switch outcome {
        case .completed: "Codex 任务已完成"
        case .cancelled: "Codex 任务已取消"
        case .failed: "Codex 任务运行失败"
        case .aborted: "Codex 任务已中止"
        }
        try await scheduleGenericAlert(
            id: "workpulse.task-terminal.\(id)",
            title: genericTitle,
            body: detail,
            deepLink: deepLink,
            categoryIdentifier: "WORKPULSE_TASK_TERMINAL",
            extraUserInfo: ["taskOutcome": outcome.rawValue]
        )
    }

    private func scheduleGenericAlert(
        id: String,
        title: String,
        body: String,
        deepLink: URL,
        categoryIdentifier: String = "WORKPULSE_NEEDS_YOU",
        extraUserInfo: [String: String] = [:],
        delay: TimeInterval? = nil
    ) async throws {
        guard let center else { throw WorkPulseNotificationError.unavailableOutsideAppBundle }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = extraUserInfo.merging(["deepLink": deepLink.absoluteString]) { current, _ in current }
        let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false) }
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let raw = content.userInfo["deepLink"] as? String
        let title = content.title
        let body = content.body
        let taskOutcome = (content.userInfo["taskOutcome"] as? String)
            .flatMap(CodexTaskTerminalOutcome.init(rawValue:))
        let actionIdentifier = response.actionIdentifier
        let requestIdentifier = response.notification.request.identifier
        completionHandler()
        Task { @MainActor [weak self] in
            if actionIdentifier == UNNotificationDefaultActionIdentifier || actionIdentifier == "OPEN",
                      let raw,
                      let url = URL(string: raw) {
                self?.onOpenNotification?(
                    url,
                    title,
                    body,
                    taskOutcome,
                    ResponseContext(
                        requestIdentifier: requestIdentifier,
                        actionIdentifier: actionIdentifier
                    )
                )
            }
        }
    }
}

final class WorkPulseAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in NotificationCoordinator.shared.configure() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NotificationCenter.default.post(name: .workPulseDeepLink, object: url)
        }
    }
}
