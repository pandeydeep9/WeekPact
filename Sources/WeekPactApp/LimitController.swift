import Foundation
import ServiceManagement
import SwiftUI
import WeekPactCore

@MainActor
final class LimitController: ObservableObject {
    @Published private(set) var book = SharedLimitStore.readBook() ?? LimitBook()
    @Published private(set) var status = "Install and test the signed macOS filter before locking a service."

    func commit(services: Set<LockedService>, minutes: Int, endDay: Weekday,
                filterEnabled: Bool, usage: UsageController) -> Bool {
        guard filterEnabled else {
            status = "The macOS filter is not enabled. No rule was committed."
            return false
        }
        guard usage.isTracking else {
            status = "Resume local usage tracking before locking a daily allowance."
            return false
        }
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            status = "Use the signed WeekPactMac app; `swift run` cannot enforce a lock."
            return false
        }
        do {
            // Registration gives the sampler a chance to restart after login.
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            var updated = SharedLimitStore.readBook() ?? LimitBook()
            let date = try updated.commit(services: services, dailySeconds: minutes * 60,
                                          endWeekday: endDay, now: .now,
                                          timeZoneID: TimeZone.current.identifier)
            usage.refreshHeartbeat()
            guard SharedLimitStore.writeBook(updated) else {
                status = "Could not save the shared lock. No rule was committed."
                return false
            }
            book = updated
            status = "Locked through \(date.formatted(date: .abbreviated, time: .shortened)). Daily minutes refill at local midnight."
            return true
        } catch {
            status = "No rule was committed: \(error.localizedDescription)"
            return false
        }
    }

    func refresh() {
        book = SharedLimitStore.readBook() ?? LimitBook()
    }
}
