// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CarnivalKit",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "CarnivalKit", targets: ["CarnivalKit"])
    ],
    targets: [
        .target(name: "CarnivalKit")
    ]
)
