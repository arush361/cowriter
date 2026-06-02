// ⚠️ UNVERIFIED SCAFFOLDING — never compiled or run. See ../README.md.
//
// Resolves where a model's weights live on disk. The MLX engine is handed this
// directory. A real ModelManager would download the Hugging Face snapshot here
// on first run, verify per-file digests, and report progress to onboarding.

import Foundation
import CowriterCore

enum ModelPaths {
    /// ~/Library/Application Support/Cowriter/models/<id>/
    static func directory(for model: ModelDescriptor) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("Cowriter/models", isDirectory: true)
            .appendingPathComponent(model.id, isDirectory: true)
    }

    static func isDownloaded(_ model: ModelDescriptor) -> Bool {
        // VERIFY: check for the expected MLX files (config.json, weights, tokenizer).
        let dir = directory(for: model)
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("config.json").path)
    }
}
