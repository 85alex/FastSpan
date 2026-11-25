// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FastingAppCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "FastingAppCore",
            targets: ["FastingAppCore"]
        ),
        .executable(
            name: "FastingTestRunner",
            targets: ["FastingTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "FastingAppCore",
            path: "FastingApp/Shared"
        ),
        .executableTarget(
            name: "FastingTestRunner",
            dependencies: ["FastingAppCore"],
            path: "FastingApp/Tests",
            exclude: [
                "FastingEngineTests.swift",
                "NotificationTests.swift",
                "StoreKitTests.swift",
                "CSVExportTests.swift"
            ],
            sources: ["TestMain.swift"]
        )
    ]
)
