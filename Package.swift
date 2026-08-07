// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bonefeed",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bonefeed", targets: ["Bonefeed"])
    ],
    targets: [
        .executableTarget(
            name: "Bonefeed",
            path: "Sources/Bonefeed"
        )
    ]
)
