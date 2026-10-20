// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ExcaliCursor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ExcaliCursor",
            targets: ["ExcaliCursor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ExcaliCursor",
            path: "Sources/ExcaliCursor",
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/canvas.html"),
                .copy("Resources/canvas.js"),
                .copy("Resources/rough.min.js")
            ]
        )
    ]
)
