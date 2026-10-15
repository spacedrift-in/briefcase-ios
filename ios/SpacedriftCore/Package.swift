// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpacedriftCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SpacedriftCore", targets: ["SpacedriftCore"])
    ],
    targets: [
        .target(name: "SpacedriftCore"),
        .testTarget(name: "SpacedriftCoreTests", dependencies: ["SpacedriftCore"])
    ]
)
