# Cowriter: step-by-step build guide

A complete walkthrough from this repo to a running menu bar app on your Mac.

This assumes you are on Apple Silicon, macOS 14+, with Xcode 16+ installed. The
core package is verified; the app layer and MLX backend in `scaffolding/` have
never been compiled, so expect to fix `// VERIFY:` sites as you go. Work the
steps in order. Do not skip Step 6 (the benchmark): it is the gate the whole
product depends on.

---

## Step 0: Confirm the verified core builds

```bash
cd app
swift build
swift test            # expect 41 passed
swift run cowriter-demo "Thanks for"
```

If this works, the engine is healthy and everything below is about wiring the
macOS edges onto it.

---

## Step 1: Create the Xcode app target

1. Open Xcode. File > New > Project.
2. Choose macOS > App. Next.
3. Product Name: `Cowriter`. Interface: SwiftUI. Language: Swift. Uncheck tests/Core Data.
4. Save it somewhere OUTSIDE this repo for now (e.g. `~/Developer/CowriterApp`), or
   inside it as a sibling of `app/`. Keep them separate to start.
5. Delete the auto-generated `CowriterApp.swift` / `ContentView.swift` from the
   target (you will replace them with the scaffolding files).

---

## Step 2: Make it a menu bar agent (no Dock icon)

Recent Xcode (16+) auto-generates the Info.plist, so there is usually no "Info"
tab row to edit. Use Build Settings instead:

1. Click the project (blue icon at the top of the navigator).
2. Under TARGETS, select Cowriter.
3. Open the Build Settings tab; select All + Combined.
4. Search `agent` (or `UIElement`).
5. Set `Application is agent (UIElement)` (raw key `INFOPLIST_KEY_LSUIElement`) to YES.

Alternative (no Build Settings edit): drop the Dock icon in code by adding this
to the `CowriterApp` struct:

```swift
init() {
    NSApplication.shared.setActivationPolicy(.accessory)
}
```

Do one of the two, not both. Then set the minimum deployment:

6. Target > General > Minimum Deployments > macOS = 14.0.

---

## Step 3: Add this Swift package as a local dependency

1. File > Add Package Dependencies > Add Local.
2. Select this repo's `app/` folder (the one with `Package.swift`).
3. Add the products to your target:
   - `CowriterCore`
   - `CowriterInferenceMLX` (you will create this target in Step 5)

---

## Step 4: Add the MLX dependency to the package

Edit `app/Package.swift`. Add to `dependencies`:

```swift
.package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main"),
```

Add to `targets` (and move the scaffolding sources into `Sources/`, see Step 5):

```swift
.target(
    name: "CowriterInferenceMLX",
    dependencies: [
        "CowriterCore",
        .product(name: "MLXLLM", package: "mlx-swift-examples"),
        .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
    ]
),
```

Add to `products`:

```swift
.library(name: "CowriterInferenceMLX", targets: ["CowriterInferenceMLX"]),
```

---

## Step 5: Move the scaffolding into place

```bash
cd app
mv scaffolding/CowriterInferenceMLX Sources/CowriterInferenceMLX
```

Then add the app-layer files to the Xcode app target (not the package):
drag every file in `scaffolding/CowriterApp/` into the Cowriter target in Xcode.

Resolve packages: File > Packages > Resolve Package Versions. Then build the
package alone to shake out backend errors:

```bash
swift build           # now compiles CowriterInferenceMLX against MLX
```

Note: `MLXInferenceEngine.swift` and `CowriterBench` already compile against
`mlx-swift-lm` @ main (the LLM libraries moved there from `mlx-swift-examples`).
The package manifest in this repo already declares `mlx-swift-lm`,
`swift-transformers` (for the tokenizer-loader macro), and `mlx-swift`, so
`swift build` succeeds. The remaining `// VERIFY:` work is in the app-layer
files (`CowriterApp/`), not the backend.

---

## Step 6: Download a model and benchmark it (THE GATE)

Install the Hugging Face CLI and pull the default model:

```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli download Qwen/Qwen3-1.7B-MLX-4bit \
  --local-dir ~/Library/Application\ Support/Cowriter/models/qwen3-1.7b
```

The model download is verified working (the snapshot lands at the path above).

IMPORTANT - the benchmark cannot run via `swift run`. MLX initializes Metal at
framework startup and needs `mlx-swift_Cmlx.bundle/default.metallib`, which a
plain SwiftPM CLI build does NOT compile or bundle:

```bash
swift run cowriter-bench --model-path .../model   # -> "Failed to load the default metallib"
```

The fix is to build with `xcodebuild` instead of `swift build` (NO Xcode GUI
needed). xcodebuild uses the full Xcode build system, which compiles + bundles
the Metal library. This is verified working:

```bash
cd app
xcodebuild -scheme cowriter-bench -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .xcode-build -skipMacroValidation build
# (-skipMacroValidation approves the MLXHuggingFace macro non-interactively)

.xcode-build/Build/Products/Debug/cowriter-bench \
  --model-path "$HOME/Library/Application Support/Cowriter/models/<model>"
```

Read the first-token number. Under ~100 ms = good.

### Verified results (June 2, M-series)
- Real GPU inference confirmed running via the xcodebuild route.
- `Qwen3-1.7B-MLX-4bit`: first-token ~37 ms BUT it is a **thinking** model - it
  emits a `<think>...</think>` trace that consumes the whole short token budget
  before producing any continuation. **Unsuitable for autocomplete.**
- `Qwen2.5-1.5B-Instruct-4bit` (Apache 2.0, **non-thinking**): first-token
  ~34-41 ms, full short suggestion 67-314 ms, clean continuations
  (e.g. "Let me know if you" -> "are interested in joining our team."). This is
  the right kind of model for the use case.

Lesson: pick a NON-thinking instruct (or base) model. See plan/07 Q2/Q5.

(The same metallib requirement is why the menu bar app must also be built via
Xcode / xcodebuild, not `swift run`.)

---

## Step 7: First run of the app

1. In Xcode, select the Cowriter target and Run (Cmd-R).
2. The onboarding window appears. Click through to the permission step.
3. It opens System Settings > Privacy & Security > Accessibility. Toggle Cowriter ON.
   (You may need to quit and relaunch the app once after granting.)
4. Pick the Balanced model. It uses the weights you downloaded in Step 6.
5. In the try-it box, type a sentence opener and watch for grey ghost text. Tab accepts.

If nothing appears, see the debugging checklist below.

---

## Step 8: Validate across real apps (Phase 2 / 4)

Open Mail, Notes, Slack, a browser, etc. Type in each and confirm:
- Ghost text appears at the caret and tracks it as you type.
- Tab inserts the suggestion; continuing to type clears it.
- Password fields never get a suggestion.

Update `AppCompatibility.known` profiles where an app misbehaves, and tune the
caret-rect conversion in `GhostTextOverlay` / `TextMonitor` for apps where the
overlay is misaligned.

---

## Debugging checklist (no suggestions showing)

1. Is Cowriter checked in System Settings > Privacy & Security > Accessibility?
2. Did you relaunch after granting permission?
3. Is the model actually downloaded to the path in `ModelPaths.directory(for:)`?
4. Is the app paused, or disabled for the current app in Settings?
5. Add a temporary `print` in `AppController.requestSuggestion` to confirm the
   pipeline is reached and a non-nil `Suggestion` comes back.
6. Confirm Qwen3 is running in non-thinking mode (no `<think>` text in output).

---

## After it runs (Phases 5, 6, 9)

- Polish onboarding + settings; wire `launchAtLogin` to `SMAppService`.
- Per-app enable/disable + tone instructions (the `Apps` settings tab is a stub).
- Phase 9: Stripe checkout + a webhook that signs license keys with the Ed25519
  private key (the app already verifies them offline via `LicenseManager`), then
  sign + notarize the app and set up Sparkle for updates.

When you hit a specific compile or runtime error, capture the exact message and
the file/line. That is the fastest thing to act on.
