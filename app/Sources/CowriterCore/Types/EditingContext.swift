import Foundation

/// A normalized snapshot of what the user is currently editing, produced by the
/// Text Monitor (Accessibility + event tap) and consumed by everything downstream.
///
/// This type is the boundary between the platform-specific capture layer and the
/// platform-agnostic suggestion logic. Nothing in `CowriterCore` reads the
/// Accessibility API directly; it only ever sees an `EditingContext`.
public struct EditingContext: Equatable, Sendable {
    /// Bundle identifier of the frontmost app, e.g. "com.tinyspeck.slackmacgap".
    public let appBundleID: String

    /// Human-readable app name, when available (for UI + tone heuristics).
    public let appName: String?

    /// The full text content of the focused field.
    public let fieldText: String

    /// Caret offset as a UTF-16 distance from the start of `fieldText`.
    /// (UTF-16 because that is what AppKit/Accessibility report.)
    public let caretOffset: Int

    /// True when the field is a secure/password field. The pipeline must never
    /// generate a suggestion when this is true.
    public let isSecure: Bool

    public init(
        appBundleID: String,
        appName: String? = nil,
        fieldText: String,
        caretOffset: Int,
        isSecure: Bool = false
    ) {
        self.appBundleID = appBundleID
        self.appName = appName
        self.fieldText = fieldText
        self.caretOffset = caretOffset
        self.isSecure = isSecure
    }

    /// Text before the caret, clamped to valid bounds.
    public var textBeforeCaret: String {
        let clamped = max(0, min(caretOffset, fieldText.utf16.count))
        guard let idx = utf16Index(clamped) else { return fieldText }
        return String(fieldText[..<idx])
    }

    /// Text after the caret, clamped to valid bounds.
    public var textAfterCaret: String {
        let clamped = max(0, min(caretOffset, fieldText.utf16.count))
        guard let idx = utf16Index(clamped) else { return "" }
        return String(fieldText[idx...])
    }

    private func utf16Index(_ utf16Offset: Int) -> String.Index? {
        guard let utf16Idx = fieldText.utf16.index(
            fieldText.utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: fieldText.utf16.endIndex
        ) else { return nil }
        return utf16Idx.samePosition(in: fieldText)
    }
}
