// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BiTTU",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BiTTU",
            path: "Sources/BiTTU",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)