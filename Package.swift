// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScriptingBridgeGen",
    platforms: [.macOS(.v13), .iOS("999999"), .watchOS("999999"), .tvOS("999999"), .driverKit("999999")],
    products: [
        .executable(name: "sbgen", targets: ["SBGen"]),
        .executable(name: "sbhc", targets: ["SBHC"]),
        .executable(name: "sbsc", targets: ["SBSC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/llvm-swift/ClangSwift", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "SBGen",
            dependencies: [
                "SBHCCore",
                "SBSCCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "SBHC",
            dependencies: [
                "SBHCCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SBHCCore",
            dependencies: [
                "Util",
                .product(name: "Clang", package: "ClangSwift"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "SBSC",
            dependencies: [
                "SBSCCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SBSCCore",
            dependencies: [
                "Util",
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .target(name: "Util"),
        .testTarget(
            name: "SBHCCoreTests",
            dependencies: ["SBHCCore"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "SBSCCoreTests",
            dependencies: ["SBSCCore"],
            resources: [.copy("Resources")]
        ),
    ]
)

// MARK: -
package.targets.forEach {
    $0.swiftSettings = [
        .enableExperimentalFeature("AccessLevelOnImport"),
        .enableUpcomingFeature("InternalImportsByDefault"),
    ]
}
