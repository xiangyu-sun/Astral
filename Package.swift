// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// The airbnb/swift package is only needed by contributors, for its `format` command plugin
// (`swift package plugin format`, used by CI and documented in CONTRIBUTING.md). It is not wired to any
// target, so it is opt-in: set `ASTRAL_DEV_TOOLS=1` to add it. Consumers of Astral never see it in their
// dependency graph.
let includeDevTools = ProcessInfo.processInfo.environment["ASTRAL_DEV_TOOLS"] != nil

let package = Package(
  name: "Astral",
  platforms: [
    .macOS(.v10_13),
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
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
  ] + (includeDevTools ? [.package(url: "https://github.com/airbnb/swift", from: "1.0.0")] : []),
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "Astral",
      dependencies: [
        .product(name: "Numerics", package: "swift-numerics"),
      ],
      exclude: ["Eclipse/Data"]),
    .testTarget(
      name: "AstralTests",
      dependencies: ["Astral"],
      exclude: [
        "Ephemeris/Fixtures/raw",
        "Ephemeris/Fixtures/make_fixture.py",
        "Ephemeris/Fixtures/make_svs_libration_fixture.py",
        "Ephemeris/Fixtures/SPK/raw",
        "Ephemeris/Fixtures/SPK/make_tiny_kernel.py",
        "Ephemeris/Fixtures/SPK/make_spk_fixture.py",
        "Eclipse/Fixtures/raw",
        "Eclipse/Fixtures/make_eclipse_fixture.py",
      ],
      resources: [
        .copy("Ephemeris/Fixtures/horizons.json"),
        .copy("Ephemeris/Fixtures/svs_libration.json"),
        .copy("Ephemeris/Fixtures/SPK/tiny.bsp"),
        .copy("Ephemeris/Fixtures/SPK/horizons_spk.json"),
        .copy("Eclipse/Fixtures/solar_local.json"),
        .copy("Eclipse/Fixtures/solar_global.json"),
        .copy("Eclipse/Fixtures/lunar_eclipses.json"),
        .copy("Eclipse/Fixtures/transits.json"),
      ]),
  ],
  swiftLanguageModes: [.v6])
