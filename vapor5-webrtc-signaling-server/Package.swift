// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "vapor-webrtc-signaling",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [
        .package(path: "SignalingShared"),
        .package(url: "https://github.com/vapor/vapor.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SignalingShared", package: "SignalingShared"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
