//
//  TestTags.swift
//  Centralized tag definitions for the Astral test suite
//
//  This file defines all tags used across the test suite for better organization
//  and filtering. Tags enable you to run specific subsets of tests:
//
//  Examples:
//    swift test --filter .fast
//    swift test --filter .solar
//    swift test --skip .slow
//

import Testing

extension Tag {
  // MARK: - Functional Area Tags

  /// Tests related to solar (sun) calculations
  @Tag static var solar: Self

  /// Tests related to lunar (moon) calculations
  @Tag static var lunar: Self

  /// Tests related to time and date conversions
  @Tag static var time: Self

  /// Tests related to geographic coordinate handling
  @Tag static var coordinate: Self

  /// Tests related to Chinese solar term calculations
  @Tag static var solarTerm: Self

  // MARK: - Calculation Type Tags

  /// Tests for position calculations (azimuth, elevation, zenith)
  @Tag static var position: Self

  /// Tests for rise/set time calculations
  @Tag static var transit: Self

  /// Tests for unit or time system conversions
  @Tag static var conversion: Self

  /// Tests verifying numerical accuracy and precision
  @Tag static var accuracy: Self

  // MARK: - Performance Tags

  /// Quick unit tests (< 1 second)
  @Tag static var fast: Self

  /// Complex calculations that take longer to run
  @Tag static var slow: Self

  // MARK: - Scope Tags

  /// Tests that combine multiple components
  @Tag static var integration: Self

  /// Isolated unit tests for individual functions
  @Tag static var unit: Self

  // MARK: - Quality Tags

  /// Tests for edge cases and boundary conditions
  @Tag static var edge: Self

  /// Regression tests for previously fixed bugs
  @Tag static var regression: Self

  /// Tests that validate input validation and error handling
  @Tag static var validation: Self
}
