// On-device inference backend for Cowriter, implemented on MLX Swift
// (mlx-swift-lm). Loads a local MLX model directory and generates a continuation
// via the streaming `AsyncStream<Generation>` API.
//
// Verified to COMPILE against mlx-swift-lm @ main (MLXLLM / MLXLMCommon /
// MLXHuggingFace). Runtime behavior (latency, output quality) still needs a real
// model on real hardware: run `cowriter-bench` to confirm. See ../scaffolding/README.md.

import Foundation
import CowriterCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers  // required by the #huggingFaceTokenizerLoader macro expansion

/// Timing + output from one generation, used by both `generate` and the benchmark.
public struct GenStats: Sendable {
    public let text: String
    public let firstTokenSeconds: Double
    public let totalSeconds: Double
    public let tokenCount: Int
}

public actor MLXInferenceEngine: InferenceEngine {
    /// Maps a `ModelDescriptor` to the on-disk MLX model directory.
    private let resolveLocalPath: @Sendable (ModelDescriptor) -> URL

    private var container: ModelContainer?
    private var loaded: ModelDescriptor?

    /// Low temperature: short, faithful continuations beat creative ones here.
    public var temperature: Float = 0.2
    public var topP: Float = 0.9

    // Note on Qwen3 "thinking": we feed a bare completion prompt via
    // `UserInput(prompt: .text(...))`, which bypasses the chat template, so no
    // `<think>` trace is produced. (Going through `.chat`/`.messages` would
    // apply the template and require `enable_thinking: false`.)

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
            // Load straight from the local directory (no network), using the
            // Hugging Face tokenizer loader provided by the MLXHuggingFace macro.
            container = try await LLMModelFactory.shared.loadContainer(
                from: dir,
                using: #huggingFaceTokenizerLoader()
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
        try await generateTimed(prompt: prompt, maxTokens: maxTokens).text
    }

    /// Generate and report timing. Runs entirely inside `container.perform`, so
    /// all accumulation is local to the model's isolation (no Sendable hazards).
    public func generateTimed(prompt: String, maxTokens: Int) async throws -> GenStats {
        guard let container else { throw InferenceError.modelNotLoaded }
        let temperature = self.temperature
        let topP = self.topP

        do {
            return try await container.perform { (context: ModelContext) in
                let lmInput = try await context.processor.prepare(
                    input: UserInput(prompt: .text(prompt))
                )
                let params = GenerateParameters(
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP
                )

                let start = DispatchTime.now().uptimeNanoseconds
                var firstTokenNs: UInt64?
                var out = ""
                var count = 0

                let stream = try MLXLMCommon.generate(
                    input: lmInput, parameters: params, context: context
                )
                for await item in stream {
                    try Task.checkCancellation()
                    if let chunk = item.chunk {
                        if firstTokenNs == nil { firstTokenNs = DispatchTime.now().uptimeNanoseconds }
                        out += chunk
                        count += 1
                    }
                }

                let end = DispatchTime.now().uptimeNanoseconds
                let seconds = { (ns: UInt64) in Double(ns) / 1_000_000_000 }
                return GenStats(
                    text: out,
                    firstTokenSeconds: seconds((firstTokenNs ?? end) - start),
                    totalSeconds: seconds(end - start),
                    tokenCount: count
                )
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
