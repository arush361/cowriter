import XCTest
@testable import CowriterCore

final class PauseStateTests: XCTestCase {
    func testActiveIsAlwaysActive() {
        XCTAssertTrue(PauseState.active.isActive(now: Date()))
    }

    func testIndefiniteIsNeverActive() {
        XCTAssertFalse(PauseState.pausedIndefinitely.isActive(now: Date()))
    }

    func testPausedUntilFutureIsInactive() {
        let now = Date()
        let state = PauseState.pausedUntil(now.addingTimeInterval(60))
        XCTAssertFalse(state.isActive(now: now))
    }

    func testPausedUntilPastIsActive() {
        let now = Date()
        let state = PauseState.pausedUntil(now.addingTimeInterval(-60))
        XCTAssertTrue(state.isActive(now: now))
    }

    func testThirtyMinutesDuration() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let state = PauseState.from(.thirtyMinutes, now: now)
        XCTAssertEqual(state, .pausedUntil(now.addingTimeInterval(1800)))
    }

    func testUntilTomorrowIsStartOfNextDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 2021-01-01 10:00 UTC
        let now = Date(timeIntervalSince1970: 1_609_495_200)
        let state = PauseState.from(.untilTomorrow, now: now, calendar: cal)
        // Expect start of 2021-01-02 UTC = 1_609_545_600
        XCTAssertEqual(state, .pausedUntil(Date(timeIntervalSince1970: 1_609_545_600)))
    }

    func testIndefiniteDuration() {
        XCTAssertEqual(PauseState.from(.indefinitely, now: Date()), .pausedIndefinitely)
    }
}
