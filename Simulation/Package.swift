// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiverSimulation",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [.package(path: "../RiverKit")],
    targets: [.executableTarget(name: "RiverSimulation", dependencies: [
        .product(name: "Poker", package: "RiverKit"),
        .product(name: "RiverUI", package: "RiverKit"),
    ], path: "Sources")]
)
