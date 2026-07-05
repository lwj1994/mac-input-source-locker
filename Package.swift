// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacInputSourceLocker",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "InputLocker", targets: ["InputLocker"])
    ],
    targets: [
        .target(name: "MacInputSourceLockerCore"),
        .executableTarget(
            name: "InputLocker",
            dependencies: ["MacInputSourceLockerCore"],
            path: "Sources/InputLocker",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MacInputSourceLockerCoreTests",
            dependencies: ["MacInputSourceLockerCore"]
        )
    ]
)
