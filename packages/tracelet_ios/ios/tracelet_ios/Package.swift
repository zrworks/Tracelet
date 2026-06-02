// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tracelet_ios",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "tracelet-ios", targets: ["tracelet_ios"])
    ],
    dependencies: [
        // Consumed via Swift Package Manager when imported as a Flutter plugin.
        // It points to the root of the Tracelet monorepo where the SPM configuration resides.
        .package(url: "https://github.com/Ikolvi/Tracelet.git", revision: "sdk-ios-v3.0.1"),
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "tracelet_ios",
            dependencies: [
                .product(name: "TraceletSDK", package: "Tracelet"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/tracelet_ios"
        )
    ]
)
