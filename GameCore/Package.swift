// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "HoldemUI", targets: ["HoldemUI"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .target(name: "HoldemUI", dependencies: ["GameCore"]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "HoldemUITests", dependencies: ["GameCore", "HoldemUI"]),
    ]
)
