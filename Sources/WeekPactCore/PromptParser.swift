import Foundation

public struct ParsedPlan {
    public var rules: [Rule]
    public var unparsed: [String]
    public init(rules: [Rule], unparsed: [String]) {
        self.rules = rules
        self.unparsed = unparsed
    }
}

/// A deliberately small, local interpreter. It never commits or silently ignores a clause.
public enum PromptParser {
    private static let services: [(String, [String])] = [
        ("youtube", ["youtube.com", "youtu.be"]),
        ("netflix", ["netflix.com"]),
        ("reddit", ["reddit.com"]),
        ("instagram", ["instagram.com"]),
        ("facebook", ["facebook.com"]),
        ("tiktok", ["tiktok.com"]),
        ("x.com", ["x.com", "twitter.com"])
    ]

    public static func parse(_ input: String) -> ParsedPlan {
        let separated = input.replacingOccurrences(of: ". ", with: "\n")
        let clauses = separated.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?"))) }
            .filter { !$0.isEmpty }
        var rules: [Rule] = []
        var unparsed: [String] = []
        for clause in clauses {
            guard let rule = parseClause(clause), !rules.contains(where: { $0.id == rule.id }) else {
                unparsed.append(clause)
                continue
            }
            rules.append(rule)
        }
        return ParsedPlan(rules: rules, unparsed: unparsed)
    }

    private static func parseClause(_ clause: String) -> Rule? {
        let lower = clause.lowercased()
        let found = services.first { service, _ in
            lower.range(of: "\\b" + NSRegularExpression.escapedPattern(for: service) + "\\b", options: .regularExpression) != nil
        }
        let domain = capture("\\b([a-z0-9-]+(?:\\.[a-z0-9-]+)+)\\b", in: lower)?.first
        guard let name = found?.0 ?? domain else { return nil }
        let domains = found?.1 ?? [name]

        var days = Set(Weekday.allCases)
        var hasDayQualifier = false
        if lower.contains("weekdays") || lower.contains("workdays") {
            hasDayQualifier = true
            days = [.monday, .tuesday, .wednesday, .thursday, .friday]
        } else if lower.contains("weekends") {
            hasDayQualifier = true
            days = [.saturday, .sunday]
        } else {
            let named = Weekday.allCases.filter { lower.contains($0.shortName.lowercased()) || lower.contains(String(describing: $0)) }
            if !named.isEmpty {
                hasDayQualifier = true
                days = Set(named)
            }
        }
        if lower.contains("monday through thursday") || lower.contains("mon-thu") {
            hasDayQualifier = true
            days = [.monday, .tuesday, .wednesday, .thursday]
        }

        if lower.contains("unblock") { return nil }
        let blocked = lower.contains("block") || lower.contains("never")
        if blocked {
            return Rule(id: name, domains: domains,
                        days: hasDayQualifier ? Set(Weekday.allCases).subtracting(days) : [],
                        windows: hasDayQualifier ? [TimeWindow(startMinute: 0, endMinute: 1440)] : [],
                        dailySeconds: nil)
        }

        var start = 0
        var end = 1440
        let after = capture("\\bafter\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)\\b", in: lower)
        let before = capture("\\bbefore\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)\\b", in: lower)
        if (lower.contains("after") && after == nil) || (lower.contains("before") && before == nil) { return nil }
        if let pair = after {
            guard let minute = clockMinute(pair) else { return nil }
            start = minute
        }
        if let pair = before {
            guard let minute = clockMinute(pair) else { return nil }
            end = minute
        }
        guard start < end else { return nil }

        var allowance: Int?
        if let value = capture("\\b(\\d+)\\s*(minutes?|mins?|hours?|hrs?)\\b", in: lower),
           let number = Int(value[0]) {
            allowance = number * (value[1].hasPrefix("h") ? 3600 : 60)
        }
        // Reject a seemingly quantitative request we cannot safely interpret.
        if lower.contains("minute") || lower.contains("hour") {
            guard allowance != nil else { return nil }
        }
        return Rule(id: name, domains: domains, days: days,
                    windows: [TimeWindow(startMinute: start, endMinute: end)], dailySeconds: allowance)
    }

    private static func capture(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }

    private static func clockMinute(_ values: [String]) -> Int? {
        guard let hour = Int(values[0]), (1...12).contains(hour),
              let minute = Int(values[1].isEmpty ? "0" : values[1]), (0...59).contains(minute) else { return nil }
        return (hour % 12 + (values[2] == "pm" ? 12 : 0)) * 60 + minute
    }
}
