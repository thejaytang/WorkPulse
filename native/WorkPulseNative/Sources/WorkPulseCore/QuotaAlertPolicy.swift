import Foundation

public struct QuotaAlertCandidate: Equatable, Sendable {
    public let limitID: String
    public let displayName: String
    public let remainingPercent: Double
    public let windowDurationMinutes: Int
    public let resetsAt: Date
    public let cycleKey: String

    public var observationKey: String { "\(limitID)|\(cycleKey)" }

    public init(
        limitID: String,
        displayName: String,
        remainingPercent: Double,
        windowDurationMinutes: Int,
        resetsAt: Date,
        cycleKey: String
    ) {
        self.limitID = limitID
        self.displayName = displayName
        self.remainingPercent = remainingPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
        self.cycleKey = cycleKey
    }
}

public enum QuotaAlertPolicy {
    public static func candidates(
        buckets: [RateLimitBucketSnapshot],
        threshold: Int,
        alertedCycles: [String: String],
        previousRemainingByCycle: [String: Double]
    ) -> [QuotaAlertCandidate] {
        guard threshold > 0 else { return [] }
        return buckets.compactMap { bucket in
            let cycleKey = String(Int(bucket.resetsAt.timeIntervalSince1970.rounded()))
            let observationKey = "\(bucket.limitID)|\(cycleKey)"
            guard let previousRemaining = previousRemainingByCycle[observationKey],
                  previousRemaining > Double(threshold),
                  bucket.remainingPercent <= Double(threshold),
                  alertedCycles[bucket.limitID] != cycleKey else { return nil }
            return QuotaAlertCandidate(
                limitID: bucket.limitID,
                displayName: bucket.displayName ?? bucket.limitID,
                remainingPercent: bucket.remainingPercent,
                windowDurationMinutes: bucket.windowDurationMinutes,
                resetsAt: bucket.resetsAt,
                cycleKey: cycleKey
            )
        }
    }

    public static func observations(
        for buckets: [RateLimitBucketSnapshot]
    ) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: buckets.map { bucket in
            let cycleKey = String(Int(bucket.resetsAt.timeIntervalSince1970.rounded()))
            return ("\(bucket.limitID)|\(cycleKey)", bucket.remainingPercent)
        })
    }

    public static func recording(
        _ candidates: [QuotaAlertCandidate],
        in alertedCycles: [String: String]
    ) -> [String: String] {
        candidates.reduce(into: alertedCycles) { result, candidate in
            result[candidate.limitID] = candidate.cycleKey
        }
    }
}
