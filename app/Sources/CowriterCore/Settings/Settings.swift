import Foundation

/// All user-configurable state. Pure value type, Codable for persistence.
/// IMPORTANT: this never holds any captured text content. Only preferences.
public struct Settings: Equatable, Codable, Sendable {
    public var activeModelID: String?
    public var suggestionLength: SuggestionLength
    public var launchAtLogin: Bool
    /// Per-app overrides keyed by bundle ID.
    public var perApp: [String: AppSettings]

    public init(
        activeModelID: String? = nil,
        suggestionLength: SuggestionLength = .medium,
        launchAtLogin: Bool = false,
        perApp: [String: AppSettings] = [:]
    ) {
        self.activeModelID = activeModelID
        self.suggestionLength = suggestionLength
        self.launchAtLogin = launchAtLogin
        self.perApp = perApp
    }

    public static let `default` = Settings()

    /// Whether suggestions are enabled for the given app. Defaults to enabled
    /// when there is no explicit per-app override.
    public func isEnabled(forApp bundleID: String) -> Bool {
        perApp[bundleID]?.enabled ?? true
    }

    /// Per-app tone instruction, if the user set one.
    public func toneInstruction(forApp bundleID: String) -> String? {
        perApp[bundleID]?.toneInstruction
    }
}

/// Per-app overrides.
public struct AppSettings: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var toneInstruction: String?

    public init(enabled: Bool = true, toneInstruction: String? = nil) {
        self.enabled = enabled
        self.toneInstruction = toneInstruction
    }
}
