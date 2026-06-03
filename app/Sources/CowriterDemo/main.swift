import Foundation
import CowriterCore

// A headless end-to-end demo of the suggestion pipeline using the mock engine.
// Proves the Phase 3 spine works without a GUI or a real model:
//   EditingContext -> PromptBuilder -> SuggestionCoordinator -> Suggestion
//
// Usage:
//   cowriter-demo "Thanks for"
//   cowriter-demo            (runs a few built-in samples)

func runSuggestion(for text: String) async {
    let engine = MockInferenceEngine()
    try? await engine.load(ModelRegistry.model(id: "qwen2.5-1.5b")!)

    let coordinator = SuggestionCoordinator(engine: engine)
    let context = EditingContext(
        appBundleID: "com.apple.mail",
        appName: "Mail",
        fieldText: text,
        caretOffset: text.utf16.count
    )

    let suggestion = await coordinator.requestSuggestion(
        for: context,
        settings: .default,
        pause: .active
    )

    if let suggestion {
        print("  input : \(text)")
        print("  ghost : \(suggestion.text)")
        print("  joined: \(text)\(suggestion.text)")
    } else {
        print("  input : \(text)")
        print("  ghost : (no suggestion)")
    }
    print("")
}

let args = Array(CommandLine.arguments.dropFirst())

await { () async in
    if let userText = args.first, !userText.isEmpty {
        await runSuggestion(for: userText)
    } else {
        print("Cowriter pipeline demo (mock engine)\n")
        let samples = [
            "Thanks for",
            "Let me know",
            "I wanted to",
            "The deploy is finished and"
        ]
        for sample in samples {
            await runSuggestion(for: sample)
        }
    }
}()
