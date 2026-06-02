// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// The macOS menu bar app entry point. This is a SwiftUI `MenuBarExtra` agent
// (LSUIElement, no Dock icon). It needs an Xcode app target with an Info.plist
// (LSUIElement = YES) plus the Accessibility usage setup; it is not buildable as
// a plain SPM executable. Every platform API that must be checked is `// VERIFY:`.

import SwiftUI
import CowriterCore

@main
struct CowriterApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        // The always-present menu bar item. Its icon reflects engine state.
        MenuBarExtra {
            MenuBarContent(controller: controller)
        } label: {
            Image(systemName: controller.menuBarSymbol) // VERIFY: SF Symbol names
        }
        .menuBarExtraStyle(.menu)

        // Settings window (Cmd-,). SwiftUI Settings scene.
        Settings {
            SettingsView(controller: controller)
        }

        // Onboarding is shown as a separate window on first run.
        Window("Welcome to Cowriter", id: "onboarding") {
            OnboardingView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}

/// The dropdown shown when the user clicks the menu bar icon.
struct MenuBarContent: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            switch controller.status {
            case .active:     Text("Cowriter is active")
            case .generating: Text("Thinking...")
            case .paused:     Text("Paused")
            case .needsPermission: Text("Needs Accessibility permission")
            }
        }
        .disabled(true)

        Divider()

        if controller.status == .paused {
            Button("Resume") { controller.resume() }
        } else {
            Menu("Pause") {
                ForEach(PauseState.Duration.allCases, id: \.self) { duration in
                    Button(duration.displayName) { controller.pause(duration) }
                }
            }
        }

        Divider()

        // SettingsLink opens the Settings scene. VERIFY: availability on target OS.
        SettingsLink { Text("Settings...") }
        Button("Quit Cowriter") { NSApplication.shared.terminate(nil) }
    }
}
