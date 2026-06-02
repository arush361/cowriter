import Foundation

/// The contract every inference backend implements. The real backends (MLX-Swift
/// for Apple Silicon, llama.cpp for fallback/Intel) live outside `CowriterCore`
/// because they pull in Metal + multi-GB weights. The core only ever talks to
/// this protocol, so it stays headless and testable.
///
/// FROZEN CONTRACT: do not change these signatures without updating every
/// backend and the coordinator. This is the spine the whole app integrates on.
public protocol InferenceEngine: Sendable {
    /// Load the given model into memory. Idempotent for an already-loaded model.
    func load(_ model: ModelDescriptor) async throws

    /// Release the model from memory.
    func unload() async

    /// Whether a model is currently loaded and ready to generate.
    var isLoaded: Bool { get async }

    /// Generate a continuation for `prompt`, honoring `maxTokens`.
    ///
    /// Implementations must check `Task.isCancelled` between tokens and throw
    /// `InferenceError.cancelled` promptly when the surrounding Task is cancelled.
    /// This is how the coordinator aborts an in-flight suggestion when the user
    /// keeps typing.
    func generate(prompt: String, maxTokens: Int) async throws -> String
}
