// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().resolvingSymlinksInPath()
let traceletRoot = packageDir.appendingPathComponent("../../../..").standardized.path

let package = Package(
    name: "tracelet_sync",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(name: "tracelet-sync", targets: ["tracelet_sync"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "TraceletSDK", path: traceletRoot)
    ],
    targets: [
        .target(
            name: "tracelet_sync",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "TraceletSDK", package: "TraceletSDK"),
                "TraceletSyncFFI"
            ],
            linkerSettings: [
                .unsafeFlags(["-Wl,-multiply_defined,suppress", "-Wl,-ld_classic"])
            ]
        ),
        .binaryTarget(
            name: "TraceletSyncFFI",
            path: "TraceletSyncFFI.xcframework"
        )
    ]
)
