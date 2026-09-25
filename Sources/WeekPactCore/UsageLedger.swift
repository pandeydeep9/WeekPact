import Foundation

public struct UsageBucket: Codable, Equatable, Identifiable {
    public var day: String
    public var site: String
    public var service: String
    public var browser: String
    public var seconds: Double
    public var sessions: Int
    public var lastSeen: Date

    public var id: String { "\(day)|\(site)|\(service)|\(browser)" }
}

public struct UsageLedger: Codable, Equatable {
    public private(set) var buckets: [UsageBucket] = []

    public init() {}

    @discardableResult
    public mutating func record(url: URL?, browser: String, seconds: Double, at date: Date,
                                timeZoneID: String, newSession: Bool) -> Bool {
        guard let site = Self.site(for: url), seconds > 0 else { return false }
        let day = Self.localDay(date, timeZoneID: timeZoneID)
        if let index = buckets.firstIndex(where: { $0.day == day && $0.site == site.host
                                               && $0.service == site.service && $0.browser == browser }) {
            buckets[index].seconds += seconds
            if newSession { buckets[index].sessions += 1 }
            buckets[index].lastSeen = date
        } else {
            buckets.append(UsageBucket(day: day, site: site.host, service: site.service,
                                       browser: browser, seconds: seconds, sessions: 1, lastSeen: date))
        }
        return true
    }

    public func report(last days: Int, ending date: Date, timeZoneID: String) -> UsageReport {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let start = calendar.date(byAdding: .day, value: -(max(1, days) - 1),
                                  to: calendar.startOfDay(for: date))!
        let included = buckets.filter { bucket in
            guard let bucketDate = Self.date(bucket.day, timeZoneID: timeZoneID) else { return false }
            return bucketDate >= start && bucketDate <= date
        }
        let grouped: [String: [UsageBucket]] = Dictionary(grouping: included) { bucket in
            bucket.service + "|" + bucket.site
        }
        var sites: [UsageReportRow] = []
        for items in grouped.values {
            let seconds = items.reduce(0.0) { $0 + $1.seconds }
            let sessions = items.reduce(0) { $0 + $1.sessions }
            sites.append(UsageReportRow(site: items[0].site, service: items[0].service,
                                        seconds: seconds, sessions: sessions))
        }
        sites.sort { $0.seconds == $1.seconds ? $0.site < $1.site : $0.seconds > $1.seconds }
        return UsageReport(start: start, end: date, sites: sites)
    }

    public static func site(for url: URL?) -> (host: String, service: String)? {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty else { return nil }
        let normalized = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        func matches(_ domain: String) -> Bool {
            normalized == domain || normalized.hasSuffix("." + domain)
        }
        let service: String
        if matches("youtube.com") || matches("youtu.be") || matches("youtube-nocookie.com") {
            service = "YouTube"
        } else if matches("netflix.com") {
            service = "Netflix"
        } else if matches("messenger.com") || matches("m.me")
                    || (matches("facebook.com") && url.path.lowercased().hasPrefix("/messages")) {
            service = "Messenger"
        } else if matches("facebook.com") || matches("fb.com") || matches("fb.watch") {
            service = "Facebook"
        } else if matches("instagram.com") {
            service = "Instagram"
        } else if matches("reddit.com") || matches("redd.it") {
            service = "Reddit"
        } else if matches("quora.com") {
            service = "Quora"
        } else {
            service = "Other"
        }
        // Store the hostname only. Paths, searches, and page titles never enter the ledger.
        return (normalized, service)
    }

    private static func localDay(_ date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func date(_ day: String, timeZoneID: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day)
    }
}

public struct UsageReportRow: Equatable, Identifiable {
    public let site: String
    public let service: String
    public let seconds: Double
    public let sessions: Int
    public var id: String { "\(service)|\(site)" }
}

public struct UsageReport: Equatable {
    public let start: Date
    public let end: Date
    public let sites: [UsageReportRow]
    public var totalSeconds: Double { sites.reduce(0) { $0 + $1.seconds } }
}
