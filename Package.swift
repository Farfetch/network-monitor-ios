// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "NetworkMonitor",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "FNMNetworkMonitor", targets: ["FNMNetworkMonitor"])
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
            path: "Tests", 
            resources: [.process("Resources")]),
    ],
    swiftLanguageVersions: [.v5]
)
