import Foundation

public enum WorkEventType: String, Codable, Hashable, Sendable {
    case needsApproval
    case needsInput
    case workLossRiskFailure
    case recoverableFailure
    case quotaPaused
    case longTaskCompleted
    case quotaCritical
    case sourceDisconnected
}

public enum DeliverySurface: String, Codable, Sendable {
    case inbox
    case menuBar
    case overlayAlert
    case notification
    case widget
}

public struct DeliveryContext: Equatable, Sendable {
    public var sourceIsFrontmost: Bool
    public var overlayEnabled: Bool
    public var overlayReachable: Bool
    public var notificationsAuthorized: Bool
    public var userIsActive: Bool

    public init(
        sourceIsFrontmost: Bool,
        overlayEnabled: Bool,
        overlayReachable: Bool,
        notificationsAuthorized: Bool,
        userIsActive: Bool
    ) {
        self.sourceIsFrontmost = sourceIsFrontmost
        self.overlayEnabled = overlayEnabled
        self.overlayReachable = overlayReachable
        self.notificationsAuthorized = notificationsAuthorized
        self.userIsActive = userIsActive
    }
}

public enum DeliveryPolicy {
    /// Chooses one interruption surface. A transient overlay is useful only
    /// while the user is actively at the Mac; otherwise it can appear and
    /// disappear unseen, so an authorized system notification is preferred.
    public static func preferredActiveSurface(context: DeliveryContext) -> DeliverySurface? {
        guard !context.sourceIsFrontmost else { return nil }
        if context.userIsActive, context.overlayEnabled, context.overlayReachable {
            return .overlayAlert
        }
        if context.notificationsAuthorized {
            return .notification
        }
        return nil
    }

    public static func surfaces(for event: WorkEventType, context: DeliveryContext) -> Set<DeliverySurface> {
        var result: Set<DeliverySurface> = [.menuBar]

        switch event {
        case .needsApproval, .needsInput, .workLossRiskFailure, .quotaPaused:
            result.insert(.inbox)
            if let surface = preferredActiveSurface(context: context) { result.insert(surface) }
        case .longTaskCompleted:
            result.insert(.inbox)
            if let surface = preferredActiveSurface(context: context) { result.insert(surface) }
        case .recoverableFailure:
            result.insert(.inbox)
        case .quotaCritical:
            result.insert(.widget)
        case .sourceDisconnected:
            result.insert(.inbox)
        }

        return result
    }
}
