import Foundation

public enum LockedService: String, Codable, CaseIterable, Hashable, Identifiable {
    case youtube, netflix, facebook, messenger, instagram, reddit, quora

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized == "Youtube" ? "YouTube" : rawValue.capitalized }

    public var domains: [String] {
        switch self {
        case .youtube: return ["youtube.com", "youtu.be", "youtube-nocookie.com", "googlevideo.com", "ytimg.com"]
        case .netflix: return ["netflix.com", "nflxvideo.net"]
        case .facebook: return ["facebook.com", "fb.com", "fb.watch"]
        case .messenger: return ["messenger.com", "m.me"]
        case .instagram: return ["instagram.com"]
        case .reddit: return ["reddit.com", "redd.it"]
        case .quora: return ["quora.com"]
        }
    }

    public func matches(host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

public enum LimitClock {
    public static func nextMidnight(on weekday: Weekday, after now: Date, timeZoneID: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar.nextDate(after: now,
                                 matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: weekday.rawValue),
                                 matchingPolicy: .nextTime, direction: .forward)!
    }

    public static func localDay(_ date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct ServiceLimit: Codable, Equatable, Identifiable {
    public let service: LockedService
    public let dailySeconds: Int
    public let startsAt: Date
    public let endsAt: Date
    public let timeZoneID: String

    public var id: String { service.rawValue + "|" + startsAt.description }
    public func active(at date: Date) -> Bool { startsAt <= date && date < endsAt }
}

public enum LimitError: Error, LocalizedError {
    case emptySelection, invalidAllowance, activeRule(LockedService), invalidEnd

    public var errorDescription: String? {
        switch self {
        case .emptySelection: return "Select at least one service."
        case .invalidAllowance: return "Choose 30 minutes, 1 hour, 2 hours, or 3 hours."
        case .activeRule(let service): return "\(service.title) is already locked. Wait until its end time."
        case .invalidEnd: return "Choose a future day at midnight."
        }
    }
}

public struct LimitBook: Codable, Equatable {
    public private(set) var limits: [ServiceLimit] = []
    public init() {}

    public func active(at date: Date) -> [ServiceLimit] { limits.filter { $0.active(at: date) } }

    @discardableResult
    public mutating func commit(services: Set<LockedService>, dailySeconds: Int,
                                endWeekday: Weekday, now: Date, timeZoneID: String) throws -> Date {
        guard !services.isEmpty else { throw LimitError.emptySelection }
        guard [1800, 3600, 7200, 10800].contains(dailySeconds) else { throw LimitError.invalidAllowance }
        guard TimeZone(identifier: timeZoneID) != nil else { throw LimitError.invalidEnd }
        let end = LimitClock.nextMidnight(on: endWeekday, after: now, timeZoneID: timeZoneID)
        guard end > now else { throw LimitError.invalidEnd }
        for service in services {
            guard !active(at: now).contains(where: { $0.service == service }) else {
                throw LimitError.activeRule(service)
            }
        }
        limits.append(contentsOf: services.sorted { $0.rawValue < $1.rawValue }.map {
            ServiceLimit(service: $0, dailySeconds: dailySeconds,
                         startsAt: now, endsAt: end, timeZoneID: timeZoneID)
        })
        return end
    }

    /// Unknown or missing observations block only selected services. Other sites stay open.
    public func permits(host: String, sourceAppIdentifier: String?, at date: Date,
                        usage: UsageHeartbeat?) -> Bool {
        let matching = active(at: date).filter { $0.service.matches(host: host) }
        guard !matching.isEmpty else { return true }
        guard let usage, date.timeIntervalSince(usage.sampledAt) >= 0,
              date.timeIntervalSince(usage.sampledAt) <= 10 else { return false }
        return matching.allSatisfy { limit in
            usage.day == LimitClock.localDay(date, timeZoneID: limit.timeZoneID)
                && usage.observedBrowser == sourceAppIdentifier
                && usage.observedHost.map { limit.service.matches(host: $0) } == true
                && (usage.seconds[limit.service] ?? 0) < Double(limit.dailySeconds)
        }
    }
}

public struct UsageHeartbeat: Codable, Equatable {
    public let sampledAt: Date
    public let day: String
    public let seconds: [LockedService: Double]
    public let observedBrowser: String?
    public let observedHost: String?

    public init(sampledAt: Date, day: String, seconds: [LockedService: Double],
                observedBrowser: String?, observedHost: String?) {
        self.sampledAt = sampledAt
        self.day = day
        self.seconds = seconds
        self.observedBrowser = observedBrowser
        self.observedHost = observedHost
    }
}

/// Shared with the signed content filter. App Group files are not tamper-proof to an administrator.
public enum SharedLimitStore {
    private static let bookKey = "lockedLimitsV1"
    private static let usageKey = "lockedUsageV1"

    public static func readBook() -> LimitBook? { read(bookKey) }
    public static func readUsage() -> UsageHeartbeat? { read(usageKey) }

    @discardableResult
    public static func writeBook(_ book: LimitBook) -> Bool { write(book, key: bookKey) }
    @discardableResult
    public static func writeUsage(_ usage: UsageHeartbeat) -> Bool { write(usage, key: usageKey) }

    private static func read<T: Decodable>(_ key: String) -> T? {
        guard let bytes = UserDefaults(suiteName: SharedPolicySnapshot.suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: bytes)
    }

    private static func write<T: Encodable>(_ value: T, key: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: SharedPolicySnapshot.suiteName),
              let bytes = try? JSONEncoder().encode(value) else { return false }
        defaults.set(bytes, forKey: key)
        return true
    }
}
