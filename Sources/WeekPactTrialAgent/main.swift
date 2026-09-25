import AppKit
import Foundation
import WeekPactCore

/// User-session experiment: continues the five-minute browser trial when its UI quits.
/// The UI remains the sole sampler while it runs, so foreground time is not counted twice.
final class BrowserTrialAgent {
    private var lastUptime = ProcessInfo.processInfo.systemUptime
    private var lastError = ""

    init() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.tick()
        }
    }

    private func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = min(2.5, max(0, uptime - lastUptime))
        lastUptime = uptime
        guard !appIsRunning(), var budget = TrialStateStore.read() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let day = formatter.string(from: .now)
        let browser = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var url: URL?
        if let browser, browser == "com.apple.Safari" || browser == "com.google.Chrome" {
            let tab = browser == "com.apple.Safari" ? "current tab" : "active tab"
            let script = """
            tell application id "\(browser)"
                if not (exists front window) then return ""
                return URL of \(tab) of front window
            end tell
            """
            let read = runAppleScript(script)
            if let error = read.error {
                if lastError != error {
                    fputs("WeekPact background trial cannot read browser: \(error)\n", stderr)
                    lastError = error
                }
                return
            }
            lastError = ""
            url = read.value.flatMap(URL.init(string:))
        }

        let before = budget
        let redirect = budget.observe(url: url, elapsedSeconds: url == nil ? 0 : elapsed, localDay: day)
        if before != budget && !TrialStateStore.write(budget) {
            fputs("WeekPact background trial could not save its budget.\n", stderr)
            return
        }
        guard redirect, let browser else { return }
        let tab = browser == "com.apple.Safari" ? "current tab" : "active tab"
        let script = """
        tell application id "\(browser)"
            if exists front window then set URL of \(tab) of front window to "about:blank"
        end tell
        """
        if let error = runAppleScript(script).error {
            fputs("WeekPact background trial could not redirect: \(error)\n", stderr)
        }
    }

    private func appIsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier &&
            ($0.bundleIdentifier == "com.pandeydeep9.WeekPact" ||
             $0.executableURL?.lastPathComponent == "WeekPactApp")
        }
    }

    private func runAppleScript(_ source: String) -> (value: String?, error: String?) {
        guard let script = NSAppleScript(source: source) else { return (nil, "Invalid script") }
        var failure: NSDictionary?
        let output = script.executeAndReturnError(&failure)
        if let failure {
            return (nil, failure["NSAppleScriptErrorMessage"] as? String ?? "Automation denied")
        }
        return (output.stringValue, nil)
    }
}

let agent = BrowserTrialAgent()
RunLoop.main.run()
