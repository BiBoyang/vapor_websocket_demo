// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SignalingShared",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SignalingShared",
            targets: ["SignalingShared"]
        )
    ],
    targets: [
        .target(
            name: "SignalingShared"
        )
    ]
)
