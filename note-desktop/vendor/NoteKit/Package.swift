// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NoteKit", targets: ["NoteKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NoteKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "NoteKitTests",
            dependencies: ["NoteKit"],
            path: "Tests"
        )
    ]
)
