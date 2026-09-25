import Foundation

/// Shared by the app and the optional per-user browser trial agent.
public enum TrialStateStore {
    public static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeekPact", isDirectory: true)
            .appendingPathComponent("youtube-trial.json")
    }

    public static func read() -> TrialBudget? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TrialBudget.self, from: data)
    }

    @discardableResult
    public static func write(_ budget: TrialBudget) -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(budget).write(to: fileURL, options: .atomic)
            return true
        } catch { return false }
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
