import Foundation

/// The set of models the app offers, and logic for picking a sensible default
/// given the machine's RAM. Real download URLs + checksums are filled in when
/// the inference backend is finalized (Phase 1 decision); these are placeholders
/// with the correct shape.
public enum ModelRegistry {
    public static let all: [ModelDescriptor] = [
        ModelDescriptor(
            id: "small",
            displayName: "Fast (small)",
            approxRAMMB: 300,
            approxDiskMB: 900,
            downloadURL: URL(string: "https://models.cowriter.app/small.bin")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .small
        ),
        ModelDescriptor(
            id: "balanced",
            displayName: "Balanced (medium)",
            approxRAMMB: 1200,
            approxDiskMB: 2600,
            downloadURL: URL(string: "https://models.cowriter.app/balanced.bin")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .medium
        ),
        ModelDescriptor(
            id: "quality",
            displayName: "High quality (large)",
            approxRAMMB: 3200,
            approxDiskMB: 4400,
            downloadURL: URL(string: "https://models.cowriter.app/quality.bin")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .large
        )
    ]

    public static func model(id: String) -> ModelDescriptor? {
        all.first { $0.id == id }
    }

    /// Recommend a default model given available RAM. Leaves headroom so we never
    /// recommend a model that would push a machine into swap.
    public static func recommendedDefault(ramBytes: UInt64) -> ModelDescriptor {
        let ramMB = Int(ramBytes / (1024 * 1024))
        // Require roughly 4x the model's resident size in total RAM as headroom.
        let affordable = all.filter { $0.approxRAMMB * 4 <= ramMB }
        return affordable.max(by: { $0.tier < $1.tier })
            ?? all.min(by: { $0.tier < $1.tier })!
    }
}
