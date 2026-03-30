// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenLumina",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenLumina", targets: ["OpenLumina"])
    ],
    targets: [
        .executableTarget(
            name: "OpenLumina",
            path: "OpenLumina/Sources"
        ),
        .testTarget(
            name: "OpenLuminaTests",
            dependencies: ["OpenLumina"],
            path: "OpenLuminaTests"
        )
    ]
)
