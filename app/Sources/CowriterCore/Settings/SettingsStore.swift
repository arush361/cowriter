import Foundation

/// Persists `Settings` to disk as JSON in Application Support. No text content is
/// ever written. Synchronous and small; settings are tiny.
public final class SettingsStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.cowriter.settings")

    /// - Parameter fileURL: where to persist. Defaults to
    ///   ~/Library/Application Support/Cowriter/settings.json. Injectable for tests.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("Cowriter/settings.json")
        }
    }

    public func load() -> Settings {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
                return .default
            }
            return settings
        }
    }

    public func save(_ settings: Settings) throws {
        try queue.sync {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        }
    }
}
