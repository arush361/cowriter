// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// First-run flow: welcome -> grant Accessibility permission -> pick a model
// (download with progress) -> try-it sandbox. SwiftUI. This is the Phase 5 edge.

import SwiftUI
import CowriterCore

struct OnboardingView: View {
    @ObservedObject var controller: AppController
    @State private var step: Step = .welcome

    enum Step { case welcome, permission, model, tryIt, done }

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .welcome:
                pane(
                    title: "Cowriter finishes your sentences",
                    body: "Private, on-device autocomplete in every app. Press Tab to accept, keep typing to ignore. Nothing leaves your Mac.",
                    cta: "Get started"
                ) { step = .permission }

            case .permission:
                pane(
                    title: "Grant Accessibility access",
                    body: "Cowriter needs Accessibility permission to read the text field you are typing in and show suggestions. It is used only for that.",
                    cta: "Open System Settings"
                ) {
                    controller.requestAccessibilityPermission()
                    step = .model
                }

            case .model:
                ModelPickerStep(controller: controller) { step = .tryIt }

            case .tryIt:
                VStack(spacing: 12) {
                    Text("Try it").font(.title2.bold())
                    Text("Start typing below. A suggestion appears in grey; press Tab to accept.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    TextEditor(text: .constant(""))
                        .frame(height: 100)
                        .border(.quaternary)
                    Button("Finish") { step = .done; closeWindow() }
                        .buttonStyle(.borderedProminent)
                }

            case .done:
                EmptyView()
            }
        }
        .padding(40)
        .frame(width: 480)
    }

    private func pane(title: String, body: String, cta: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(body).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(cta, action: action).buttonStyle(.borderedProminent)
        }
    }

    private func closeWindow() {
        // VERIFY: dismiss the onboarding window (e.g. @Environment(\.dismissWindow)).
        NSApplication.shared.keyWindow?.close()
    }
}

/// Model choice with a (stubbed) download. Real download lives in ModelManager.
struct ModelPickerStep: View {
    @ObservedObject var controller: AppController
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose a model").font(.title2.bold())
            Text("Balanced is recommended. You can change this later in Settings.")
                .foregroundStyle(.secondary)
            ForEach(ModelRegistry.all) { model in
                Button {
                    var s = controller.settings
                    s.activeModelID = model.id
                    controller.updateSettings(s)
                    onDone()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.displayName).bold()
                            Text("~\(model.approxDiskMB) MB download, ~\(model.approxRAMMB) MB RAM")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.tier == .medium { Text("Recommended").font(.caption) }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
