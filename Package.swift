// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "NpmRemoteControl",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "NpmRemoteControlLib", type: .dynamic, targets: ["NpmRemoteControlLib"]),
    ],
    targets: [
        .target(
            name: "NpmRemoteControlLib",
            path: "Sources/NpmRemoteControlLib"
        ),
        .executableTarget(
            name: "NpmRemoteControl",
            dependencies: ["NpmRemoteControlLib"],
            path: "Sources/NpmRemoteControl"
        ),
    ]
)
