// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubusCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SubusCore", targets: ["SubusCore"])],
    targets: [
        .target(name: "SubusCore"),
        .testTarget(
            name: "SubusCoreTests",
            dependencies: ["SubusCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
