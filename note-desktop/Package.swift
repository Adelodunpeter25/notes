// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Note",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Note", targets: ["Note"]),
        .library(name: "NoteCore", targets: ["NoteCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NoteCore",
            dependencies: [],
            path: "Sources",
            exclude: ["App"]
        ),
        .executableTarget(
            name: "Note",
            dependencies: [
                "NoteCore"
            ],
            path: "Sources/App"
        ),
        .testTarget(
            name: "NoteTests",
            dependencies: ["NoteCore"],
            path: "Tests"
        )
    ]
)
