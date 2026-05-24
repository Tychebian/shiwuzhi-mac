// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShiWuZhi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ShiWuZhi",
            path: "Sources/ShiWuZhi",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
