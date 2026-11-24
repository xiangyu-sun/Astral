# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-11-24

### Added
- Dwarf planets: `BodyID.ceres`, `.eris`, `.haumea`, `.makemake` (and `BodyID.dwarfPlanets`), with `Catalog.ceres`,
  `.eris`, `.haumea`, `.makemake` and `Catalog.dwarfPlanets`. They are not part of `Catalog.all` or
  `Catalog.allWithPluto`, so existing systems are unchanged; add them with `SolarSystem(bodies: Catalog.allWithPluto +
  Catalog.dwarfPlanets)`.
- `Body.smallBody`: JPL SBDB osculating elements for a body with no JPL Table 1 row. `SolarSystem.snapshot(at:)` and
  `orbitPath(of:at:samples:)` propagate them (two-body); the dwarf-planet rows use the SBDB elements verbatim.
  Against JPL Horizons the error is about 2e-5 AU two months from the 2026-06-09 epoch and 7e-4 AU a year away.
- Small-body fixture: Eris, Haumea and Makemake (SBDB + Horizons); `make_smallbody_fixture.py --only <keys>`.

### Changed
- `PlanetRiseSet` throws `PlanetError.unsupportedBody` for the dwarf planets; `PhysicalConstants.radii(of:)`,
  `pole(of:)` and `PlanetaryMagnitude` return `nil` for them. `SPKFile.naifIDs(for:)` gives their NAIF small-body IDs.

### Fixed
- `make_smallbody_fixture.py` started with a Swift lint comment and could not run.

## [1.3.0] - Unreleased

### Added
- Planetary ephemeris API (ported from the OrbitKit package), all public and `Sendable`:
  - `JulianDate` (with `init?(DateComponents)` bridging the existing Julian day code and `isInSupportedRange`)
  - `OrbitalElements`, `Kepler` (Kepler solver and orbital position, including `longitudeOffsetDeg`)
  - `BodyID`, `Body`, `Units` and `Catalog` (JPL "Approximate Positions of the Planets" Table 1 elements for
    Mercury–Neptune and the Earth–Moon barycentre, Meeus chapter 47 Moon elements, an unverified Pluto row, and
    display-only physical data)
  - `MoonEphemeris.geocentricPosition(elements:T:periodicTerms:)`
  - `MoonPhase` (elongation, illuminated fraction, name, `isWaxing`; `init(sun:earth:moon:)`, `init(date:model:)`).
    It coexists with the free function `moonPhase(date:)`, which still returns the Moon's age in days.
  - `BodyOrientation`, `SolarSystem`, `SystemSnapshot`, `BodyState` (`snapshot(at:)` and `orbitPath(of:at:samples:)`)
- `MoonEphemeris.geocentricPositionSeries(T:)` / `(at:)`: Astral's lunar series as a J2000 ecliptic vector in AU.
  Measured against JPL Horizons at five epochs it is within 39″ in longitude, 63″ in latitude and 0.006 % in
  distance, against up to 372″ / 429″ / 1.4 % for the mean elements plus periodic terms.
- `MoonModel` (`.meanElements`, `.periodicTerms`, `.series`) selects the Moon model of `SolarSystem`
  (`SolarSystem(bodies:moonModel:)`, default `.periodicTerms`). `SolarSystem(bodies:moonPeriodicTerms:)` and the
  `moonPeriodicTerms` property remain as conveniences.
- Tests: JPL Horizons fixture (`Tests/AstralTests/Ephemeris/Fixtures`, with the generator script and raw
  responses), Kepler, orbit, orientation, syzygy, moon phase, Moon model accuracy, and cross-checks against
  `moon_true_longitude(jd2000:)` and `moonPhase(date:)`.
- `Sendable` and `Hashable` conformances on `Observer`, `LocationInfo`, `Elevation`, `Depression`,
  `SunDirection`, `SunError` and `MoonError` (`Elevation` was `Equatable` only).

### Changed
- **Swift 6**: `swift-tools-version: 6.0` and Swift 6 language mode (strict concurrency). Building Astral now
  requires Swift 6.0 / Xcode 16 or newer; supported deployment targets are unchanged (macOS 10.13, iOS 13,
  watchOS 5 in `Package.swift`; recent Xcode versions raise the effective iOS minimum themselves).
- `Table4Row.sincos` is `@Sendable`; the `DateComponents: Comparable` conformance is marked `@retroactive`.
- The `airbnb/swift` package (only needed for its `format` command plugin) is no longer a dependency of consumers:
  it is added to the package graph only when `ASTRAL_DEV_TOOLS` is set, as CI's formatting job and CONTRIBUTING.md
  now do. `Package.resolved` no longer pins `airbnb/swift` and `swift-argument-parser`.
- CI: the `macos-13` runner (no Xcode 16) is replaced by `macos-15`.

## [Unreleased]

### Added
- Comprehensive documentation for all public APIs
- Examples directory with usage examples
- DocC documentation catalog
- CODE_OF_CONDUCT.md
- CONTRIBUTING.md
- GitHub issue and PR templates
- ARCHITECTURE.md explaining calculation algorithms
- ACKNOWLEDGMENTS.md crediting sources

### Changed
- Made core types public (Observer, LocationInfo, etc.)
- Updated README with correct API examples
- Fixed typos in predefined location names (new_delhi, wellington)
- Improved file headers with proper filenames
- Updated platform support documentation

### Fixed
- API access control for public usage
- Example code in README to match actual API
- Typos in Observer.swift and Moon.swift

## [1.0.0] - 2023-01-19

### Added
- Solar calculations (sunrise, sunset, dawn, dusk, noon, midnight)
- Lunar calculations (moonrise, moonset, moon phase)
- Solar position calculations (azimuth, elevation, zenith)
- Twilight calculations (civil, nautical, astronomical)
- Golden hour and blue hour calculations
- Rahukaalam calculations (Vedic astronomy)
- Solar term calculations (Chinese calendar)
- Support for custom observer locations
- Predefined locations (London, Delhi, Riyadh, Wellington, Barcelona)
- Comprehensive test suite
- CI/CD with GitHub Actions
- Code coverage reporting

[1.3.0]: https://github.com/xiangyu-sun/Astral/compare/v1.2.0...HEAD
[Unreleased]: https://github.com/sunxiangyu/Astral/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sunxiangyu/Astral/releases/tag/v1.0.0

