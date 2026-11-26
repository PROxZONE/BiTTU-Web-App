// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BiTTU",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BiTTU", targets: ["BiTTU"])
    ],
    dependencies: [
        // Auto-update framework (Phase 4: Distribution).
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "BiTTU",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/BiTTU",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)