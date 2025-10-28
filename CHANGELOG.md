# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[Unreleased]: https://github.com/sunxiangyu/Astral/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sunxiangyu/Astral/releases/tag/v1.0.0

