# Contributing to Astral

Thank you for your interest in contributing to Astral! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to keep our community approachable and respectable.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** - Include code snippets, test cases, or example coordinates
- **Describe the behavior you observed** and what behavior you expected
- **Include details about your environment** - OS, Xcode version, Swift version
- **If possible, include a failing test case**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most Astral users
- **List any alternative solutions** you've considered

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the code style** - We use [Airbnb Swift Style Guide](https://github.com/airbnb/swift)
3. **Add tests** - Your PR should include tests for any new functionality
4. **Update documentation** - Keep documentation up-to-date with code changes
5. **Ensure tests pass** - Run `swift test` before submitting
6. **Write clear commit messages** - Use descriptive commit messages

#### Pull Request Process

1. Update the README.md or relevant documentation with details of changes
2. Ensure all tests pass and add new tests for new functionality
3. Run `swift package plugin format` to format your code
4. The PR will be merged once it receives approval from a maintainer

## Development Setup

### Prerequisites

- **Xcode 14.0+** or **Swift 5.9+**
- **macOS 10.13+**, **iOS 13+**, or **watchOS 5+**

### Building the Project

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/astral.git
cd astral

# Build the package
swift build

# Run tests
swift test

# Run specific tests
swift test --filter SunCalcTests
```

### Code Formatting

We use the Airbnb Swift style guide. Format your code before committing:

```bash
swift package plugin --allow-writing-to-package-directory format .
```

## Code Style Guidelines

### Swift Style

- Follow the [Airbnb Swift Style Guide](https://github.com/airbnb/swift)
- Use 2 spaces for indentation
- Maximum line length of 120 characters
- Use meaningful variable names
- Add documentation comments for all public APIs

### Documentation

- All public types, methods, and properties must have documentation comments
- Use Swift DocC style comments (`///`)
- Include parameter descriptions, return values, and throws documentation
- Provide code examples for complex functionality

Example:
```swift
/// Calculates the sunrise time for a given observer and date.
///
/// - Parameters:
///   - observer: The observer's geographical location
///   - date: The date for which to calculate sunrise
///   - tzinfo: The desired timezone for the result (default: UTC)
/// - Returns: A DateComponents representing the sunrise time
/// - Throws: `SunError.valueError` if sunrise cannot be determined (e.g., polar regions)
///
/// Example:
/// ```swift
/// let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0))
/// let date = Date().components()
/// let sunrise = try sunrise(observer: observer, date: date)
/// ```
public func sunrise(
  observer: Observer,
  date: DateComponents,
  tzinfo: TimeZone = .utc
) throws -> DateComponents
```

### Testing

- Write unit tests for all new functionality
- Aim for high code coverage (target: 80%+)
- Use descriptive test names: `testSunriseCalculationForLondon()`
- Include edge cases and error conditions in tests
- Use reference data from established astronomical sources

## Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests when relevant

Examples:
```
Add moonrise calculation for southern hemisphere
Fix zenith calculation for polar regions
Update documentation for Observer struct
```

## Testing Guidelines

### Writing Tests

- Tests should be deterministic and repeatable
- Use known reference values from astronomical tables
- Test edge cases (polar regions, equator, date boundaries)
- Include accuracy tolerances appropriate for astronomical calculations

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test -v

# Run specific test suite
swift test --filter SunCalcTests

# Run with code coverage
swift test --enable-code-coverage
```

## Astronomical Accuracy

When contributing calculations:

- **Cite your sources** - Reference the algorithm or formula used
- **Validate against known data** - Use published astronomical tables
- **Document accuracy** - State the expected accuracy of calculations
- **Consider edge cases** - Polar regions, date line, time zones

## Questions?

Feel free to open an issue with your question, or reach out to the maintainers.

Thank you for contributing to Astral! 🌟

