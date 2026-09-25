import Foundation
import NetworkExtension
import Security
import WeekPactCore

/// The signed system extension reads fixed commitments even when the UI is closed.
public final class WeekPactDataFilter: NEFilterDataProvider {
    public override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        if let host = hostname(for: flow),
           SharedFilterTestRule.read()?.blocks(host: host, at: .now) == true { return .drop() }
        guard let host = hostname(for: flow),
              let book = SharedLimitStore.readBook(),
              book.active(at: .now).contains(where: { $0.service.matches(host: host) }) else { return .allow() }
        guard book.permits(host: host, sourceAppIdentifier: signingIdentifier(for: flow),
                           at: .now, usage: SharedLimitStore.readUsage()) else { return .drop() }
        // Keep checking an already-open connection as its traffic arrives.
        return .filterDataVerdict(withFilterInbound: true, peekInboundBytes: 1,
                                  filterOutbound: true, peekOutboundBytes: 1)
    }

    public override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset: Int,
                                           readBytes: Data) -> NEFilterDataVerdict {
        verdict(for: flow, bytes: readBytes.count)
    }

    public override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset: Int,
                                            readBytes: Data) -> NEFilterDataVerdict {
        verdict(for: flow, bytes: readBytes.count)
    }

    private func verdict(for flow: NEFilterFlow, bytes: Int) -> NEFilterDataVerdict {
        guard let host = hostname(for: flow), let book = SharedLimitStore.readBook() else { return .allow() }
        guard book.permits(host: host, sourceAppIdentifier: signingIdentifier(for: flow),
                           at: .now, usage: SharedLimitStore.readUsage()) else { return .drop() }
        return NEFilterDataVerdict(passBytes: bytes, peekBytes: 1)
    }

    private func hostname(for flow: NEFilterFlow) -> String? {
        if let host = flow.url?.host { return host }
        return (flow as? NEFilterSocketFlow)?.remoteHostname
    }

    /// macOS exposes the source app's audit token, rather than sourceAppIdentifier.
    /// A missing or unresolvable token fails closed for selected services.
    private func signingIdentifier(for flow: NEFilterFlow) -> String? {
        guard let token = flow.sourceAppAuditToken else { return nil }
        var guest: SecCode?
        let attributes = [kSecGuestAttributeAudit: token] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &guest) == errSecSuccess,
              let guest else { return nil }
        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(guest, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &signingInfo) == errSecSuccess,
              let signingInfo = signingInfo as? [String: Any] else { return nil }
        return signingInfo[kSecCodeInfoIdentifier as String] as? String
    }
}
