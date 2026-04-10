// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clip", targets: ["Clip"]),
        .executable(name: "clip-tool", targets: ["ClipCLI"]),
        .library(name: "ClipCore", targets: ["ClipCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "ClipCore",
            path: "Sources/ClipCore"
        ),
        .executableTarget(
            name: "Clip",
            dependencies: [
                "ClipCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
            exclude: ["ClipCore", "ClipCLI", "ClipQLPreview"]
        ),
        .executableTarget(
            name: "ClipCLI",
            dependencies: ["ClipCore"],
            path: "Sources/ClipCLI"
        ),
        .testTarget(
            name: "ClipTests",
            dependencies: ["Clip"],
            path: "Tests/ClipTests"
        )
    ]
)
