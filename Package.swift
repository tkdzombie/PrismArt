// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismArt",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PrimitiveCore", targets: ["PrimitiveCore"]),
        .executable(name: "PrismArt", targets: ["PrismArt"])
    ],
    targets: [
        .target(name: "PrimitiveCore"),
        .executableTarget(
            name: "PrismArt",
            dependencies: ["PrimitiveCore"],
            path: "Sources/PrimitiveArt"
        ),
        .testTarget(
            name: "PrimitiveCoreTests",
            dependencies: ["PrimitiveCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
