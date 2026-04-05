// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clip", targets: ["Clip"]),
        .executable(name: "clip", targets: ["ClipCLI"]),
        .library(name: "ClipCore", targets: ["ClipCore"]),
    ],
    targets: [
        .target(
            name: "ClipCore",
            path: "Sources/ClipCore"
        ),
        .executableTarget(
            name: "Clip",
            dependencies: ["ClipCore"],
            path: "Sources",
            exclude: ["ClipCore", "ClipCLI"]
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
