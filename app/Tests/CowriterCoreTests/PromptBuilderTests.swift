import XCTest
@testable import CowriterCore

final class PromptBuilderTests: XCTestCase {
    let builder = PromptBuilder()

    func testNoPromptForSecureField() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "secret", caretOffset: 6, isSecure: true)
        XCTAssertNil(builder.makePrompt(for: ctx, length: .medium))
    }

    func testNoPromptForEmptyPrefix() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "   ", caretOffset: 0)
        XCTAssertNil(builder.makePrompt(for: ctx, length: .medium))
    }

    func testPromptIncludesContextAndLength() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "Thanks for", caretOffset: 10)
        let prompt = builder.makePrompt(for: ctx, length: .short)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.text.contains("Thanks for"))
        XCTAssertTrue(prompt!.text.lowercased().contains("short"))
    }

    func testToneInstructionAppears() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "Hey team", caretOffset: 8)
        let prompt = builder.makePrompt(for: ctx, length: .medium, toneInstruction: "casual and friendly")
        XCTAssertTrue(prompt!.text.contains("casual and friendly"))
    }

    func testFingerprintStableForSameInput() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "Hello there", caretOffset: 11)
        let a = builder.makePrompt(for: ctx, length: .medium)
        let b = builder.makePrompt(for: ctx, length: .medium)
        XCTAssertEqual(a!.fingerprint, b!.fingerprint)
    }

    func testFingerprintChangesWithLength() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "Hello there", caretOffset: 11)
        let a = builder.makePrompt(for: ctx, length: .medium)
        let b = builder.makePrompt(for: ctx, length: .long)
        XCTAssertNotEqual(a!.fingerprint, b!.fingerprint)
    }

    func testBeforeWindowIsBounded() {
        let long = String(repeating: "a", count: 5000)
        let ctx = EditingContext(appBundleID: "x", fieldText: long, caretOffset: long.utf16.count)
        let prompt = builder.makePrompt(for: ctx, length: .medium)!
        // The longest run of "a" (the included prefix) must be bounded by the
        // window. Counting all "a"s would also catch the header's letters.
        var longestRun = 0, run = 0
        for ch in prompt.text {
            if ch == "a" { run += 1; longestRun = max(longestRun, run) } else { run = 0 }
        }
        XCTAssertLessThanOrEqual(longestRun, builder.beforeWindow)
        XCTAssertEqual(longestRun, builder.beforeWindow)
    }
}
