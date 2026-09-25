import Foundation
import NetworkExtension
import SystemExtensions
import SwiftUI
import WeekPactCore

/// Activates Apple's signed, user-approved system content filter.
final class FilterSetupController: NSObject, ObservableObject, OSSystemExtensionRequestDelegate {
    @Published private(set) var status = "Filter inactive. A signed Xcode app is required."
    @Published private(set) var isEnabled = false

    private let extensionID = "com.pandeydeep9.WeekPact.Filter"
    private let extensionName = "WeekPactFilter.systemextension"

    override init() {
        super.init()
        refreshStatus()
    }

    func install() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            report("Run a signed WeekPactMac app from Xcode. `swift run` cannot install a system extension.")
            return
        }
        let embedded = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/SystemExtensions/\(extensionName)")
        guard FileManager.default.fileExists(atPath: embedded.path) else {
            report("The system extension is missing from the app bundle.")
            return
        }
        report("Requesting macOS system extension approval…")
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionID, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func refreshStatus() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                self.report("Filter status unavailable: \(error.localizedDescription)")
                self.setEnabled(false)
            } else {
                self.setEnabled(manager.isEnabled)
                self.report(manager.isEnabled ? "macOS filter enabled. Test coverage before relying on it."
                                              : "Filter inactive. Enable it before locking a service.")
            }
        }
    }

    func startShortTest() {
        guard isEnabled else { report("Enable the macOS filter before testing."); return }
        let rule = TemporaryDomainBlock(domain: "example.com", expiresAt: Date().addingTimeInterval(60))
        if SharedFilterTestRule.write(rule) {
            report("example.com should be blocked for 60 seconds. Try a new tab, then retry after it expires.")
        } else {
            report("Could not share the test rule with the system extension.")
        }
    }

    private func enableFilter() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                self.report("Cannot load filter configuration: \(error.localizedDescription)")
                return
            }
            let configuration = NEFilterProviderConfiguration()
            configuration.filterBrowsers = true
            configuration.filterSockets = true
            configuration.filterDataProviderBundleIdentifier = self.extensionID
            manager.providerConfiguration = configuration
            manager.localizedDescription = "WeekPact locked service limits"
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error {
                    self.report("Cannot enable macOS filter: \(error.localizedDescription)")
                } else {
                    self.setEnabled(true)
                    self.report("Filter enabled. Verify its browser coverage on this Mac.")
                }
            }
        }
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        report("Approve WeekPact in macOS System Settings, then return here.")
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if result == .willCompleteAfterReboot {
            report("macOS needs a restart to activate the extension. Reopen WeekPact afterward.")
        } else {
            report("Extension active. Enabling content filtering…")
            enableFilter()
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        report("Extension activation failed: \(error.localizedDescription)")
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    private func report(_ message: String) { DispatchQueue.main.async { self.status = message } }
    private func setEnabled(_ value: Bool) { DispatchQueue.main.async { self.isEnabled = value } }
}
