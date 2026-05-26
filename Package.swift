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
            checksum: "1e89b22321da388186c30f63c5490f99163642c1f272666439e287ec436b578d"
        ),
        .testTarget(
            name: "TraceletSDKTests",
            dependencies: ["TraceletSDK"],
            path: "sdk/ios/Tests/TraceletSDKTests"
        ),
    ]
)
