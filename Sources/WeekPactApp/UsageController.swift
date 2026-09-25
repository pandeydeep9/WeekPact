import AppKit
import Foundation
import WeekPactCore

/// Local foreground-tab sampler. Runs while the WeekPact process is alive.
@MainActor
final class UsageController: ObservableObject {
    @Published private(set) var ledger: UsageLedger
    @Published private(set) var generatedReport: UsageReport?
    @Published private(set) var status = "Watching foreground Safari and Chrome tabs while WeekPact runs."
    @Published private(set) var isTracking: Bool

    private let fileURL: URL
    private let enabledKey = "WeekPact.usageTrackingEnabled.v1"
    private var timer: Timer?
    private var lastUptime = ProcessInfo.processInfo.systemUptime
    private var previousSite: String?

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeekPact", isDirectory: true)
        fileURL = folder.appendingPathComponent("usage.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(UsageLedger.self, from: data) {
            ledger = saved
        } else {
            ledger = UsageLedger()
        }
        isTracking = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func setTracking(_ enabled: Bool) {
        isTracking = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        previousSite = nil
        lastUptime = ProcessInfo.processInfo.systemUptime
        status = enabled ? "Tracking resumed." : "Tracking paused. No website time is being saved."
    }

    func generateReport() {
        generatedReport = ledger.report(last: 7, ending: .now, timeZoneID: TimeZone.current.identifier)
    }

    var today: UsageReport {
        ledger.report(last: 1, ending: .now, timeZoneID: TimeZone.current.identifier)
    }

    private func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = min(2.5, max(0, uptime - lastUptime))
        lastUptime = uptime
        guard isTracking else { return }
        guard let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              bundle == "com.apple.Safari" || bundle == "com.google.Chrome" else {
            previousSite = nil
            return
        }
        let browser = bundle == "com.apple.Safari" ? "Safari" : "Chrome"
        let tab = bundle == "com.apple.Safari" ? "current tab" : "active tab"
        let script = """
        tell application id "\(bundle)"
            if not (exists front window) then return ""
            return URL of \(tab) of front window
        end tell
        """
        guard let automation = NSAppleScript(source: script) else { return }
        var failure: NSDictionary?
        let result = automation.executeAndReturnError(&failure)
        if failure != nil {
            previousSite = nil
            status = "Cannot read \(browser)'s front tab. Check macOS Automation permission; private windows may need separate coverage."
            return
        }
        let url = result.stringValue.flatMap(URL.init(string:))
        guard let site = UsageLedger.site(for: url) else {
            previousSite = nil
            status = "No readable website in \(browser)'s front tab. Unreadable tabs are not counted."
            return
        }
        let key = "\(browser)|\(site.service)|\(site.host)"
        guard ledger.record(url: url, browser: browser, seconds: elapsed, at: .now,
                            timeZoneID: TimeZone.current.identifier, newSession: previousSite != key) else { return }
        previousSite = key
        status = "Counting \(site.service == "Other" ? site.host : site.service) in \(browser)."
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(ledger).write(to: fileURL, options: .atomic)
        } catch {
            status = "Could not save local usage: \(error.localizedDescription)"
        }
    }
}
