# ⚠️ UNVERIFIED SCAFFOLDING — does not compile in this repo as-is

Everything in `app/scaffolding/` is **draft code that has never been compiled or
run**. It is intentionally kept **outside `Sources/`** so it does not touch the
verified package: `swift build` and `swift test` in `app/` stay green precisely
because SPM never looks in this folder.

Enabling it requires three things this environment does not have:
1. **Network access** to fetch the `mlx-swift` / `mlx-swift-examples` packages.
2. **Apple Silicon + Metal** to actually run inference.
3. **Real model weights** on disk (multi-GB, downloaded separately).

Treat the code here as a head start, not a finished backend. The MLX Swift API
moves between releases; expect to reconcile the call sites below against the
exact version you pin. Every spot that needs checking is marked `// VERIFY:`.

---

## What's here

| File | Purpose |
|------|---------|
| `CowriterInferenceMLX/MLXInferenceEngine.swift` | An `InferenceEngine` backed by MLX, with a streaming hook for the benchmark |
| `CowriterBench/main.swift` | A CLI that loads each model and measures load time, first-token latency, full-suggestion latency, tokens/sec, and resident memory |

Neither is referenced by `Package.swift`. Nothing in `CowriterCore` depends on
them. Wiring them in is the step below.

---

## How to wire it in (on a real Mac, online)

### 1. Move the sources under `Sources/`
```bash
cd app
mv scaffolding/CowriterInferenceMLX Sources/CowriterInferenceMLX
mv scaffolding/CowriterBench        Sources/CowriterBench
```

### 2. Add the dependency + targets to `Package.swift`
Add to `dependencies:`
```swift
.package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main"),
```
Add to `targets:`
```swift
.target(
    name: "CowriterInferenceMLX",
    dependencies: [
        "CowriterCore",
        .product(name: "MLXLLM", package: "mlx-swift-examples"),
        .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
    ]
),
.executableTarget(
    name: "CowriterBench",
    dependencies: ["CowriterCore", "CowriterInferenceMLX"]
),
```
And expose the backend as a product if you like:
```swift
.library(name: "CowriterInferenceMLX", targets: ["CowriterInferenceMLX"]),
```

### 3. Get a model
Download an MLX-format model (e.g. a 4-bit Gemma or Llama-class model from the
`mlx-community` org on Hugging Face) into a local directory, and point the bench
at it (see `CowriterBench/main.swift` usage).

### 4. Build and run the benchmark
```bash
swift build
swift run cowriter-bench --model-path /path/to/mlx-model --prompt "Thanks for"
```

### 5. Record the result
Put the numbers (first-token latency, tokens/sec, RAM) into
`../../plan/07-risks-open-questions.md` Q1 and pick the primary backend. The
target to beat: **first token < 100 ms** on Apple Silicon for the small model.

---

## Why this isn't wired in already

The advisor boundary for this repo: code in the verified column must compile and
pass tests *here*. This code cannot (no network, no Metal, no weights), so
shipping it inside `Sources/` would silently break the green build and dress up
unverified code as done. Keeping it in `scaffolding/` is the honest placement.
