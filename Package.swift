// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Paperclip",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Paperclip", path: "Sources")]
)
