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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
    ],
    targets: [
        .executableTarget(
            name: "Slashgrab",
            dependencies: [
                "SlashgrabCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
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
