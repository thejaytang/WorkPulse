import Foundation

public struct DisplayPlacementCandidate: Equatable, Sendable {
    public let displayID: UInt32
    public let isBuiltIn: Bool
    public let hasNotch: Bool
    public let isMain: Bool

    public init(displayID: UInt32, isBuiltIn: Bool, hasNotch: Bool, isMain: Bool) {
        self.displayID = displayID
        self.isBuiltIn = isBuiltIn
        self.hasNotch = hasNotch
        self.isMain = isMain
    }
}

public enum DisplayPlacementPolicy {
    /// The overlay belongs to the physical Mac display, not to the screen under the pointer.
    /// External displays are only a fallback when the built-in display is unavailable (for
    /// example, clamshell mode).
    public static func preferredDisplayID(
        from candidates: [DisplayPlacementCandidate]
    ) -> UInt32? {
        candidates.first(where: { $0.isBuiltIn && $0.hasNotch })?.displayID
            ?? candidates.first(where: \.isBuiltIn)?.displayID
            ?? candidates.first(where: \.isMain)?.displayID
            ?? candidates.first?.displayID
    }
}
