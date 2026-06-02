import Foundation

/// Orchestrates a single suggestion lifecycle: gating (app enabled, not paused,
/// not secure), prompt construction, dedupe, in-flight cancellation, and calling
/// the engine. This is the Phase 3 spine.
///
/// It is deliberately UI-agnostic: it returns a `Suggestion?` and never renders
/// anything. The Ghost Text Renderer (Phase 4, AppKit) consumes the result.
public actor SuggestionCoordinator {
    private let engine: any InferenceEngine
    private let promptBuilder: PromptBuilder

    /// Last suggestion + the fingerprint it was generated for, for dedupe.
    private var lastFingerprint: Int?
    private var lastSuggestion: Suggestion?

    /// The currently in-flight generation task, if any. Cancelled when a new
    /// request supersedes it.
    private var inFlight: Task<Suggestion?, Never>?

    /// Monotonic request counter. Because this actor can be re-entered at `await`
    /// points, a later request increments this; an earlier request that resumes
    /// afterward sees a mismatch and knows it was superseded.
    private var generation: UInt64 = 0

    public init(engine: any InferenceEngine, promptBuilder: PromptBuilder = PromptBuilder()) {
        self.engine = engine
        self.promptBuilder = promptBuilder
    }

    /// Request a suggestion for the given context. Cancels any in-flight request
    /// first (the user typed something new). Returns nil when gated out, when the
    /// context is identical to the last one (served from cache), or when there is
    /// nothing presentable to suggest.
    ///
    /// - Parameters:
    ///   - context: the current editing context.
    ///   - settings: user settings (gating + length + tone).
    ///   - pause: current pause state.
    ///   - now: injected clock for deterministic pause evaluation.
    public func requestSuggestion(
        for context: EditingContext,
        settings: Settings,
        pause: PauseState,
        now: Date = Date()
    ) async -> Suggestion? {
        // A new request always supersedes the previous in-flight one.
        generation &+= 1
        let myGeneration = generation
        inFlight?.cancel()
        inFlight = nil

        // --- Gating ---
        guard pause.isActive(now: now) else { return nil }
        guard !context.isSecure else { return nil }
        guard settings.isEnabled(forApp: context.appBundleID) else { return nil }

        guard let prompt = promptBuilder.makePrompt(
            for: context,
            length: settings.suggestionLength,
            toneInstruction: settings.toneInstruction(forApp: context.appBundleID)
        ) else { return nil }

        // --- Dedupe: identical context returns the cached suggestion ---
        if prompt.fingerprint == lastFingerprint {
            return lastSuggestion
        }

        let maxTokens = settings.suggestionLength.maxTokens
        let engine = self.engine

        let task = Task<Suggestion?, Never> {
            do {
                let text = try await engine.generate(prompt: prompt.text, maxTokens: maxTokens)
                try Task.checkCancellation()
                let suggestion = Suggestion(text: text, contextFingerprint: prompt.fingerprint)
                return suggestion.isPresentable ? suggestion : Suggestion(text: "", contextFingerprint: prompt.fingerprint)
            } catch {
                return nil
            }
        }
        inFlight = task

        let result = await task.value
        // Only commit to cache if this request was not superseded while awaiting.
        guard myGeneration == generation else { return nil }
        inFlight = nil
        lastFingerprint = prompt.fingerprint
        lastSuggestion = result
        guard let result, result.isPresentable else { return nil }
        return result
    }

    /// Cancel any in-flight work (e.g. focus lost). Does not clear the cache.
    public func cancelInFlight() {
        inFlight?.cancel()
        inFlight = nil
    }

    /// Clear the dedupe cache (e.g. on app switch).
    public func resetCache() {
        lastFingerprint = nil
        lastSuggestion = nil
    }
}
