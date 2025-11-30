// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiniSwiftEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MiniSwiftEditor",
            targets: ["MiniSwiftEditor"]
        ),
    ],
    targets: [
        .target(
            name: "MiniSwiftEditor",
            dependencies: [],
            path: "Sources/MiniSwiftEditor"
        ),
        .testTarget(
            name: "MiniSwiftEditorTests",
            dependencies: ["MiniSwiftEditor"],
            path: "Tests/MiniSwiftEditorTests"
        ),
    ]
)
