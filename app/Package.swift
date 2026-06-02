// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cowriter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CowriterCore", targets: ["CowriterCore"]),
        .executable(name: "cowriter-demo", targets: ["CowriterDemo"])
    ],
    targets: [
        // Headless, fully-testable core: types, prompt building, the suggestion
        // coordinator, settings, and offline license verification. No GUI, no
        // network, no Metal. This is the part we can build and verify here.
        .target(
            name: "CowriterCore"
        ),
        // A CLI that drives the full suggestion pipeline through the mock engine,
        // so the end-to-end flow is runnable without a GUI or a real model.
        .executableTarget(
            name: "CowriterDemo",
            dependencies: ["CowriterCore"]
        ),
        .testTarget(
            name: "CowriterCoreTests",
            dependencies: ["CowriterCore"]
        )
    ]
)
