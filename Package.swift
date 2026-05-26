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
            checksum: "284d4eb715779ab94a128cb60c3aba4990c11cc2212a466ce2fc7afeea52d548"
        ),
        .testTarget(
            name: "TraceletSDKTests",
            dependencies: ["TraceletSDK"],
            path: "sdk/ios/Tests/TraceletSDKTests"
        ),
    ]
)
