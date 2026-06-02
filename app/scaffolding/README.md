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

**Inference + benchmark**

| File | Purpose |
|------|---------|
| `CowriterInferenceMLX/MLXInferenceEngine.swift` | An `InferenceEngine` backed by MLX, with a streaming hook for the benchmark |
| `CowriterBench/main.swift` | A CLI that loads each model and measures load time, first-token latency, full-suggestion latency, tokens/sec, and resident memory |

**The macOS app layer** (`CowriterApp/`) — the GUI + system edges (Phases 2, 4, 5, 6)

| File | Purpose |
|------|---------|
| `CowriterApp.swift` | `@main` SwiftUI `MenuBarExtra` agent: menu bar item, pause menu, settings + onboarding scenes |
| `AppController.swift` | Wires capture -> `SuggestionCoordinator` (real `MLXInferenceEngine`) -> overlay; owns pause/settings state and the debounce |
| `TextMonitor.swift` | Accessibility capture: `AXObserver` on the focused field, caret geometry, secure-field guard, commit. Emits `EditingContext` |
| `KeystrokeTap.swift` | `CGEventTap`: Tab-to-accept (swallowed when a suggestion shows), any-other-key-to-dismiss |
| `GhostTextOverlay.swift` | Borderless click-through `NSPanel` rendering faint ghost text at the caret |
| `OnboardingView.swift` | First-run flow: welcome -> permission -> model -> try-it |
| `SettingsView.swift` | Settings window: General, Models, Apps, Privacy |
| `ModelPaths.swift` | Where weights live on disk (a real `ModelManager` downloads + verifies here) |

Nothing here is referenced by `Package.swift`, and nothing in `CowriterCore`
depends on it. The app layer consumes the real `CowriterCore` contracts
(`EditingContext`, `SuggestionCoordinator`, `Settings`, `AppCompatibility`,
`ModelRegistry`) and the `CowriterInferenceMLX` engine. Assembling it into a
runnable app is the steps below.

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

### 5. Assemble the menu bar app (on your Mac, in Xcode)

The app layer (`CowriterApp/`) cannot be a plain SPM executable: a menu bar agent
needs an app bundle with an `Info.plist` (`LSUIElement = YES`) and runtime
permissions. Build it as an Xcode app target:

1. In Xcode: File > New > Project > macOS > App (SwiftUI lifecycle). Name it Cowriter.
2. Set `Application is agent (UIElement)` to YES in the target's Info (so there is no Dock icon).
3. Add this Swift package (`app/`) as a local package dependency, linking the
   `CowriterCore` and `CowriterInferenceMLX` products.
4. Add the `CowriterApp/*.swift` files to the app target (delete the template `App.swift`).
5. Enable the Hardened Runtime. Accessibility (AXIsProcessTrusted) does not need a
   specific entitlement, but the app must be signed and the user must grant it in
   System Settings > Privacy & Security > Accessibility.
6. Build and Run. On first launch the onboarding window asks for Accessibility
   permission, downloads the model, and drops you into the try-it box.

Expect to fix `// VERIFY:` sites against the real AppKit / Accessibility / MLX
APIs as you go. This code has never been compiled.

### 6. Record the benchmark result
Put the numbers (first-token latency, tokens/sec, RAM) into
`../../plan/07-risks-open-questions.md` Q1 and pick the primary backend. The
target to beat: **first token < 100 ms** on Apple Silicon for the small model.

---

## Why this isn't wired in already

The advisor boundary for this repo: code in the verified column must compile and
pass tests *here*. This code cannot (no network, no Metal, no weights), so
shipping it inside `Sources/` would silently break the green build and dress up
unverified code as done. Keeping it in `scaffolding/` is the honest placement.
