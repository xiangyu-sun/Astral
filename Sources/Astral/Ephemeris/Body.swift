//
//  Body.swift
//

import Foundation
import simd

// MARK: - BodyID

/// Identifies a body of the solar system.
public enum BodyID: String, Sendable, CaseIterable, Identifiable {
  case sun
  case mercury
  case venus
  case earth
  case moon
  case mars
  case jupiter
  case saturn
  case uranus
  case neptune
  case pluto
  /// Dwarf planets other than Pluto. Their orbits come from JPL Small-Body Database elements (``Body/smallBody``).
  case ceres
  case eris
  case haumea
  case makemake

  // MARK: Public

  /// Ceres, Eris, Haumea and Makemake (Pluto, whose row predates them, is not included).
  public static let dwarfPlanets: [BodyID] = [.ceres, .eris, .haumea, .makemake]

  public var id: String {
    rawValue
  }

  public var displayName: String {
    rawValue.capitalized
  }
}

// MARK: - Body

/// A body of the solar system: its orbit and its physical data.
public struct Body: Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: BodyID,
    parent: BodyID?,
    elements: OrbitalElements?,
    radiusKm: Double,
    axialTiltDeg: Double,
    rotationPeriodHours: Double,
    smallBody: SmallBody? = nil
  ) {
    self.id = id
    self.parent = parent
    self.elements = elements
    self.radiusKm = radiusKm
    self.axialTiltDeg = axialTiltDeg
    self.rotationPeriodHours = rotationPeriodHours
    self.smallBody = smallBody
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
  /// Osculating elements from the JPL Small-Body Database, for bodies (the dwarf planets) that have no row in
  /// JPL Table 1. When present, ``SolarSystem`` propagates them (two-body, about the Sun) instead of ``elements``,
  /// which is then `nil`.
  public let smallBody: SmallBody?
}

// MARK: - Units

/// Unit conversion constants.
public enum Units {
  public static let kmPerAU = 149_597_870.7
  public static let degToRad = Double.pi / 180
}
