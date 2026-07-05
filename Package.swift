// swift-tools-version: 6.0

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
    dependencies: [
        .package(url: "https://github.com/lwj1994/apple_view_model.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "MacInputSourceLockerCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "InputLocker",
            dependencies: [
                "MacInputSourceLockerCore",
                .product(name: "AppleViewModel", package: "apple_view_model")
            ],
            path: "Sources/InputLocker",
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MacInputSourceLockerCoreTests",
            dependencies: ["MacInputSourceLockerCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
