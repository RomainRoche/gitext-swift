// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitradSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GitradSDK", targets: ["GitradSDK"]),
    ],
    targets: [
        .target(
            name: "GitradSDK",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GitradSDKTests",
            dependencies: ["GitradSDK"]
        ),
    ]
)
