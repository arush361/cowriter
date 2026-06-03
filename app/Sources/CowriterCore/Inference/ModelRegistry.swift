import Foundation

/// The set of models the app offers, and logic for picking a sensible default
/// given the machine's RAM.
///
/// We ship the **Qwen2.5-Instruct** family (Apache 2.0): commercial-friendly,
/// official MLX 4-bit builds, and crucially NON-thinking, so it produces clean
/// inline continuations instead of a `<think>` reasoning trace. (Qwen3 was the
/// original pick but its 1.7B build forces thinking, which is unusable for
/// autocomplete - see plan/07 Q2.) One family spans 0.5B -> 3B, same tokenizer.
///
/// `downloadURL` points at the Hugging Face repo. MLX models are multi-file
/// snapshots resolved by the Hub, not a single checksummed blob, so `sha256` is
/// a placeholder until the loader verifies per-file digests. RAM/disk figures
/// are estimates; the 1.5B was measured at ~983 MB resident on Apple Silicon.
public enum ModelRegistry {
    public static let all: [ModelDescriptor] = [
        ModelDescriptor(
            id: "qwen2.5-0.5b",
            displayName: "Fast",
            approxRAMMB: 600,
            approxDiskMB: 350,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .small
        ),
        ModelDescriptor(
            id: "qwen2.5-1.5b",
            displayName: "Balanced",
            approxRAMMB: 1300,
            approxDiskMB: 1000,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .medium
        ),
        ModelDescriptor(
            id: "qwen2.5-3b",
            displayName: "High quality",
            approxRAMMB: 2400,
            approxDiskMB: 1800,
            downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-3B-Instruct-4bit")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .large
        )
    ]

    public static func model(id: String) -> ModelDescriptor? {
        all.first { $0.id == id }
    }

    /// Recommend a default model for a fresh install, given available RAM.
    ///
    /// Policy: **Qwen3-1.7B (medium) is the baseline default for everyone.** It is
    /// the best quality-per-latency point for inline autocomplete and fits the
    /// 8 GB-Mac floor. The 4B (large) model is **opt-in only** and is never
    /// auto-selected, even on high-RAM machines. On machines too constrained for
    /// the medium model, fall back to 0.6B (small). We leave ~4x headroom over a
    /// model's resident size so we never push a machine into swap.
    public static func recommendedDefault(ramBytes: UInt64) -> ModelDescriptor {
        let ramMB = Int(ramBytes / (1024 * 1024))
        let medium = all.first { $0.tier == .medium } ?? all[0]
        let small = all.first { $0.tier == .small } ?? all[0]
        return medium.approxRAMMB * 4 <= ramMB ? medium : small
    }
}
