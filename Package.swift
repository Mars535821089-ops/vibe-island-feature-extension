// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibeIslandMenuSpacer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VibeIslandMenuSpacer", targets: ["VibeIslandMenuSpacer"])
    ],
    targets: [
        .target(name: "SpacerCore"),
        .executableTarget(name: "VibeIslandMenuSpacer", dependencies: ["SpacerCore"]),
        .testTarget(name: "SpacerCoreTests", dependencies: ["SpacerCore"])
    ]
)
