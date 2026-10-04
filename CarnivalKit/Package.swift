// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarnivalKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "CarnivalKit", targets: ["CarnivalKit"])
    ],
    targets: [
        .target(name: "CarnivalKit")
    ]
)
