import XCTest
@testable import CowriterCore

final class ModelRegistryTests: XCTestCase {
    func testLookupByID() {
        XCTAssertEqual(ModelRegistry.model(id: "qwen2.5-0.5b")?.tier, .small)
        XCTAssertNil(ModelRegistry.model(id: "nope"))
    }

    func testLowRAMGetsSmallModel() {
        // 4 GB machine.
        let rec = ModelRegistry.recommendedDefault(ramBytes: 4 * 1024 * 1024 * 1024)
        XCTAssertEqual(rec.tier, .small)
    }

    func testHighRAMGetsBalancedDefaultNotLarge() {
        // 32 GB machine: the large tier is opt-in only, so the default stays the
        // balanced model even when there is plenty of RAM.
        let rec = ModelRegistry.recommendedDefault(ramBytes: 32 * 1024 * 1024 * 1024)
        XCTAssertEqual(rec.tier, .medium)
        XCTAssertEqual(rec.id, "qwen2.5-1.5b")
    }

    func testEightGBMachineGetsBalancedDefault() {
        // 8 GB floor: medium needs ~6 GB headroom, which fits.
        let rec = ModelRegistry.recommendedDefault(ramBytes: 8 * 1024 * 1024 * 1024)
        XCTAssertEqual(rec.tier, .medium)
    }

    func testTinyRAMStillReturnsSomething() {
        // 1 GB: nothing is comfortably affordable, must still return smallest.
        let rec = ModelRegistry.recommendedDefault(ramBytes: 1 * 1024 * 1024 * 1024)
        XCTAssertEqual(rec.tier, .small)
    }
}

final class AppCompatibilityTests: XCTestCase {
    func testKnownAppProfile() {
        let mail = AppCompatibility.profile(for: "com.apple.mail")
        XCTAssertEqual(mail.name, "Mail")
        XCTAssertEqual(mail.support, .full)
    }

    func testUnknownAppDefaultsToOverlay() {
        let unknown = AppCompatibility.profile(for: "com.acme.whatever")
        XCTAssertEqual(unknown.support, .full)
        XCTAssertEqual(unknown.rendering, .overlay)
    }

    func testShouldEngageDefaultsTrue() {
        XCTAssertTrue(AppCompatibility.shouldEngage("com.acme.whatever"))
    }
}
