import Foundation

/// An expiring test rule, deliberately separate from committed weekly policies.
public struct TemporaryDomainBlock: Codable, Equatable {
    public let domain: String
    public let expiresAt: Date

    public init(domain: String, expiresAt: Date) {
        self.domain = domain.lowercased()
        self.expiresAt = expiresAt
    }

    public func blocks(host: String, at date: Date) -> Bool {
        guard date < expiresAt else { return false }
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return host == domain || host.hasSuffix("." + domain)
    }
}

/// Shared App Group storage for a short manual filter test. This is editable state.
public enum SharedFilterTestRule {
    private static let key = "temporaryDomainBlockV1"

    public static func read() -> TemporaryDomainBlock? {
        guard let data = UserDefaults(suiteName: SharedPolicySnapshot.suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TemporaryDomainBlock.self, from: data)
    }

    @discardableResult
    public static func write(_ rule: TemporaryDomainBlock?) -> Bool {
        guard let defaults = UserDefaults(suiteName: SharedPolicySnapshot.suiteName) else { return false }
        if let rule {
            guard let data = try? JSONEncoder().encode(rule) else { return false }
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        return true
    }
}
