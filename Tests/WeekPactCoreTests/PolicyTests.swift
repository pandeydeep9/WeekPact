import XCTest
@testable import WeekPactCore

final class PolicyTests: XCTestCase {
    private let zone = "America/Los_Angeles"
    private let allDays = Set(Weekday.allCases)

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func policy(_ start: String, rules: [Rule]) -> WeeklyPolicy {
        WeeklyPolicy(weekStart: date(start), timeZoneID: zone, rules: rules)
    }

    private func youtube(minutes: Int = 30, start: Int = 18 * 60, end: Int = 22 * 60) -> Rule {
        Rule(id: "youtube", domains: ["youtube.com"], days: allDays,
             windows: [TimeWindow(startMinute: start, endMinute: end)], dailySeconds: minutes * 60)
    }

    func testParserProducesReviewableRules() {
        let plan = PromptParser.parse("Next week, YouTube for 30 minutes a day after 6 PM. Netflix for 2 hours on Friday and Saturday. Block Reddit")
        XCTAssertEqual(plan.rules.count, 3)
        XCTAssertTrue(plan.unparsed.isEmpty)
        XCTAssertEqual(plan.rules[0].dailySeconds, 1800)
        XCTAssertEqual(plan.rules[0].windows[0].startMinute, 1080)
        XCTAssertEqual(plan.rules[1].days, [.friday, .saturday])
        XCTAssertEqual(plan.rules[2].days, [])
        XCTAssertFalse(PromptParser.parse("Allow social media after dinner").unparsed.isEmpty)
        XCTAssertFalse(PromptParser.parse("YouTube after dinner").unparsed.isEmpty)
        XCTAssertEqual(PromptParser.parse("Block example.com").rules.first?.domains, ["example.com"])
    }

    func testDomainAndAllowanceEnforcement() {
        let p = policy("2026-09-28T07:00:00Z", rules: [youtube()])
        let evening = date("2026-09-30T02:00:00Z") // Tuesday 7 PM PDT
        XCTAssertTrue(p.allows(host: "www.youtube.com", at: evening, usageSeconds: ["youtube": 1799]))
        XCTAssertFalse(p.allows(host: "youtube.com", at: evening, usageSeconds: ["youtube": 1800]))
        XCTAssertTrue(p.allows(host: "example.com", at: evening))
        XCTAssertTrue(p.allows(host: "notyoutube.com", at: evening))
        XCTAssertFalse(p.allows(host: "youtube.com", at: date("2026-09-29T18:00:00Z")))
    }

    func testTighteningChecksWholeWindowAndBudget() {
        XCTAssertTrue(PolicyComparison.isNoWeaker([youtube(minutes: 15)], than: [youtube()]))
        XCTAssertFalse(PolicyComparison.isNoWeaker([youtube(minutes: 60)], than: [youtube()]))
        XCTAssertFalse(PolicyComparison.isNoWeaker([youtube(minutes: 15, start: 17 * 60)], than: [youtube()]))
        XCTAssertFalse(PolicyComparison.isNoWeaker([], than: [youtube()]))
    }

    func testSevenDayDelayAndCarryForward() throws {
        var book = PolicyBook()
        let first = policy("2026-09-28T07:00:00Z", rules: [youtube()])
        XCTAssertEqual(try book.submit(first, now: date("2026-09-25T18:00:00Z")), .committed(first.weekStart))
        let relaxed = policy("2026-10-05T07:00:00Z", rules: [youtube(minutes: 60)])
        let result = try book.submit(relaxed, now: date("2026-09-30T18:00:00Z"))
        XCTAssertEqual(result, .scheduled(date("2026-10-12T07:00:00Z")))
        XCTAssertEqual(book.effective(at: date("2026-10-07T18:00:00Z"))?.rules[0].dailySeconds, 1800)
        XCTAssertEqual(book.effective(at: date("2026-10-13T18:00:00Z"))?.rules[0].dailySeconds, 3600)
    }

    func testCommittedWeekAcceptsOnlyTightening() throws {
        var book = PolicyBook()
        let start = "2026-09-28T07:00:00Z"
        _ = try book.submit(policy(start, rules: [youtube()]), now: date("2026-09-25T18:00:00Z"))
        XCTAssertEqual(try book.submit(policy(start, rules: [youtube(minutes: 15)]),
                                       now: date("2026-09-30T18:00:00Z")), .committed(date(start)))
        XCTAssertEqual(book.effective(at: date("2026-10-01T18:00:00Z"))?.rules[0].dailySeconds, 900)
    }

    func testWeekBoundaryAcrossDaylightSavingChange() {
        let before = date("2026-11-01T08:30:00Z")
        XCTAssertEqual(WeekClock.next(after: before, timeZoneID: zone), date("2026-11-02T08:00:00Z"))
    }
}
