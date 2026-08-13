import Foundation

public enum ExternalAlertUrgency: String, Codable, Sendable {
    case active
    case passive
}

public struct ExternalAlertPayload: Codable, Equatable, Sendable {
    public let eventID: UUID
    public let surface: DeliverySurface
    public let title: String
    public let body: String
    public let primaryActionLabel: String
    public let secondaryActionLabel: String?
    public let deepLink: URL
    public let urgency: ExternalAlertUrgency

    public init(
        eventID: UUID,
        surface: DeliverySurface,
        title: String,
        body: String,
        primaryActionLabel: String,
        secondaryActionLabel: String?,
        deepLink: URL,
        urgency: ExternalAlertUrgency
    ) {
        self.eventID = eventID
        self.surface = surface
        self.title = title
        self.body = body
        self.primaryActionLabel = primaryActionLabel
        self.secondaryActionLabel = secondaryActionLabel
        self.deepLink = deepLink
        self.urgency = urgency
    }
}

public enum ExternalAlertPayloadFactory {
    public static func make(
        eventID: UUID,
        type: WorkEventType,
        surface: DeliverySurface
    ) -> ExternalAlertPayload? {
        guard surface == .overlayAlert || surface == .notification,
              let deepLink = URL(string: "workpulse://event/\(eventID.uuidString)") else {
            return nil
        }

        let urgency: ExternalAlertUrgency = switch type {
        case .needsApproval, .needsInput, .workLossRiskFailure, .quotaPaused:
            .active
        case .recoverableFailure, .longTaskCompleted, .quotaCritical, .sourceDisconnected:
            .passive
        }

        return ExternalAlertPayload(
            eventID: eventID,
            surface: surface,
            title: "WorkPulse 需要你的处理",
            body: "一个任务正在等待操作。打开 WorkPulse 查看。",
            primaryActionLabel: "查看提醒",
            secondaryActionLabel: surface == .overlayAlert ? "稍后" : nil,
            deepLink: deepLink,
            urgency: urgency
        )
    }
}
