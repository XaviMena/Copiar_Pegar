// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopiaPegaMacOs",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CopiaPegaMacOs", targets: ["CopiaPegaMacOs"])
    ],
    targets: [
        .executableTarget(
            name: "CopiaPegaMacOs",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
