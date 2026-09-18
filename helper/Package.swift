// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ZoteroMetadataHelper",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "ZoteroMetadataHelper", targets: ["ZoteroMetadataHelper"])
    ],
    targets: [
        .executableTarget(
            name: "ZoteroMetadataHelper",
            path: "Sources/ZoteroMetadataHelper"
        ),
        .testTarget(
            name: "ZoteroMetadataHelperTests",
            dependencies: ["ZoteroMetadataHelper"],
            path: "Tests/ZoteroMetadataHelperTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
