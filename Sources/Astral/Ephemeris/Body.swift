//
//  Body.swift
//

import Foundation
import simd

/// Identifies a body of the solar system.
public enum BodyID: String, Sendable, CaseIterable, Identifiable {
  case sun, mercury, venus, earth, moon, mars, jupiter, saturn, uranus, neptune, pluto

  public var id: String { rawValue }
  public var displayName: String { rawValue.capitalized }
}

/// A body of the solar system: its orbit and its physical data.
public struct Body: Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: BodyID,
    parent: BodyID?,
    elements: OrbitalElements?,
    radiusKm: Double,
    axialTiltDeg: Double,
    rotationPeriodHours: Double)
  {
    self.id = id
    self.parent = parent
    self.elements = elements
    self.radiusKm = radiusKm
    self.axialTiltDeg = axialTiltDeg
    self.rotationPeriodHours = rotationPeriodHours
  }

  // MARK: Public

  public let id: BodyID
  /// The body this one orbits; `nil` for the Sun.
  public let parent: BodyID?
  /// Orbital elements; `nil` for the Sun.
  public let elements: OrbitalElements?
  public let radiusKm: Double
  public let axialTiltDeg: Double
  /// Sidereal rotation period in hours; negative means retrograde.
  public let rotationPeriodHours: Double
}

/// Unit conversion constants.
public enum Units {
  public static let kmPerAU = 149_597_870.7
  public static let degToRad = Double.pi / 180
}
