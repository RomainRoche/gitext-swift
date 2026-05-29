// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitradSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        // Only GitradSDK is a public product. Domain and Data are internal targets.
        .library(name: "GitradSDK", targets: ["GitradSDK"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Data", dependencies: ["Domain"]),
        .target(
            name: "GitradSDK",
            dependencies: ["Domain", "Data"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data"]),
        .testTarget(name: "SDKIntegrationTests", dependencies: ["GitradSDK"]),
    ]
)
