// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kasane",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KasaneCore", targets: ["KasaneCore"])],
    targets: [
        .target(name: "KasaneCore", path: "Core"),
        .testTarget(name: "KasaneCoreTests", dependencies: ["KasaneCore"], path: "Tests/KasaneCoreTests")
    ]
)
