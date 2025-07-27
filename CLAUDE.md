# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Astral is a Swift library for astronomical calculations, specifically focused on solar and lunar timings. It's inspired by the Python Astral package and provides calculations for sunrise, sunset, moonrise, moonset, twilight phases, moon phases, and other astronomical phenomena.

## Development Environment

### Building and Testing

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a specific test target
swift test --filter AstralTests

# Run a specific test case
swift test --filter SunCalcTests.testGeom
```

### Platform Support

- **Minimum Swift Version**: 5.9
- **Platforms**: macOS 10.14+, iOS 16+
- **Dependencies**: 
  - `swift-numerics` for mathematical operations
  - `airbnb/swift` for code formatting (development dependency)

## Architecture Overview

### Core Components

**Observer (`Observer.swift`)**
- Represents a geographical location with latitude, longitude, and elevation
- Supports both decimal degrees and DMS (degrees-minutes-seconds) string format
- Elevation can be a simple height or a tuple for obscuring features
- Includes predefined locations (London, Delhi, Riyadh, Wellington, Barcelona)

**Solar Calculations (`Sun.swift`)**
- Central module for all sun-related calculations
- Key functions include:
  - `sunrise()`, `sunset()`, `dawn()`, `dusk()` - solar event times
  - `zenith()`, `azimuth()`, `elevation()` - solar position
  - `golden_hour()`, `blue_hour()`, `twilight()` - special periods
  - `noon()`, `midnight()` - solar extremes
  - `rahukaalam()` - Vedic astronomy calculations

**Lunar Calculations (`Moon.swift`)**
- Complex calculations using lunar series tables
- Key functions include:
  - `moonrise()`, `moonset()` - lunar transit times
  - `azimuth()`, `elevation()`, `zenith()` - lunar position
  - `moonPosition()` - detailed orbital calculations using Table4Row data

**Time Systems (`Julian.swift`)**
- Julian Day and Modified Julian Day conversions
- Julian Century calculations for astronomical algorithms
- Date/time utilities for astronomical computations

**Additional Modules**
- `MoonPhase.swift` - Moon phase calculations using Meeus algorithm
- `SolarTerm.swift` - Chinese solar term calculations (24 solar terms)
- `Types.swift` - Type aliases and enums (Degrees, Radians, Elevation)

### Key Design Patterns

**Error Handling**
- `SunError` for solar calculation errors
- `MoonError` for lunar calculation errors
- Throwing functions for cases where calculations are impossible (e.g., polar regions)

**Coordinate Systems**
- Consistent use of degrees for input/output
- Internal calculations in radians where needed
- Geographic coordinates: positive latitude = North, positive longitude = East

**Time Zone Handling**
- All core calculations performed in UTC
- Results converted to requested time zones
- Extensive use of `DateComponents` for precise time representation

## Testing Strategy

### Test Structure
- Tests are organized by functionality (e.g., `SunCalcTests`, `MoonTests`, `JulianTests`)
- Comprehensive test data with expected values for validation
- Tests cover both basic functionality and edge cases
- Accuracy testing with appropriate tolerances for floating-point calculations

### Key Test Files
- `SunCalcTests.swift` - Tests all solar calculation functions with reference data
- `MoonPostionTests.swift` - Validates lunar position calculations
- `SolarTermTests.swift` - Tests Chinese solar term calculations
- `DateCompoenentHelper.swift` - Date/time utility testing

### Running Specific Tests
```bash
# Test solar calculations
swift test --filter SunCalcTests

# Test moon calculations  
swift test --filter MoonTests

# Test time conversions
swift test --filter JulianTests
```

## Common Development Tasks

### Adding New Solar Events
1. Implement the core calculation in `Sun.swift`
2. Follow the pattern of existing functions (e.g., `sunrise()`, `sunset()`)
3. Use `time_of_transit()` for zenith-based calculations
4. Add comprehensive tests with reference data

### Adding New Lunar Calculations
1. Extend functions in `Moon.swift`
2. Use `moonPosition()` for orbital elements
3. Apply appropriate parallax corrections for Earth-based observations
4. Validate against published astronomical data

### Geographic Coordinate Parsing
- DMS string format: `"51°31'N"` or `"174° 46' 34.4496'' E"`
- Use `convertDegreesMinutesSecondsToDouble()` for parsing
- Handle validation and error cases appropriately

### Working with Time Zones
- Always perform core calculations in UTC
- Use `astimezone()` for final result conversion
- Be aware of daylight saving time transitions
- Test with various global time zones

## Important Notes

### Numerical Precision
- Solar calculations generally accurate to ~1 minute
- Lunar calculations can be more complex due to orbital perturbations
- Use appropriate tolerances in tests (typically 0.001 to 0.1 depending on the calculation)

### Polar Regions
- Many calculations will throw errors near the poles where sun/moon may not rise/set
- Handle `SunError.valueError` and `MoonError.invalidData` appropriately

### Performance Considerations
- Julian Day calculations are fundamental - optimize these if needed
- Lunar calculations involve complex series - Table4Row data is pre-computed
- Consider caching for repeated calculations at the same location/time

### Dependencies
- Keep external dependencies minimal
- `swift-numerics` provides enhanced math functions
- Core functionality should work with standard Swift library