// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "NpmRemoteControl",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "NpmRemoteControl",
            path: "Sources/NpmRemoteControl"
        ),
    ]
)
