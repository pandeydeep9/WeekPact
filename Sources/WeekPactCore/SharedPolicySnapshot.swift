import Foundation

/// Transport for the unsigned feasibility prototype. It is not tamper-resistant.
public enum SharedPolicySnapshot {
    public static let suiteName = "group.com.pandeydeep9.WeekPact"
    private static let key = "policyBookV1"

    @discardableResult
    public static func write(_ book: PolicyBook) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(book) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    public static func read() -> PolicyBook? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PolicyBook.self, from: data)
    }
}
