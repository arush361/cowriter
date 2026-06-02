import Foundation

/// The set of models the app offers, and logic for picking a sensible default
/// given the machine's RAM.
///
/// We ship the **Qwen3** family (Apache 2.0), which permits commercial
/// redistribution inside a paid app, has official MLX 4-bit builds, and spans a
/// true 0.6B up to 4B so each tier is the same family (one tokenizer + prompt
/// format). Run these in non-thinking mode (`/no_think`): the hybrid reasoning
/// trace would blow the inline-latency budget. See plan/03-tech-stack.md.
///
/// `downloadURL` points at the Hugging Face repo. MLX models are multi-file
/// snapshots resolved by the Hub, not a single checksummed blob, so `sha256` is
/// a placeholder until the loader verifies per-file digests. RAM/disk figures
/// are estimates pending the Phase 1 benchmark on real hardware.
public enum ModelRegistry {
    public static let all: [ModelDescriptor] = [
        ModelDescriptor(
            id: "qwen3-0.6b",
            displayName: "Fast",
            approxRAMMB: 700,
            approxDiskMB: 450,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-0.6B-MLX-4bit")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .small
        ),
        ModelDescriptor(
            id: "qwen3-1.7b",
            displayName: "Balanced",
            approxRAMMB: 1500,
            approxDiskMB: 1100,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-1.7B-MLX-4bit")!,
            sha256: "0000000000000000000000000000000000000000000000000000000000000000",
            tier: .medium
        ),
        ModelDescriptor(
            id: "qwen3-4b",
            displayName: "High quality",
            approxRAMMB: 3200,
            approxDiskMB: 2400,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-4B-MLX-4bit")!,
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
