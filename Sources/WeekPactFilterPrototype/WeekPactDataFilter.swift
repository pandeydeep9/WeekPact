import Foundation
import NetworkExtension
import WeekPactCore

/// Compile-time feasibility spike. The packaged system extension still needs
/// signing, activation, coverage testing, and trusted policy storage.
public final class WeekPactDataFilter: NEFilterDataProvider {
    public override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let host = hostname(for: flow),
              let policy = SharedPolicySnapshot.read()?.effective(at: .now) else {
            // No trustworthy policy snapshot: this prototype cannot promise a lock.
            return .allow()
        }
        // Usage counting is not connected yet. A budgeted service must not get
        // unlimited access merely because the counter is unavailable.
        if policy.rules.contains(where: { $0.matches(host: host) && $0.dailySeconds != nil }) {
            return .drop()
        }
        return policy.allows(host: host, at: .now) ? .allow() : .drop()
    }

    private func hostname(for flow: NEFilterFlow) -> String? {
        if let host = flow.url?.host { return host }
        return (flow as? NEFilterSocketFlow)?.remoteHostname
    }
}
