// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "garminy-mac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GarminyCore"),
        .executableTarget(name: "GarminyCompanion", dependencies: ["GarminyCore"],
                         swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "garminy-hook", dependencies: ["GarminyCore"]),
        .testTarget(name: "GarminyCoreTests", dependencies: ["GarminyCore"], resources: [.copy("Fixtures")]),
    ]
)
