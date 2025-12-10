// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Clip",
            targets: ["Clip"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Clip",
            path: "Sources"
        ),
        .testTarget(
            name: "ClipTests",
            dependencies: ["Clip"],
            path: "Tests/ClipTests"
        )
    ]
)
