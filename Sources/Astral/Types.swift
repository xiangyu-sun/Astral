import Foundation

/// Angle measurement in degrees.
public typealias Degrees = Double

/// Angle measurement in radians.
public typealias Radians = Double

/// Duration expressed in minutes.
public typealias Minutes = Double

// MARK: - Elevation

public enum Elevation: Equatable {
  case double(Double)
  case tuple(Double, Double)
}
