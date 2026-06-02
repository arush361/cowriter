# Cowriter (core)

The Swift package behind Cowriter, a private, on-device AI autocomplete app for macOS. This repository holds the headless, testable core: the suggestion pipeline, settings, model registry, app-compatibility profiles, and offline license verification. The GUI app, real inference backends, and system text capture are built on top of these contracts.

## Build and test

```bash
swift build
swift test
swift run cowriter-demo "Thanks for"
```

Requires Swift 6 and macOS 14+.

## What's here

| Module | Responsibility |
|--------|----------------|
| `Types/` | Shared contracts: `EditingContext`, `Suggestion`, `SuggestionLength`, `PauseState`, `ModelDescriptor` |
| `Inference/` | `InferenceEngine` protocol, a deterministic `MockInferenceEngine`, and the model registry |
| `Context/` | `PromptBuilder` - turns an editing context + settings into a prompt and a dedupe fingerprint |
| `Coordinator/` | `SuggestionCoordinator` - debounce-friendly async API with gating, dedupe, and cancel-on-supersede |
| `Settings/` | Codable settings with per-app overrides and JSON persistence (no text content is ever stored) |
| `Apps/` | Per-app support tier and ghost-text rendering strategy |
| `License/` | Ed25519 offline license verification and pasteable key encode/decode |

The `cowriter-demo` executable drives the full pipeline (context -> prompt -> coordinator -> suggestion) through the mock engine, so the flow is runnable without a GUI or a real model.

## Design

`CowriterCore` is dependency-free and engine-agnostic. Real inference backends (MLX-Swift for Apple Silicon, llama.cpp as a fallback) live in separate targets and implement `InferenceEngine`, so swapping the mock for a real model is a one-line construction change:

```swift
let coordinator = SuggestionCoordinator(engine: MockInferenceEngine())   // today
let coordinator = SuggestionCoordinator(engine: MLXInferenceEngine(...))  // with a real model
```
