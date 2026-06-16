// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TokenMaxxingCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TokenMaxxingCore",
            targets: ["TokenMaxxingCore"]
        ),
    ],
    targets: [
        .target(
            name: "TokenMaxxingCore"
        ),
        .testTarget(
            name: "TokenMaxxingCoreTests",
            dependencies: ["TokenMaxxingCore"]
        ),
    ]
)
