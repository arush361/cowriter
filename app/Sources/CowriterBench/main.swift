// Benchmark harness for the MLX inference backend. Compiles and links against
// mlx-swift-lm @ main.
//
// KNOWN LIMITATION: running this via a bare `swift run` fails at startup with
// "Failed to load the default metallib" because plain SwiftPM CLI builds do not
// compile/bundle MLX's Metal shader library (`mlx-swift_Cmlx.bundle/default.metallib`).
// MLX initializes Metal at framework startup, so even `--cpu` cannot bypass it
// from the CLI. To actually run inference, build through Xcode (an app target or
// a command-line-tool target in an Xcode project), which performs the Metal
// compile + resource bundling. See scaffolding/BUILD-GUIDE.md.
//
// Measures, per model:
//   - model load time
//   - first-token latency  (the number the product lives or dies on: < 100 ms)
//   - full short-suggestion latency
//   - tokens/sec
//   - resident memory delta (RSS) after load
//
// Requires Apple Silicon + Metal + a local MLX model. Not part of the package
// build until wired in per ../README.md.
//
// Usage:
//   swift run cowriter-bench --model-path /path/to/mlx-model [--prompt "Thanks for"] [--runs 5]

import Foundation
import CowriterCore
import CowriterInferenceMLX
import MLX

// MARK: - Arguments

struct Args {
    var modelPath: String?
    var prompt: String = "Thanks for"
    var runs: Int = 5
    /// Force the CPU backend. Useful when the Metal shader library is not
    /// available (e.g. running as a bare `swift run` CLI rather than an app
    /// bundle). CPU latency is not representative of the shipping GPU path.
    var cpu: Bool = false
}

func parseArgs() -> Args {
    var args = Args()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = it.next() {
        switch arg {
        case "--model-path": args.modelPath = it.next()
        case "--prompt":     args.prompt = it.next() ?? args.prompt
        case "--runs":       args.runs = Int(it.next() ?? "") ?? args.runs
        case "--cpu":        args.cpu = true
        default:
            FileHandle.standardError.write(Data("Unknown argument: \(arg)\n".utf8))
        }
    }
    return args
}

// MARK: - Resident memory (RSS) via mach task_info

func residentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
    )
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return kerr == KERN_SUCCESS ? info.resident_size : 0
}

func ms(_ seconds: Double) -> String { String(format: "%.1f ms", seconds * 1000) }
func mb(_ bytes: UInt64) -> String { String(format: "%.0f MB", Double(bytes) / 1_048_576) }

// MARK: - One model run

struct Result {
    let model: String
    let loadSeconds: Double
    let firstTokenSeconds: Double
    let fullSeconds: Double
    let tokenCount: Int
    let rssDeltaBytes: UInt64
    var tokensPerSec: Double { tokenCount > 0 ? Double(tokenCount) / fullSeconds : 0 }
}

func monotonicSeconds() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000 }

func benchmark(model: ModelDescriptor, modelDir: URL, prompt: String, runs: Int) async throws -> Result {
    let engine = MLXInferenceEngine(resolveLocalPath: { _ in modelDir })

    let rssBefore = residentBytes()
    let loadStart = monotonicSeconds()
    try await engine.load(model)
    let loadSeconds = monotonicSeconds() - loadStart
    let rssAfter = residentBytes()

    // Warm-up run (excluded from timings): first inference pays one-time costs.
    _ = try? await engine.generate(prompt: prompt, maxTokens: 8)

    // Print one real continuation so we can eyeball output quality + confirm
    // non-thinking mode (no <think> trace).
    let sample = try await engine.generateTimed(
        prompt: prompt, maxTokens: SuggestionLength.medium.maxTokens
    )
    print("sample continuation: \"\(prompt)\(sample.text)\"\n")

    var firstTokenTimes: [Double] = []
    var fullTimes: [Double] = []
    var tokenCounts: [Int] = []

    for _ in 0..<runs {
        // generateTimed measures first-token and total latency inside the model's
        // isolation, so timing is not skewed by actor hops.
        let stats = try await engine.generateTimed(
            prompt: prompt, maxTokens: SuggestionLength.medium.maxTokens
        )
        firstTokenTimes.append(stats.firstTokenSeconds)
        fullTimes.append(stats.totalSeconds)
        tokenCounts.append(stats.tokenCount)
    }

    func median(_ xs: [Double]) -> Double {
        let s = xs.sorted(); return s.isEmpty ? 0 : s[s.count / 2]
    }

    return Result(
        model: model.displayName,
        loadSeconds: loadSeconds,
        firstTokenSeconds: median(firstTokenTimes),
        fullSeconds: median(fullTimes),
        tokenCount: tokenCounts.max() ?? 0,
        rssDeltaBytes: rssAfter > rssBefore ? rssAfter - rssBefore : 0
    )
}

// MARK: - Main

let args = parseArgs()
guard let modelPath = args.modelPath else {
    FileHandle.standardError.write(Data("Error: --model-path is required\n".utf8))
    exit(2)
}
let modelDir = URL(fileURLWithPath: modelPath)

if args.cpu {
    // Route all MLX ops to the CPU backend (skips the Metal shader library).
    MLX.Device.setDefault(device: Device(.cpu))
    print("(running on CPU backend; latency is NOT representative of the GPU path)\n")
}

// The bench points every descriptor at the same local dir; in a real run you
// would supply one directory per model tier.
let model = ModelRegistry.model(id: "qwen2.5-0.5b") ?? ModelRegistry.all[0]

do {
    print("Benchmarking \(model.displayName) at \(modelDir.path)")
    print("prompt=\"\(args.prompt)\"  runs=\(args.runs)\n")

    let r = try await benchmark(model: model, modelDir: modelDir, prompt: args.prompt, runs: args.runs)

    print("model:           \(r.model)")
    print("load time:       \(ms(r.loadSeconds))")
    print("first token:     \(ms(r.firstTokenSeconds))   target < 100 ms")
    print("full (median):   \(ms(r.fullSeconds))")
    print("tokens/sec:      \(String(format: "%.1f", r.tokensPerSec))")
    print("RSS after load:  \(mb(r.rssDeltaBytes))")
    print("")
    let pass = r.firstTokenSeconds < 0.100
    print(pass ? "PASS: first-token under 100 ms" : "FAIL: first-token over 100 ms target")
} catch {
    FileHandle.standardError.write(Data("Benchmark failed: \(error)\n".utf8))
    exit(1)
}
