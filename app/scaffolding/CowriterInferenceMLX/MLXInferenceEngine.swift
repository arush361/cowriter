// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// This implements `InferenceEngine` (from CowriterCore) on top of MLX Swift.
// It requires the `mlx-swift-examples` package, Apple Silicon + Metal, and a
// local MLX-format model. It is deliberately NOT part of the package build.
//
// The MLX Swift API surface changes between releases. Every call site that
// must be reconciled against your pinned version is tagged `// VERIFY:`.

import Foundation
import CowriterCore

// VERIFY: module names and availability for your pinned mlx-swift-examples.
import MLXLMCommon
import MLXLLM

/// MLX-backed inference engine. Loads a local MLX model and streams a
/// continuation, honoring `maxTokens` and cooperative cancellation.
public actor MLXInferenceEngine: InferenceEngine {

    /// How a model id maps to an on-disk MLX model directory. The bench and app
    /// supply this; `ModelDescriptor` only carries a download URL + checksum.
    private let resolveLocalPath: @Sendable (ModelDescriptor) -> URL

    /// VERIFY: `ModelContainer` is the mlx-swift-examples handle that owns the
    /// model + tokenizer + processor and serializes access to them.
    private var container: ModelContainer?
    private var loaded: ModelDescriptor?

    /// Sampling parameters. Short, faithful continuations beat creative ones for
    /// autocomplete, so keep temperature low.
    public var temperature: Float = 0.2
    public var topP: Float = 0.9

    public init(resolveLocalPath: @escaping @Sendable (ModelDescriptor) -> URL) {
        self.resolveLocalPath = resolveLocalPath
    }

    public var isLoaded: Bool { container != nil }

    public func load(_ model: ModelDescriptor) async throws {
        if loaded?.id == model.id, container != nil { return } // idempotent

        let dir = resolveLocalPath(model)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw InferenceError.backendFailure("Model not found at \(dir.path)")
        }

        do {
            // VERIFY: `ModelConfiguration(directory:)` and `LLMModelFactory.shared
            // .loadContainer(configuration:)` against your pinned API. Older
            // versions used `LLM.loadModelContainer(...)`.
            let configuration = ModelConfiguration(directory: dir)
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            )
            loaded = model
        } catch {
            throw InferenceError.backendFailure("MLX load failed: \(error)")
        }
    }

    public func unload() async {
        container = nil
        loaded = nil
    }

    public func generate(prompt: String, maxTokens: Int) async throws -> String {
        var text = ""
        try await stream(prompt: prompt, maxTokens: maxTokens) { token in
            text += token
        }
        return text
    }

    /// Streaming variant used by the benchmark to time the first token. The
    /// `onToken` closure is called for each decoded chunk. Throws
    /// `InferenceError.cancelled` promptly when the Task is cancelled.
    public func stream(
        prompt: String,
        maxTokens: Int,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let container else { throw InferenceError.modelNotLoaded }

        do {
            // VERIFY: the whole closure body. The mlx-swift-examples generation
            // API has shifted across versions between a callback-style
            // `generate(...) { ... }` and an `AsyncStream` of `Generation`
            // events. This uses the stream form; adapt as needed.
            try await container.perform { (context: ModelContext) in
                let userInput = UserInput(prompt: .text(prompt))           // VERIFY
                let input = try await context.processor.prepare(input: userInput) // VERIFY

                let params = GenerateParameters(                            // VERIFY
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP
                )

                let generation = try MLXLMCommon.generate(                  // VERIFY
                    input: input,
                    parameters: params,
                    context: context
                )

                var produced = 0
                for await event in generation {
                    try Task.checkCancellation()
                    switch event {
                    case .chunk(let piece):                                 // VERIFY: case name
                        onToken(piece)
                        produced += 1
                        if produced >= maxTokens { return }
                    case .info:                                             // VERIFY: case name
                        // Per-generation stats (tokens/sec etc.); ignored here.
                        break
                    @unknown default:
                        break
                    }
                }
            }
        } catch is CancellationError {
            throw InferenceError.cancelled
        } catch let err as InferenceError {
            throw err
        } catch {
            throw InferenceError.backendFailure("MLX generate failed: \(error)")
        }
    }
}
