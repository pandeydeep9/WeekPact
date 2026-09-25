import XCTest
@testable import WeekPactCore

final class FixedLimitsTests: XCTestCase {
    private let zone = "America/Los_Angeles"
    private func time(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testStartsNowAndEndsNextMondayMidnight() throws {
        let thursday = time("2026-09-25T02:11:50Z")
        var book = LimitBook()
        let end = try book.commit(services: [.youtube, .reddit], dailySeconds: 1800,
                                  endWeekday: .monday, now: thursday, timeZoneID: zone)
        XCTAssertEqual(end, time("2026-09-28T07:00:00Z"))
        XCTAssertEqual(book.active(at: thursday).count, 2)
        XCTAssertTrue(book.active(at: end).isEmpty)
        XCTAssertThrowsError(try book.commit(services: [.youtube], dailySeconds: 10800,
                                             endWeekday: .sunday, now: thursday, timeZoneID: zone))
    }

    func testBudgetRefillsDailyButRuleDoesNotEnd() throws {
        let now = time("2026-09-25T02:11:50Z")
        var book = LimitBook()
        _ = try book.commit(services: [.youtube], dailySeconds: 1800,
                            endWeekday: .monday, now: now, timeZoneID: zone)
        let today = UsageHeartbeat(sampledAt: now, day: "2026-09-24", seconds: [.youtube: 1800],
                                   observedBrowser: "com.apple.Safari", observedHost: "youtube.com")
        XCTAssertFalse(book.permits(host: "www.youtube.com", sourceAppIdentifier: "com.apple.Safari", at: now, usage: today))
        XCTAssertTrue(book.permits(host: "example.com", sourceAppIdentifier: nil, at: now, usage: today))
        XCTAssertTrue(book.permits(host: "youtube.com.evil.example", sourceAppIdentifier: nil, at: now, usage: today))
        let tomorrow = time("2026-09-25T07:00:01Z")
        let fresh = UsageHeartbeat(sampledAt: tomorrow, day: "2026-09-25", seconds: [:],
                                   observedBrowser: "com.apple.Safari", observedHost: "youtube.com")
        XCTAssertTrue(book.permits(host: "youtube.com", sourceAppIdentifier: "com.apple.Safari", at: tomorrow, usage: fresh))
        XCTAssertFalse(book.permits(host: "youtube.com", sourceAppIdentifier: "org.mozilla.firefox", at: tomorrow, usage: fresh))
        XCTAssertFalse(book.permits(host: "youtube.com", sourceAppIdentifier: "com.apple.Safari", at: tomorrow, usage: today))
        XCTAssertFalse(book.permits(host: "youtube.com", sourceAppIdentifier: "com.apple.Safari", at: tomorrow, usage: nil))
    }

    func testHostGroupsAndDaylightSavingEnd() throws {
        XCTAssertTrue(LockedService.youtube.matches(host: "r2.googlevideo.com"))
        XCTAssertFalse(LockedService.youtube.matches(host: "fakegooglevideo.com"))
        let sunday = time("2026-11-01T08:30:00Z")
        XCTAssertEqual(LimitClock.nextMidnight(on: .monday, after: sunday, timeZoneID: zone),
                       time("2026-11-02T08:00:00Z"))
    }
}
