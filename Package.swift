// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotSleep",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotSleep", targets: ["NotSleep"])
    ],
    targets: [
        .executableTarget(
            name: "NotSleep",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
