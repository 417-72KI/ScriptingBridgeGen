// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftScripting",
    platforms: [.macOS(.v13), .iOS("999999"), .watchOS("999999"), .tvOS("999999"), .driverKit("999999")],
    products: [
        .executable(name: "sbgen", targets: ["SBGen"]),
        .executable(name: "sbhc", targets: ["SBHC"]),
        .executable(name: "sbsc", targets: ["SBSC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.6.1"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
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
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                "SwiftSoup",
            ]
        ),

    ]
)
