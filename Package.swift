// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftDataAnalyst",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/Nodibell/SwiftSci.git", from: "3.6.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftDataAnalyst",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftDataFrame", package: "SwiftSci"),
                .product(name: "SwiftAgent", package: "SwiftSci"),
                .product(name: "SwiftStats", package: "SwiftSci"),
                .product(name: "SwiftVisualization", package: "SwiftSci")
            ]
        ),
        .testTarget(
            name: "SwiftDataAnalystTests",
            dependencies: ["SwiftDataAnalyst"]
        )
    ]
)
