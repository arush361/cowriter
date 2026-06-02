// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// The Settings window: General, Models, Apps, Privacy, License, About. SwiftUI
// TabView bound to the controller's `Settings`. This is the Phase 5/6 edge.

import SwiftUI
import CowriterCore

struct SettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        TabView {
            GeneralSettings(controller: controller)
                .tabItem { Label("General", systemImage: "gearshape") }
            ModelSettings(controller: controller)
                .tabItem { Label("Models", systemImage: "cpu") }
            AppsSettings(controller: controller)
                .tabItem { Label("Apps", systemImage: "app.badge") }
            PrivacySettings()
                .tabItem { Label("Privacy", systemImage: "lock") }
        }
        .frame(width: 460, height: 360)
    }
}

struct GeneralSettings: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Picker("Suggestion length", selection: lengthBinding) {
                ForEach(SuggestionLength.allCases, id: \.self) { len in
                    Text(len.displayName).tag(len)
                }
            }
            Toggle("Launch at login", isOn: launchBinding)
        }
        .padding()
    }

    private var lengthBinding: Binding<SuggestionLength> {
        Binding(
            get: { controller.settings.suggestionLength },
            set: { var s = controller.settings; s.suggestionLength = $0; controller.updateSettings(s) }
        )
    }
    private var launchBinding: Binding<Bool> {
        Binding(
            get: { controller.settings.launchAtLogin },
            set: { var s = controller.settings; s.launchAtLogin = $0; controller.updateSettings(s) }
            // VERIFY: also call SMAppService.mainApp.register()/.unregister().
        )
    }
}

struct ModelSettings: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Form {
            Picker("Active model", selection: modelBinding) {
                ForEach(ModelRegistry.all) { Text($0.displayName).tag($0.id) }
            }
            Text("Larger models write better but use more memory and are slower.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { controller.settings.activeModelID ?? "qwen3-1.7b" },
            set: { var s = controller.settings; s.activeModelID = $0; controller.updateSettings(s) }
        )
    }
}

struct AppsSettings: View {
    @ObservedObject var controller: AppController

    var body: some View {
        // VERIFY: in a real build, list recently-seen apps and let the user
        // toggle each + set a per-app tone instruction (Settings.perApp).
        Text("Per-app toggles and tone instructions appear here.")
            .foregroundStyle(.secondary)
            .padding()
    }
}

struct PrivacySettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Everything runs on your Mac.").font(.headline)
            Text("Your text is processed locally by the on-device model. Cowriter makes no network calls to generate suggestions, keeps no account, and sends no telemetry.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
