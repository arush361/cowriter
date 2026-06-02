import Foundation

/// Static knowledge about how well specific apps support text capture + ghost
/// text injection. Used to set expectations, pick a rendering strategy, and
/// degrade gracefully in known-problematic apps.
public enum AppCompatibility {
    public enum Support: String, Sendable {
        /// Native text field, both capture and inline injection work well.
        case full
        /// Works, but ghost text must be drawn via the overlay strategy.
        case overlayOnly
        /// Known to be unreliable; engage cautiously or disable by default.
        case degraded
        /// Never engage (e.g. security-sensitive).
        case blocked
    }

    public enum Rendering: String, Sendable {
        case directInsertion
        case overlay
    }

    public struct Profile: Sendable {
        public let bundleID: String
        public let name: String
        public let support: Support
        public let rendering: Rendering

        public init(bundleID: String, name: String, support: Support, rendering: Rendering) {
            self.bundleID = bundleID
            self.name = name
            self.support = support
            self.rendering = rendering
        }
    }

    /// Curated profiles for the flagship apps we tune for. Anything not listed
    /// is treated as `.full` with overlay rendering by default (see `profile`).
    public static let known: [Profile] = [
        .init(bundleID: "com.apple.mail", name: "Mail", support: .full, rendering: .directInsertion),
        .init(bundleID: "com.apple.Notes", name: "Notes", support: .full, rendering: .directInsertion),
        .init(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "notion.id", name: "Notion", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "md.obsidian", name: "Obsidian", support: .full, rendering: .overlay),
        .init(bundleID: "com.microsoft.Word", name: "Word", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.apple.Safari", name: "Safari", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "company.thebrowser.Browser", name: "Arc", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.google.Chrome", name: "Chrome", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.microsoft.Outlook", name: "Outlook", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.linear", name: "Linear", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.hnc.Discord", name: "Discord", support: .overlayOnly, rendering: .overlay),
        .init(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor", support: .degraded, rendering: .overlay)
    ]

    private static let byBundleID: [String: Profile] = Dictionary(
        uniqueKeysWithValues: known.map { ($0.bundleID, $0) }
    )

    /// Resolve the profile for a bundle ID, defaulting unknown apps to full
    /// support with overlay rendering (the safest universal strategy).
    public static func profile(for bundleID: String) -> Profile {
        byBundleID[bundleID] ?? Profile(
            bundleID: bundleID,
            name: bundleID,
            support: .full,
            rendering: .overlay
        )
    }

    /// Whether we should attempt suggestions in this app at all.
    public static func shouldEngage(_ bundleID: String) -> Bool {
        profile(for: bundleID).support != .blocked
    }
}
