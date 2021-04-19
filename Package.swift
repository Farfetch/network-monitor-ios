// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "NetworkMonitor",
    platforms: [
        .iOS(.v10),
    ],
    products: [
        .library(
            name: "FNMNetworkMonitor",
            targets: ["FNMNetworkMonitor"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FNMNetworkMonitor",
            dependencies: [],
            path: "NetworkMonitor"),
        .testTarget(
            name: "NetworkMonitorTests",
            dependencies: ["FNMNetworkMonitor"],
            path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
