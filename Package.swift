// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RimeManager",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "RimeManager",
            dependencies: ["Yams"],
            path: "RimeManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RimeManagerTests",
            dependencies: ["RimeManager", "Yams"],
            path: "Tests"
        )
    ]
)
