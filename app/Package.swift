// swift-tools-version: 6.0
  import PackageDescription

  let package = Package(
      name: "Cowriter",
      platforms: [
          .macOS(.v14)
      ],
      products: [
          .library(name: "CowriterCore", targets: ["CowriterCore"]),
          .library(name: "CowriterInferenceMLX", targets: ["CowriterInferenceMLX"]),
          .executable(name: "cowriter-demo", targets: ["CowriterDemo"]),
          .executable(name: "cowriter-bench", targets: ["CowriterBench"])
      ],
      dependencies: [
          // MLX Swift LM libraries (Apple Silicon, Metal). The LLM/VLM libraries
          // moved out of mlx-swift-examples into this dedicated package, which is
          // what provides MLXLLM + MLXLMCommon used by CowriterInferenceMLX.
          // Consider pinning to a released tag instead of `branch: "main"` once
          // you confirm a version that compiles cleanly.
          .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main"),
          // The MLXHuggingFace tokenizer-loader macro expands to code that calls
          // `Tokenizers.AutoTokenizer`, so the consumer must supply swift-transformers.
          .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
          // Declared directly (also a transitive dep of mlx-swift-lm) so the bench
          // can import MLX and force the CPU backend. Range matches mlx-swift-lm.
          .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.31.3"))
      ],
      targets: [
          // Headless, fully-testable core: types, prompt building, the suggestion
          // coordinator, settings, and offline license verification. No GUI, no
          // network, no Metal. Stays dependency-free on purpose.
          .target(
              name: "CowriterCore"
          ),
          // Real on-device inference backend (MLX + Metal). Implements the
          // CowriterCore InferenceEngine protocol.
          .target(
              name: "CowriterInferenceMLX",
              dependencies: [
                  "CowriterCore",
                  .product(name: "MLXLLM", package: "mlx-swift-lm"),
                  .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                  .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                  .product(name: "Tokenizers", package: "swift-transformers")
              ]
          ),
          // A CLI that drives the full suggestion pipeline through the mock engine,
          // so the end-to-end flow is runnable without a GUI or a real model.
          .executableTarget(
              name: "CowriterDemo",
              dependencies: ["CowriterCore"]
          ),
          // Benchmark harness: loads a model and measures load time, first-token
          // latency, tokens/sec, and resident memory.
          .executableTarget(
              name: "CowriterBench",
              dependencies: [
                  "CowriterCore",
                  "CowriterInferenceMLX",
                  .product(name: "MLX", package: "mlx-swift")
              ]
          ),
          .testTarget(
              name: "CowriterCoreTests",
              dependencies: ["CowriterCore"]
          )
      ]
  )
