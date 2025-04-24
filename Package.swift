// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOS-native-embed-sdk",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "iOS-native-embed-sdk",
            targets: ["iOS-native-embed-sdk"]
        ),
    ],
    // 1. Declare the external package dependency
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.7") // Use appropriate version
    ],
    targets: [
        .target(
            name: "iOS-native-embed-sdk",
            dependencies: [
                .product(name: "AnyCodable", package: "AnyCodable")
            ],
            path: "Sources/iOS-native-embed-sdk"
        ),
        .testTarget(
            name: "iOS-native-embed-sdkTests",
            dependencies: [
                "iOS-native-embed-sdk",
                // Tests might also need AnyCodable if they interact with it directly
                // .product(name: "AnyCodable", package: "AnyCodable")
            ],
            path: "iOS-native-embed-sdkTests"
        ),
    ]
)
