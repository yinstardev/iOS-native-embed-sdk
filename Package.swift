// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOS-native-embed-sdk",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "iOS-native-embed-sdk",
            targets: ["iOS-native-embed-sdk"]
        ),
    ],
    targets: [
        .target(
            name: "iOS-native-embed-sdk",
            dependencies: [],
            path: "Sources/iOS-native-embed-sdk"
        ),
        .testTarget(
            name: "iOS-native-embed-sdkTests",
            dependencies: ["iOS-native-embed-sdk"],
            path: "iOS-native-embed-sdkTests"
        ),
    ]
)
