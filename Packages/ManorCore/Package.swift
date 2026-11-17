// swift-tools-version:5.9
import PackageDescription

// ManorCore: the platform-independent game (house, hunter, rules, spoken phrases).
// No UIKit / AVFoundation imports allowed here, so it can be unit-tested anywhere (including Linux CI).
let package = Package(
    name: "ManorCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ManorCore", targets: ["ManorCore"]),
    ],
    targets: [
        .target(name: "ManorCore"),
        .testTarget(name: "ManorCoreTests", dependencies: ["ManorCore"]),
    ]
)
