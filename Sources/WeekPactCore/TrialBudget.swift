import Foundation

/// Small, editable trial state. This is separate from committed weekly policies.
public struct TrialBudget: Codable, Equatable {
    public let allowanceSeconds: Double
    public private(set) var usedSeconds: Double
    public private(set) var localDay: String

    public init(allowanceSeconds: Double, localDay: String, usedSeconds: Double = 0) {
        self.allowanceSeconds = allowanceSeconds
        self.localDay = localDay
        self.usedSeconds = usedSeconds
    }

    public var remainingSeconds: Double { max(0, allowanceSeconds - usedSeconds) }
    public var isExhausted: Bool { usedSeconds >= allowanceSeconds }

    /// Returns true when a foreground YouTube tab must be redirected now.
    @discardableResult
    public mutating func observe(url: URL?, elapsedSeconds: Double, localDay: String) -> Bool {
        if self.localDay != localDay {
            self.localDay = localDay
            usedSeconds = 0
        }
        guard Self.isYouTube(url) else { return false }
        usedSeconds = min(allowanceSeconds, usedSeconds + max(0, elapsedSeconds))
        return isExhausted
    }

    public static func isYouTube(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return ["youtube.com", "youtu.be", "youtube-nocookie.com"].contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }
}
