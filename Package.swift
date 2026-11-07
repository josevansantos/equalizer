// swift-tools-version: 6.0
import PackageDescription

let testingFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

let package = Package(
    name: "Equalizer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Equalizer",
            targets: ["Equalizer"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Equalizer",
            dependencies: [],
            path: "Sources/Equalizer",
            exclude: ["Info.plist", "Equalizer.entitlements"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "EqualizerTests",
            dependencies: ["Equalizer"],
            path: "Tests/EqualizerTests",
            swiftSettings: [
                .unsafeFlags(["-F", testingFrameworkPath])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", testingFrameworkPath,
                    "-framework", "Testing",
                    "-framework", "_Testing_Foundation",
                    "-Xlinker", "-rpath",
                    "-Xlinker", testingFrameworkPath
                ])
            ]
        )
    ]
)
