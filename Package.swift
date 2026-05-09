// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexQuotaMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexQuotaMenuBar", targets: ["CodexQuotaMenuBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexQuotaMenuBar",
            path: "Sources/CodexQuotaMenuBar"
        )
    ]
)
