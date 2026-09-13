// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiverKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Poker", targets: ["Poker"]),
        .library(name: "RiverUI", targets: ["RiverUI"]),
    ],
    targets: [
        .target(name: "Poker"),
        .target(name: "RiverUI", dependencies: ["Poker"]),
        .testTarget(name: "PokerTests", dependencies: ["Poker"], resources: [.copy("Fixtures")]),
    ]
)
