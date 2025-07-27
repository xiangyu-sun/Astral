// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Astral",
  platforms: [
    .macOS(.v10_14),
    .iOS(.v13),
    .watchOS(.v5),
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "Astral",
      targets: ["Astral"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/airbnb/swift", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "Astral",
      dependencies: [
        .product(name: "Numerics", package: "swift-numerics"),
      ]),
    .testTarget(
      name: "AstralTests",
      dependencies: ["Astral"]),
  ])
