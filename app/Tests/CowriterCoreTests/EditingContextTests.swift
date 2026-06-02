import XCTest
@testable import CowriterCore

final class EditingContextTests: XCTestCase {
    func testTextSplitAtCaret() {
        let ctx = EditingContext(
            appBundleID: "com.apple.mail",
            fieldText: "Hello world",
            caretOffset: 5
        )
        XCTAssertEqual(ctx.textBeforeCaret, "Hello")
        XCTAssertEqual(ctx.textAfterCaret, " world")
    }

    func testCaretAtStart() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "abc", caretOffset: 0)
        XCTAssertEqual(ctx.textBeforeCaret, "")
        XCTAssertEqual(ctx.textAfterCaret, "abc")
    }

    func testCaretAtEnd() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "abc", caretOffset: 3)
        XCTAssertEqual(ctx.textBeforeCaret, "abc")
        XCTAssertEqual(ctx.textAfterCaret, "")
    }

    func testCaretOutOfBoundsIsClamped() {
        let ctx = EditingContext(appBundleID: "x", fieldText: "abc", caretOffset: 99)
        XCTAssertEqual(ctx.textBeforeCaret, "abc")
        XCTAssertEqual(ctx.textAfterCaret, "")
    }

    func testEmojiCaretOffsetUsesUTF16() {
        // "👋" is 2 UTF-16 code units; caret after it is offset 2.
        let ctx = EditingContext(appBundleID: "x", fieldText: "👋hi", caretOffset: 2)
        XCTAssertEqual(ctx.textBeforeCaret, "👋")
        XCTAssertEqual(ctx.textAfterCaret, "hi")
    }
}
