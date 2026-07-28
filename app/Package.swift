// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUPulse",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GPUPulse", targets: ["GPUPulse"])
    ],
    targets: [
        .executableTarget(
            name: "GPUPulse",
            path: "Sources/GPUPulse"
        )
    ]
)
