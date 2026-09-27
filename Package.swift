// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TagLookupCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "TagLookupCore", targets: ["TagLookupCore"])],
    targets: [
        .target(name: "TagLookupCore", path: "Core"),
        .testTarget(name: "TagLookupCoreTests", dependencies: ["TagLookupCore"], path: "Tests")
    ]
)
