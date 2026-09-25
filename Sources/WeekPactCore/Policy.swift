import Foundation

public enum Weekday: Int, Codable, CaseIterable, Hashable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }
    public var shortName: String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][rawValue - 1]
    }
    public var fullName: String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][rawValue - 1]
    }
    public static let ordered: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}

public struct TimeWindow: Codable, Equatable, Hashable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public func contains(_ minute: Int) -> Bool {
        startMinute <= minute && minute < endMinute
    }
}

public struct Rule: Codable, Equatable, Identifiable {
    public var id: String
    public var domains: [String]
    public var days: Set<Weekday>
    public var windows: [TimeWindow]
    public var dailySeconds: Int?

    public init(id: String, domains: [String], days: Set<Weekday>, windows: [TimeWindow], dailySeconds: Int? = nil) {
        self.id = id
        self.domains = domains
        self.days = days
        self.windows = windows
        self.dailySeconds = dailySeconds
    }

    public func matches(host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domains.contains { domain in
            let domain = domain.lowercased()
            return host == domain || host.hasSuffix("." + domain)
        }
    }

    public func permits(day: Weekday, minute: Int, usedSeconds: Int) -> Bool {
        days.contains(day) && windows.contains(where: { $0.contains(minute) })
            && (dailySeconds.map { usedSeconds < $0 } ?? true)
    }
}

public struct WeeklyPolicy: Codable, Equatable, Identifiable {
    public var id: UUID
    public var weekStart: Date
    public var timeZoneID: String
    public var rules: [Rule]
    public var committedAt: Date

    public init(id: UUID = UUID(), weekStart: Date, timeZoneID: String, rules: [Rule], committedAt: Date = .now) {
        self.id = id
        self.weekStart = weekStart
        self.timeZoneID = timeZoneID
        self.rules = rules
        self.committedAt = committedAt
    }

    public func allows(host: String, at date: Date, usageSeconds: [String: Int] = [:]) -> Bool {
        let matching = rules.filter { $0.matches(host: host) }
        guard !matching.isEmpty else { return true }
        let calendar = WeekClock.calendar(timeZoneID: timeZoneID)
        guard let day = Weekday(rawValue: calendar.component(.weekday, from: date)) else { return false }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return matching.allSatisfy { $0.permits(day: day, minute: minute, usedSeconds: usageSeconds[$0.id] ?? 0) }
    }
}

public enum WeekClock {
    public static func calendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    public static func start(containing date: Date, timeZoneID: String) -> Date {
        let calendar = calendar(timeZoneID: timeZoneID)
        return calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }

    public static func next(after date: Date, timeZoneID: String) -> Date {
        let calendar = calendar(timeZoneID: timeZoneID)
        return calendar.date(byAdding: .weekOfYear, value: 1, to: start(containing: date, timeZoneID: timeZoneID))!
    }

    public static func display(_ date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        return formatter.string(from: date)
    }
}

public enum PolicyError: Error, Equatable, LocalizedError {
    case invalidWeek
    case pastWeek
    case invalidRule(String)
    case timeZoneChanged

    public var errorDescription: String? {
        switch self {
        case .invalidWeek: return "Choose a Monday at midnight in the policy time zone."
        case .pastWeek: return "A past week cannot be changed."
        case .invalidRule(let message): return message
        case .timeZoneChanged: return "Keep the same time zone for committed rules."
        }
    }
}

public enum Submission: Equatable {
    case committed(Date)
    case scheduled(Date)
}

public struct PolicyBook: Codable {
    public private(set) var policies: [WeeklyPolicy]

    public init(policies: [WeeklyPolicy] = []) { self.policies = policies }

    public func effective(at date: Date) -> WeeklyPolicy? {
        policies.filter { $0.weekStart <= date }
            .max {
                if $0.weekStart != $1.weekStart { return $0.weekStart < $1.weekStart }
                return $0.committedAt < $1.committedAt
            }
    }

    public mutating func submit(_ candidate: WeeklyPolicy, now: Date) throws -> Submission {
        let zone = candidate.timeZoneID
        guard TimeZone(identifier: zone) != nil else { throw PolicyError.invalidRule("Select a valid time zone.") }
        guard policies.allSatisfy({ $0.timeZoneID == zone }) else { throw PolicyError.timeZoneChanged }
        guard WeekClock.start(containing: candidate.weekStart, timeZoneID: zone) == candidate.weekStart else {
            throw PolicyError.invalidWeek
        }
        let thisWeek = WeekClock.start(containing: now, timeZoneID: zone)
        guard candidate.weekStart >= thisWeek else { throw PolicyError.pastWeek }
        try validate(candidate)

        let previous = effective(at: candidate.weekStart)
            ?? effective(at: candidate.weekStart.addingTimeInterval(-1))
        var committed = candidate
        committed.committedAt = now
        if let previous, !PolicyComparison.isNoWeaker(candidate.rules, than: previous.rules) {
            let earliest = earliestRelaxationWeek(after: now, timeZoneID: zone)
            // A future committed week is immutable unless the new policy tightens it.
            var target = max(earliest, candidate.weekStart)
            while policies.contains(where: { $0.weekStart == target }) {
                target = WeekClock.next(after: target, timeZoneID: zone)
            }
            committed.weekStart = target
            policies.append(committed)
            return .scheduled(target)
        }
        policies.append(committed)
        // A new tightening must not be silently undone by an older queued relaxation.
        let earliest = earliestRelaxationWeek(after: now, timeZoneID: zone)
        for index in policies.indices where policies[index].id != committed.id {
            let future = policies[index]
            guard future.weekStart > committed.weekStart, future.weekStart < earliest,
                  !PolicyComparison.isNoWeaker(future.rules, than: committed.rules) else { continue }
            var destination = earliest
            while policies.contains(where: { $0.weekStart == destination }) {
                destination = WeekClock.next(after: destination, timeZoneID: zone)
            }
            policies[index].weekStart = destination
        }
        return .committed(candidate.weekStart)
    }

    private func earliestRelaxationWeek(after now: Date, timeZoneID: String) -> Date {
        let end = now.addingTimeInterval(7 * 24 * 60 * 60)
        let start = WeekClock.start(containing: end, timeZoneID: timeZoneID)
        return start < end ? WeekClock.next(after: end, timeZoneID: timeZoneID) : start
    }

    private func validate(_ policy: WeeklyPolicy) throws {
        var identifiers = Set<String>()
        for rule in policy.rules {
            guard !rule.id.isEmpty, identifiers.insert(rule.id).inserted else {
                throw PolicyError.invalidRule("Each service needs a unique name.")
            }
            guard !rule.domains.isEmpty, rule.domains.allSatisfy({ !$0.isEmpty && !$0.contains("/") && !$0.contains(" ") }) else {
                throw PolicyError.invalidRule("Enter domain names without paths or spaces.")
            }
            guard rule.dailySeconds == nil || rule.dailySeconds! >= 0 else {
                throw PolicyError.invalidRule("Daily allowances cannot be negative.")
            }
            guard rule.windows.allSatisfy({ 0 <= $0.startMinute && $0.startMinute < $0.endMinute && $0.endMinute <= 1440 }) else {
                throw PolicyError.invalidRule("Each time window must fit within one day.")
            }
        }
    }
}

public enum PolicyComparison {
    // Deliberately conservative: a safe change may be deferred, but a newly permitted
    // minute, domain, or allowance must never be accepted as a tightening.
    public static func isNoWeaker(_ candidate: [Rule], than prior: [Rule]) -> Bool {
        prior.allSatisfy { old in
            guard let new = candidate.first(where: { $0.id == old.id }) else { return false }
            let domainsCovered = old.domains.allSatisfy { oldDomain in
                new.domains.contains { newDomain in
                    oldDomain == newDomain || oldDomain.hasSuffix("." + newDomain)
                }
            }
            let budgetCovered: Bool
            switch (old.dailySeconds, new.dailySeconds) {
            case (nil, _): budgetCovered = true
            case (let oldLimit?, let newLimit?): budgetCovered = newLimit <= oldLimit
            default: budgetCovered = false
            }
            let timeCovered = Weekday.allCases.allSatisfy { day in
                (0..<1440).allSatisfy { minute in
                    !new.permits(day: day, minute: minute, usedSeconds: 0)
                        || old.permits(day: day, minute: minute, usedSeconds: 0)
                }
            }
            return domainsCovered && budgetCovered && timeCovered
        }
    }
}
