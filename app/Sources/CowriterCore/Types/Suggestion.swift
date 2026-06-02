import Foundation

/// The result of an inference request: the text to show as ghost text, plus
/// the context fingerprint it was generated for (used by the dedupe cache).
public struct Suggestion: Equatable, Sendable {
    /// The continuation text to render at the caret. Never includes the
    /// already-typed prefix.
    public let text: String

    /// A stable hash of the prompt this was generated for. Lets the coordinator
    /// avoid re-requesting an identical suggestion.
    public let contextFingerprint: Int

    public init(text: String, contextFingerprint: Int) {
        self.text = text
        self.contextFingerprint = contextFingerprint
    }

    /// A suggestion is only worth showing if it has non-whitespace content.
    public var isPresentable: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Errors the inference layer can surface. Kept small and engine-agnostic.
public enum InferenceError: Error, Equatable, Sendable {
    case cancelled
    case modelNotLoaded
    case contextTooLong
    case backendFailure(String)
}
