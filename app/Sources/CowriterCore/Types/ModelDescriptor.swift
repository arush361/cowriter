import Foundation

/// Describes a local model that can be downloaded and loaded. The actual weights
/// are fetched on first run (not bundled) and verified against `sha256`.
public struct ModelDescriptor: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let displayName: String
    /// Approximate resident RAM in megabytes once loaded.
    public let approxRAMMB: Int
    /// Approximate on-disk download size in megabytes.
    public let approxDiskMB: Int
    /// Remote URL the weights are fetched from on first run.
    public let downloadURL: URL
    /// Expected SHA-256 (hex) of the downloaded file, for integrity verification.
    public let sha256: String
    /// Relative quality/speed tier, for sorting and recommendations.
    public let tier: Tier

    public enum Tier: String, Codable, Sendable, Comparable {
        case small   // fast, low RAM, default on constrained machines
        case medium  // balanced
        case large   // highest quality

        private var order: Int {
            switch self {
            case .small: return 0
            case .medium: return 1
            case .large: return 2
            }
        }
        public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.order < rhs.order }
    }

    public init(
        id: String,
        displayName: String,
        approxRAMMB: Int,
        approxDiskMB: Int,
        downloadURL: URL,
        sha256: String,
        tier: Tier
    ) {
        self.id = id
        self.displayName = displayName
        self.approxRAMMB = approxRAMMB
        self.approxDiskMB = approxDiskMB
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.tier = tier
    }
}
