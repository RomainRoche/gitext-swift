// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitextSwift",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // Only GitextSwift is a public product. Domain and Data are internal targets.
        .library(name: "GitextSwift", targets: ["GitextSwift"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Data", dependencies: ["Domain"]),
        .target(
            name: "GitextSwift",
            dependencies: ["Domain", "Data"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data"]),
        .testTarget(name: "SDKIntegrationTests", dependencies: ["GitextSwift"]),
    ]
)
