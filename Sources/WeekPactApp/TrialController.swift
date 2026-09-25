import AppKit
import Foundation
import SwiftUI
import WeekPactCore

/// Browser-automation trial. It is intentionally separate from the committed policy store.
@MainActor
final class TrialController: ObservableObject {
    @Published var instruction = "YouTube 5 minutes per day"
    @Published private(set) var status = "Enter the instruction above to try a five-minute limit."
    @Published private(set) var remainingSeconds: Double = 300
    @Published private(set) var isRunning = false

    private let storageKey = "WeekPact.youtubeTrial.v1"
    private var budget: TrialBudget?
    private var timer: Timer?
    private var lastUptime = ProcessInfo.processInfo.systemUptime

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(TrialBudget.self, from: data) {
            budget = saved
            remainingSeconds = saved.remainingSeconds
            isRunning = true
            status = "Trial resumed. Keep WeekPact running for the block to work."
            scheduleTimer()
        }
    }

    func start() {
        let parsed = PromptParser.parse(instruction)
        guard parsed.unparsed.isEmpty, parsed.rules.count == 1,
              let rule = parsed.rules.first, rule.id == "youtube", rule.dailySeconds == 300,
              rule.days == Set(Weekday.allCases),
              rule.windows == [TimeWindow(startMinute: 0, endMinute: 1440)] else {
            status = "For this test, enter exactly: YouTube 5 minutes per day"
            return
        }
        guard !isRunning else {
            status = "The trial is already running. Starting again will not reset its timer."
            return
        }
        budget = TrialBudget(allowanceSeconds: 300, localDay: Self.localDay())
        remainingSeconds = 300
        isRunning = true
        status = "Trial running. Chrome and Safari may ask for Automation permission."
        persist()
        scheduleTimer()
    }

    private func scheduleTimer() {
        lastUptime = ProcessInfo.processInfo.systemUptime
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard var budget else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(2.5, max(0, now - lastUptime))
        lastUptime = now
        let day = Self.localDay()

        let browser = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard browser == "com.google.Chrome" || browser == "com.apple.Safari" else {
            _ = budget.observe(url: nil, elapsedSeconds: 0, localDay: day)
            update(budget)
            return
        }
        guard let browser else { return }
        let read = appleScript(urlScript(for: browser))
        if let error = read.error {
            status = "Browser access failed: \(error). Allow Automation for WeekPact in System Settings."
            return
        }
        let url = read.value.flatMap(URL.init(string:))
        let redirect = budget.observe(url: url, elapsedSeconds: elapsed, localDay: day)
        update(budget)
        if redirect {
            let result = appleScript(redirectScript(for: browser))
            status = result.error.map { "Limit reached, but redirect failed: \($0)" }
                ?? "Five minutes used. YouTube was redirected for today."
        } else if TrialBudget.isYouTube(url) {
            status = "Counting foreground YouTube time in \(browser == "com.apple.Safari" ? "Safari" : "Chrome")."
        }
    }

    private func update(_ value: TrialBudget) {
        budget = value
        remainingSeconds = value.remainingSeconds
        persist()
    }

    private func persist() {
        guard let budget, let data = try? JSONEncoder().encode(budget) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func localDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: .now)
    }

    private func urlScript(for bundleID: String) -> String {
        let tab = bundleID == "com.apple.Safari" ? "current tab" : "active tab"
        return """
        tell application id "\(bundleID)"
            if not (exists front window) then return ""
            return URL of \(tab) of front window
        end tell
        """
    }

    private func redirectScript(for bundleID: String) -> String {
        let tab = bundleID == "com.apple.Safari" ? "current tab" : "active tab"
        return """
        tell application id "\(bundleID)"
            if not (exists front window) then return ""
            set URL of \(tab) of front window to "about:blank"
        end tell
        """
    }

    private func appleScript(_ source: String) -> (value: String?, error: String?) {
        guard let script = NSAppleScript(source: source) else { return (nil, "Script could not be created") }
        var failure: NSDictionary?
        let output = script.executeAndReturnError(&failure)
        if let failure {
            return (nil, failure["NSAppleScriptErrorMessage"] as? String ?? "Automation permission denied")
        }
        return (output.stringValue, nil)
    }
}
