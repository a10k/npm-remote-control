// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NpmRemoteControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NpmRemoteControl",
            path: "Sources/NpmRemoteControl"
        ),
    ]
)
