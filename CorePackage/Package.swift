// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FileMintCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FileMintCore", targets: ["FileMintCore"]),
        .library(name: "FileMintImages", targets: ["FileMintImages"]),
        .executable(name: "filemint-harness", targets: ["FileMintHarness"])
    ],
    targets: [
        .target(name: "FileMintCore"),
        .target(name: "FileMintImages", dependencies: ["FileMintCore"]),
        .testTarget(name: "FileMintImagesTests", dependencies: ["FileMintImages", "FileMintCore"]),
        .executableTarget(
            name: "FileMintHarness",
            dependencies: ["FileMintCore"]
        ),
        .testTarget(
            name: "FileMintCoreTests",
            dependencies: ["FileMintCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
