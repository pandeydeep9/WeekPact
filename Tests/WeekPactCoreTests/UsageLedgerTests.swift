import XCTest
@testable import WeekPactCore

final class UsageLedgerTests: XCTestCase {
    func testServiceMappingAndNoSpoofedDomains() {
        XCTAssertEqual(UsageLedger.site(for: URL(string: "https://www.youtube.com/watch?v=abc"))?.service, "YouTube")
        XCTAssertEqual(UsageLedger.site(for: URL(string: "https://www.facebook.com/messages/t/123"))?.service, "Messenger")
        XCTAssertEqual(UsageLedger.site(for: URL(string: "https://facebook.com/groups/test"))?.service, "Facebook")
        XCTAssertEqual(UsageLedger.site(for: URL(string: "https://quora.com/q"))?.service, "Quora")
        XCTAssertEqual(UsageLedger.site(for: URL(string: "https://youtube.com.evil.example"))?.service, "Other")
        XCTAssertNil(UsageLedger.site(for: URL(string: "file:///Users/deep/secret")))
    }

    func testLocalAggregationKeepsOnlySiteAndSeparatesDays() throws {
        let date = ISO8601DateFormatter().date(from: "2026-09-25T06:59:55Z")!
        var ledger = UsageLedger()
        let first = URL(string: "https://www.youtube.com/watch?v=private-search")!
        let next = URL(string: "https://www.youtube.com/shorts/something-else")!
        XCTAssertTrue(ledger.record(url: first, browser: "Chrome", seconds: 20, at: date,
                                    timeZoneID: "America/Los_Angeles", newSession: true))
        XCTAssertTrue(ledger.record(url: next, browser: "Chrome", seconds: 40, at: date.addingTimeInterval(60),
                                    timeZoneID: "America/Los_Angeles", newSession: false))
        XCTAssertEqual(ledger.buckets.count, 2) // Local midnight divides the two samples.
        XCTAssertEqual(ledger.report(last: 1, ending: date.addingTimeInterval(60),
                                     timeZoneID: "America/Los_Angeles").totalSeconds, 40)
        let saved = try JSONEncoder().encode(ledger)
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("private-search"))
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("something-else"))
        XCTAssertEqual(try JSONDecoder().decode(UsageLedger.self, from: saved), ledger)
    }
}
