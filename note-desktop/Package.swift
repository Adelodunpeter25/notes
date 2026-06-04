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
    dependencies: [
        .package(path: "vendor/NoteKit")
    ],
    targets: [
        .target(
            name: "NoteCore",
            dependencies: [
                .product(name: "NoteKit", package: "NoteKit")
            ],
            path: "Sources",
            exclude: ["App"]
        ),
        .executableTarget(
            name: "Note",
            dependencies: [
                "NoteCore",
                .product(name: "NoteKit", package: "NoteKit")
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
