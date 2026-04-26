// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Notes",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/danielsaidi/RichTextKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Notes",
            dependencies: [
                .product(name: "RichTextKit", package: "RichTextKit"),
            ],
            path: "Sources/Notes"
        ),
    ]
)
