// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Astral",
    platforms: [
          .macOS(.v10_15),
          .iOS(.v13), 
          .watchOS(.v6),
          .tvOS(.v13),
          .visionOS(.v1)
      ],
    products: [
        // Default library with all functionality
        .library(
            name: "Astral",
            targets: ["Astral"]),
        // Performance-optimized variant for production use
        .library(
            name: "AstralPerformance",
            type: .static,
            targets: ["Astral"]),
        // Dynamic library for development and testing
        .library(
            name: "AstralDynamic", 
            type: .dynamic,
            targets: ["Astral"]),
    ],
    dependencies: [
        // Swift Numerics for enhanced mathematical operations
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Astral",
            dependencies: [
              .product(name: "Numerics", package: "swift-numerics")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("StrictConcurrency"),
                .define("ENABLE_TESTING", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "AstralTests",
            dependencies: ["Astral"]),
    ]
)
