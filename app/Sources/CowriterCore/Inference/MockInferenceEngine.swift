import Foundation

/// A deterministic, dependency-free `InferenceEngine` used for tests, the CLI
/// demo, and development before the real MLX/llama.cpp backends exist.
///
/// It does not run a model. It produces a plausible continuation using simple
/// heuristics so the full pipeline (capture -> context -> coordinate -> render)
/// can be exercised and unit-tested headlessly. It also honors cancellation and
/// an injectable per-token delay so debounce/cancel behavior can be tested.
public actor MockInferenceEngine: InferenceEngine {
    private var loadedModel: ModelDescriptor?
    private let perTokenDelay: Duration

    /// - Parameter perTokenDelay: simulated time to "generate" each token.
    ///   Defaults to zero so tests run fast; set it to observe cancellation.
    public init(perTokenDelay: Duration = .zero) {
        self.perTokenDelay = perTokenDelay
    }

    public var isLoaded: Bool { loadedModel != nil }

    public func load(_ model: ModelDescriptor) async throws {
        loadedModel = model
    }

    public func unload() async {
        loadedModel = nil
    }

    public func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard loadedModel != nil else { throw InferenceError.modelNotLoaded }

        let tokens = Self.continuation(for: prompt)
        var produced: [String] = []
        for token in tokens.prefix(maxTokens) {
            try Task.checkCancellation()
            if perTokenDelay != .zero {
                try await Task.sleep(for: perTokenDelay)
            }
            produced.append(token)
        }
        return produced.joined()
    }

    /// Heuristic continuation: complete a few common openers, otherwise finish
    /// the current sentence with a neutral closer. Tokenized as whitespace-joined
    /// chunks so `maxTokens` is meaningful.
    ///
    /// Operates on the user's pre-caret text, which it extracts from the prompt's
    /// "Text before cursor:" section (the format `PromptBuilder` emits).
    static func continuation(for prompt: String) -> [String] {
        let before = extractBeforeText(from: prompt)
        let trimmed = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        let canned: [(prefix: String, completion: String)] = [
            ("thanks for", " reaching out. I'll take a look and get back to you shortly."),
            ("let me know", " if you have any questions or need anything else."),
            ("i wanted to", " follow up on the discussion from earlier this week."),
            ("please find", " attached the document you requested."),
            ("looking forward", " to hearing your thoughts.")
        ]
        for entry in canned where lower.hasSuffix(entry.prefix) {
            return tokenize(entry.completion)
        }

        // Generic fallback: if mid-sentence, offer a short neutral continuation.
        if let last = trimmed.last, !".!?".contains(last) {
            return tokenize(" and let me know what you think.")
        }
        return []
    }

    /// Pull the pre-caret text out of a `PromptBuilder` prompt. Falls back to the
    /// whole string if the marker is absent (e.g. a raw prompt in a test).
    private static func extractBeforeText(from prompt: String) -> String {
        let marker = "Text before cursor:\n"
        guard let range = prompt.range(of: marker) else { return prompt }
        let after = prompt[range.upperBound...]
        if let end = after.range(of: "\n\n") {
            return String(after[..<end.lowerBound])
        }
        return String(after)
    }

    /// Split into whitespace-preserving tokens so joined output round-trips.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == " " {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
