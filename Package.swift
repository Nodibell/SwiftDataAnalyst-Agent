// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftDataAnalyst",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Nodibell/SwiftSci.git", from: "3.2.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftDataAnalyst",
            dependencies: [
                .product(name: "SwiftDataFrame", package: "SwiftSci"),
                .product(name: "SwiftAgent", package: "SwiftSci"),
                .product(name: "SwiftDatabase", package: "SwiftSci"),
                .product(name: "SwiftStats", package: "SwiftSci")
            ]
        ),
        .testTarget(
            name: "SwiftDataAnalystTests",
            dependencies: ["SwiftDataAnalyst"]
        )
    ]
)
