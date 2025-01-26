// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "chatClient",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "chatClient",
            targets: ["chatClient"])
    ],
    dependencies: [
        .package(path: "ChatClientCore"),
        .package(path: "WebSocketClient")
    ],
    targets: [
        .executableTarget(
            name: "chatClient",
            dependencies: ["ChatClientCore", "WebSocketClient"],
            path: "Sources")
    ]
)
