import XCTest
@testable import CowriterCore

final class SettingsStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("cowriter-test-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
    }

    func testLoadDefaultsWhenMissing() {
        let store = SettingsStore(fileURL: tempURL())
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveAndLoadRoundTrip() throws {
        let url = tempURL()
        let store = SettingsStore(fileURL: url)

        var settings = Settings.default
        settings.suggestionLength = .veryLong
        settings.activeModelID = "balanced"
        settings.launchAtLogin = true
        settings.perApp["com.tinyspeck.slackmacgap"] = AppSettings(enabled: false, toneInstruction: "concise")

        try store.save(settings)

        let reloaded = SettingsStore(fileURL: url).load()
        XCTAssertEqual(reloaded, settings)
        XCTAssertFalse(reloaded.isEnabled(forApp: "com.tinyspeck.slackmacgap"))
        XCTAssertEqual(reloaded.toneInstruction(forApp: "com.tinyspeck.slackmacgap"), "concise")
        XCTAssertTrue(reloaded.isEnabled(forApp: "com.unknown.app"))

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
