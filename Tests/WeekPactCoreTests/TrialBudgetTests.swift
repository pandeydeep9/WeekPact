import XCTest
@testable import WeekPactCore

final class TrialBudgetTests: XCTestCase {
    func testFiveMinutesRedirectsAtThresholdAndPersists() throws {
        var budget = TrialBudget(allowanceSeconds: 300, localDay: "2026-09-24")
        let youtube = URL(string: "https://www.youtube.com/watch?v=abc")!
        XCTAssertFalse(budget.observe(url: youtube, elapsedSeconds: 299, localDay: "2026-09-24"))
        XCTAssertFalse(budget.observe(url: URL(string: "https://example.com"), elapsedSeconds: 60, localDay: "2026-09-24"))
        XCTAssertEqual(budget.remainingSeconds, 1)
        XCTAssertTrue(budget.observe(url: youtube, elapsedSeconds: 1, localDay: "2026-09-24"))
        let restored = try JSONDecoder().decode(TrialBudget.self, from: JSONEncoder().encode(budget))
        XCTAssertTrue(restored.isExhausted)
        XCTAssertEqual(restored.usedSeconds, 300)
    }

    func testNewLocalDayStartsNewAllowance() {
        var budget = TrialBudget(allowanceSeconds: 300, localDay: "2026-09-24", usedSeconds: 300)
        XCTAssertFalse(budget.observe(url: URL(string: "https://m.youtube.com/shorts/abc"),
                                      elapsedSeconds: 2, localDay: "2026-09-25"))
        XCTAssertEqual(budget.remainingSeconds, 298)
    }

    func testHostnameCannotBeSpoofedBySuffix() {
        XCTAssertTrue(TrialBudget.isYouTube(URL(string: "https://youtu.be/abc")))
        XCTAssertFalse(TrialBudget.isYouTube(URL(string: "https://youtube.com.evil.example/")))
        XCTAssertFalse(TrialBudget.isYouTube(URL(string: "https://example.com/?next=youtube.com")))
    }

    func testNextResetUsesLocalMidnightAcrossDaylightSavingTime() {
        let formatter = ISO8601DateFormatter()
        let beforeSpringChange = formatter.date(from: "2026-03-08T09:00:00Z")!
        let springReset = TrialBudget.nextReset(after: beforeSpringChange, timeZoneID: "America/Los_Angeles")
        XCTAssertEqual(springReset, formatter.date(from: "2026-03-09T07:00:00Z"))
        let beforeFallChange = formatter.date(from: "2026-11-01T08:00:00Z")!
        let fallReset = TrialBudget.nextReset(after: beforeFallChange, timeZoneID: "America/Los_Angeles")
        XCTAssertEqual(fallReset, formatter.date(from: "2026-11-02T08:00:00Z"))
    }
}
