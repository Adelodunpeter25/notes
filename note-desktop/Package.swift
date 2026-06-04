// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Note",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Note", targets: ["Note"])
    ],
    dependencies: [
        .package(path: "vendor/NoteKit")
    ],
    targets: [
        .executableTarget(
            name: "Note",
            dependencies: [
                .product(name: "NoteKit", package: "NoteKit")
            ],
            path: "Sources"
        )
    ]
)
