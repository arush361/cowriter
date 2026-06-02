import XCTest
@testable import CowriterCore

final class SuggestionCoordinatorTests: XCTestCase {
    private func loadedEngine(delay: Duration = .zero) async -> MockInferenceEngine {
        let engine = MockInferenceEngine(perTokenDelay: delay)
        try? await engine.load(ModelRegistry.model(id: "small")!)
        return engine
    }

    func testProducesSuggestionForKnownOpener() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10)
        let s = await coordinator.requestSuggestion(for: ctx, settings: .default, pause: .active)
        XCTAssertNotNil(s)
        XCTAssertTrue(s!.text.contains("reaching out"))
    }

    func testGatedWhenPaused() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10)
        let future = Date().addingTimeInterval(3600)
        let s = await coordinator.requestSuggestion(for: ctx, settings: .default, pause: .pausedUntil(future))
        XCTAssertNil(s)
    }

    func testExpiredPauseBecomesActive() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10)
        let past = Date().addingTimeInterval(-3600)
        let s = await coordinator.requestSuggestion(for: ctx, settings: .default, pause: .pausedUntil(past))
        XCTAssertNotNil(s)
    }

    func testGatedWhenAppDisabled() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        var settings = Settings.default
        settings.perApp["com.apple.mail"] = AppSettings(enabled: false)
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10)
        let s = await coordinator.requestSuggestion(for: ctx, settings: settings, pause: .active)
        XCTAssertNil(s)
    }

    func testGatedForSecureField() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10, isSecure: true)
        let s = await coordinator.requestSuggestion(for: ctx, settings: .default, pause: .active)
        XCTAssertNil(s)
    }

    func testNoSuggestionWhenEngineHasNoCompletion() async {
        let engine = await loadedEngine()
        let coordinator = SuggestionCoordinator(engine: engine)
        // Ends with terminal punctuation -> mock returns nothing.
        let ctx = EditingContext(appBundleID: "com.apple.mail", fieldText: "All done.", caretOffset: 9)
        let s = await coordinator.requestSuggestion(for: ctx, settings: .default, pause: .active)
        XCTAssertNil(s)
    }

    func testInFlightRequestIsCancelledBySuperseding() async {
        // Slow engine so the first request is still running when the second arrives.
        let engine = await loadedEngine(delay: .milliseconds(50))
        let coordinator = SuggestionCoordinator(engine: engine)
        let ctx1 = EditingContext(appBundleID: "com.apple.mail", fieldText: "Thanks for", caretOffset: 10)
        let ctx2 = EditingContext(appBundleID: "com.apple.mail", fieldText: "Let me know", caretOffset: 11)

        async let first = coordinator.requestSuggestion(for: ctx1, settings: .default, pause: .active)
        // Give the first request a moment to start, then supersede it.
        try? await Task.sleep(for: .milliseconds(10))
        let second = await coordinator.requestSuggestion(for: ctx2, settings: .default, pause: .active)

        let firstResult = await first
        // The superseded request must not win; the second one returns its result.
        XCTAssertNotNil(second)
        XCTAssertTrue(second!.text.contains("questions"))
        // First was cancelled, so it returns nil.
        XCTAssertNil(firstResult)
    }
}
