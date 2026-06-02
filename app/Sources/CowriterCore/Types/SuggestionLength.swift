import Foundation

/// User-facing control over how much text a suggestion may contain.
/// Maps to a hard token budget passed to the inference engine.
public enum SuggestionLength: String, CaseIterable, Codable, Sendable {
    case short
    case medium
    case long
    case veryLong

    /// Max new tokens the engine is allowed to generate for this setting.
    public var maxTokens: Int {
        switch self {
        case .short: return 12
        case .medium: return 32
        case .long: return 64
        case .veryLong: return 128
        }
    }

    public var displayName: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        case .veryLong: return "Very Long"
        }
    }
}
