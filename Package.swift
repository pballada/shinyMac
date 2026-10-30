// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShinyMac",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ShinyMac", targets: ["ShinyMac"]),
        .library(name: "ShinyCore", targets: ["ShinyCore"]),
    ],
    targets: [
        // Scanning, sizing and cleaning engine. Pure Foundation, no UI, fully testable.
        .target(name: "ShinyCore"),

        // The SwiftUI app. UI code is main-actor isolated by default.
        .executableTarget(
            name: "ShinyMac",
            dependencies: ["ShinyCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        .testTarget(name: "ShinyCoreTests", dependencies: ["ShinyCore"]),
    ]
)
