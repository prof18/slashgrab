// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Slashgrab",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "Slashgrab", targets: ["Slashgrab"]),
        .library(name: "SlashgrabCore", targets: ["SlashgrabCore"]),
    ],
    targets: [
        .executableTarget(
            name: "Slashgrab",
            dependencies: ["SlashgrabCore"],
            path: "Sources/Slashgrab"
        ),
        .target(
            name: "SlashgrabCore",
            path: "Sources/SlashgrabCore"
        ),
        .testTarget(
            name: "SlashgrabCoreTests",
            dependencies: ["SlashgrabCore"],
            path: "Tests/SlashgrabCoreTests"
        ),
    ]
)
