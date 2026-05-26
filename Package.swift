// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TraceletSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "TraceletSDK",
            targets: ["TraceletSDK"]
        ),
    ],
    targets: [
        .target(
            name: "TraceletSDK",
            dependencies: ["TraceletCore"],
            path: "sdk/ios/Sources/TraceletSDK",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .binaryTarget(
            name: "TraceletCore",
            url: "https://github.com/Ikolvi/Tracelet/releases/download/sdk-ios-v3.0.1/TraceletCore.xcframework.zip",
            checksum: "66c2b378ea025060cd135693eaf1fa277547863807360456d5e68e3ab4583ef6"
        ),
        .testTarget(
            name: "TraceletSDKTests",
            dependencies: ["TraceletSDK"],
            path: "sdk/ios/Tests/TraceletSDKTests"
        ),
    ]
)
