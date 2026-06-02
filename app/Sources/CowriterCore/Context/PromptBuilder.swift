import Foundation

/// Turns an `EditingContext` plus settings into the prompt string handed to the
/// inference engine, and produces a stable fingerprint for the dedupe cache.
///
/// Design notes:
/// - We include a bounded window of text *before* the caret (the model completes
///   forward). A little text *after* the caret is included as light conditioning
///   when present (e.g. the user is editing mid-paragraph).
/// - Per-app tone instructions and the global length setting are folded in.
/// - The window is measured in characters as a proxy for the model's context
///   budget; the real backends can re-tokenize, but this keeps prompts small.
public struct PromptBuilder: Sendable {
    /// Max characters of pre-caret context to include.
    public let beforeWindow: Int
    /// Max characters of post-caret context to include as conditioning.
    public let afterWindow: Int

    public init(beforeWindow: Int = 1200, afterWindow: Int = 240) {
        self.beforeWindow = beforeWindow
        self.afterWindow = afterWindow
    }

    /// Build the prompt for a context. `toneInstruction` is the per-app override,
    /// if any. Returns nil when there is nothing meaningful to complete.
    public func makePrompt(
        for context: EditingContext,
        length: SuggestionLength,
        toneInstruction: String? = nil
    ) -> Prompt? {
        guard !context.isSecure else { return nil }

        let before = String(context.textBeforeCaret.suffix(beforeWindow))
        // Nothing to complete if there is no preceding text.
        guard !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let after = String(context.textAfterCaret.prefix(afterWindow))

        var header = "You are an inline autocomplete engine. Continue the user's text "
        header += "naturally in their voice. Output only the continuation, no preamble. "
        header += "Keep it \(length.displayName.lowercased())."
        if let tone = toneInstruction?.trimmingCharacters(in: .whitespacesAndNewlines),
           !tone.isEmpty {
            header += " Tone: \(tone)."
        }

        var body = "\n\nText before cursor:\n\(before)"
        if !after.isEmpty {
            body += "\n\nText after cursor:\n\(after)"
        }
        body += "\n\nContinuation:"

        let full = header + body
        return Prompt(text: full, fingerprint: Self.fingerprint(before: before, after: after, length: length, tone: toneInstruction))
    }

    /// Stable fingerprint of the inputs that affect generation. Used by the
    /// coordinator's dedupe cache so identical contexts don't re-request.
    static func fingerprint(
        before: String,
        after: String,
        length: SuggestionLength,
        tone: String?
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(before)
        hasher.combine(after)
        hasher.combine(length)
        hasher.combine(tone ?? "")
        return hasher.finalize()
    }
}

/// A built prompt plus its dedupe fingerprint.
public struct Prompt: Equatable, Sendable {
    public let text: String
    public let fingerprint: Int

    public init(text: String, fingerprint: Int) {
        self.text = text
        self.fingerprint = fingerprint
    }
}
