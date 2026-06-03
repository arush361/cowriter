// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// The app's coordinator object: owns the engine + suggestion coordinator + the
// capture and rendering pieces, and is the SwiftUI source of truth for menu and
// settings state. This is where the real CowriterCore types meet the macOS edges.

import SwiftUI
import CowriterCore
import CowriterInferenceMLX

@MainActor
final class AppController: ObservableObject {
    enum Status: Equatable { case active, generating, paused, needsPermission }

    @Published private(set) var status: Status = .needsPermission
    // Qualify to avoid colliding with SwiftUI's `Settings` scene type.
    @Published var settings: CowriterCore.Settings

    /// SF Symbol shown in the menu bar, reflecting current state.
    var menuBarSymbol: String {
        switch status {
        case .active:          return "text.cursor"
        case .generating:      return "ellipsis"
        case .paused:          return "pause.circle"
        case .needsPermission: return "exclamationmark.triangle"
        }
    }

    /// Prompt for Accessibility permission (opens System Settings).
    func requestAccessibilityPermission() {
        textMonitor.requestAccessibilityPermission()
    }

    private let store = SettingsStore()
    private let coordinator: SuggestionCoordinator
    private let textMonitor = TextMonitor()
    private let keystrokes = KeystrokeTap()
    private let overlay = GhostTextOverlay()

    /// Current pause state, evaluated against the wall clock on each request.
    private var pause: PauseState = .active
    /// The suggestion currently displayed, if any (so Tab knows what to commit).
    private var visible: Suggestion?
    /// Debounce handle for the typing-pause trigger.
    private var debounce: Task<Void, Never>?

    init() {
        let loaded = store.load()
        self.settings = loaded

        // Resolve the active model (default to the recommended one for this Mac).
        let ram = ProcessInfo.processInfo.physicalMemory
        let model = loaded.activeModelID.flatMap(ModelRegistry.model(id:))
            ?? ModelRegistry.recommendedDefault(ramBytes: ram)

        // The real engine. Swapping in MockInferenceEngine() makes this testable.
        let engine = MLXInferenceEngine(resolveLocalPath: { ModelPaths.directory(for: $0) })
        self.coordinator = SuggestionCoordinator(engine: engine)

        Task { await bootstrap(model: model, engine: engine) }
    }

    private func bootstrap(model: ModelDescriptor, engine: MLXInferenceEngine) async {
        guard textMonitor.hasAccessibilityPermission else {
            status = .needsPermission
            return
        }
        do {
            try await engine.load(model)
            wireCapture()
            status = .active
        } catch {
            status = .needsPermission // surfaced in UI; real handling in onboarding
        }
    }

    // MARK: - Capture wiring

    private func wireCapture() {
        // A typing pause triggers a debounced suggestion request.
        textMonitor.onContextChange = { [weak self] context in
            self?.scheduleSuggestion(for: context)
        }
        // Tab accepts a visible suggestion; any other key dismisses it.
        keystrokes.onAccept = { [weak self] in self?.acceptVisible() }
        keystrokes.onDismiss = { [weak self] in self?.dismiss() }

        textMonitor.start()
        keystrokes.start()
    }

    private func scheduleSuggestion(for context: EditingContext) {
        debounce?.cancel()
        dismiss() // clear any stale ghost text immediately on new input
        debounce = Task { [weak self] in
            // Wait for a short typing pause before asking the model.
            try? await Task.sleep(for: .milliseconds(350)) // VERIFY: tune per feel
            guard let self, !Task.isCancelled else { return }
            await self.requestSuggestion(for: context)
        }
    }

    private func requestSuggestion(for context: EditingContext) async {
        status = .generating
        let result = await coordinator.requestSuggestion(
            for: context, settings: settings, pause: pause
        )
        status = pause.isActive(now: Date()) ? .active : .paused
        guard let result else { return }
        visible = result
        let profile = AppCompatibility.profile(for: context.appBundleID)
        overlay.show(result.text, at: textMonitor.caretRect, rendering: profile.rendering)
    }

    // MARK: - Accept / dismiss

    private func acceptVisible() {
        guard let suggestion = visible else { return }
        textMonitor.commit(suggestion.text) // VERIFY: AX value mutation vs synthesized keys
        dismiss()
        Task { await coordinator.resetCache() } // next pause re-triggers cleanly
    }

    private func dismiss() {
        visible = nil
        overlay.hide()
        Task { await coordinator.cancelInFlight() }
    }

    // MARK: - Pause / resume

    func pause(_ duration: PauseState.Duration) {
        pause = .from(duration, now: Date())
        status = .paused
        dismiss()
    }

    func resume() {
        pause = .active
        status = .active
    }

    // MARK: - Settings persistence

    func updateSettings(_ newValue: CowriterCore.Settings) {
        settings = newValue
        try? store.save(newValue)
    }
}
