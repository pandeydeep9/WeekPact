import XCTest
@testable import WeekPactCore

final class TemporaryDomainBlockTests: XCTestCase {
    func testOnlyTargetDomainBlocksUntilExpiry() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rule = TemporaryDomainBlock(domain: "example.com", expiresAt: now.addingTimeInterval(60))
        XCTAssertTrue(rule.blocks(host: "example.com", at: now))
        XCTAssertTrue(rule.blocks(host: "www.example.com", at: now.addingTimeInterval(59)))
        XCTAssertFalse(rule.blocks(host: "example.com.evil.test", at: now))
        XCTAssertFalse(rule.blocks(host: "another.test", at: now))
        XCTAssertFalse(rule.blocks(host: "example.com", at: now.addingTimeInterval(60)))
        let restored = try JSONDecoder().decode(TemporaryDomainBlock.self, from: JSONEncoder().encode(rule))
        XCTAssertEqual(restored, rule)
    }
}
