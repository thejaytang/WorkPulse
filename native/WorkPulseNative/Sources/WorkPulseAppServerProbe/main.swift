import Foundation
import WorkPulseCore

@main
struct WorkPulseAppServerProbe {
    static func main() throws {
        let buckets = try CodexRateLimitReader.read()
        let tasks = try CodexRunningTaskReader.read()
        print("WorkPulse live probe passed: rateLimitBuckets=\(buckets.count); activeCodexTasks=\(tasks.count); values and names redacted")
    }
}
