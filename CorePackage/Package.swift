// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FileMintCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FileMintCore", targets: ["FileMintCore"]),
        .executable(name: "filemint-harness", targets: ["FileMintHarness"])
    ],
    targets: [
        .target(name: "FileMintCore"),
        .executableTarget(
            name: "FileMintHarness",
            dependencies: ["FileMintCore"]
        ),
        .testTarget(
            name: "FileMintCoreTests",
            dependencies: ["FileMintCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
