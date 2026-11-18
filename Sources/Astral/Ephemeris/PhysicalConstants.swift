//
//  PhysicalConstants.swift
//

import Foundation
import simd

// MARK: - TriaxialRadii

/// The triaxial radii of a body, kilometres.
public struct TriaxialRadii: Sendable, Hashable {

  // MARK: Lifecycle

  public init(a: Double, b: Double, c: Double) {
    self.a = a
    self.b = b
    self.c = c
  }

  // MARK: Public

  /// Largest equatorial radius, km. This is the radius JPL Horizons uses for the angular diameter.
  public let a: Double
  /// Smallest equatorial radius, km.
  public let b: Double
  /// Polar radius, km.
  public let c: Double

  /// Mean of the two equatorial radii, km.
  public var equatorialMean: Double {
    (a + b) / 2
  }

  /// Volumetric mean radius `(a b c)^(1/3)`, km.
  public var volumetricMean: Double {
    cbrt(a * b * c)
  }

  /// Polar flattening `(a - c) / a`, using the larger equatorial radius.
  public var flattening: Double {
    (a - c) / a
  }
}

// MARK: - PoleModel

/// A body's rotation pole, as IAU right ascension and declination of the north pole (ICRF / J2000 equator).
///
/// `value(T) = value0 + rate * T`, `T` in Julian centuries since J2000. Periodic nutation/precession terms of the
/// IAU models (for example Neptune's pole wobble of about 0.5°, or Jupiter's) are not included, and neither are
/// prime-meridian (spin) terms.
public struct PoleModel: Sendable, Hashable {

  // MARK: Lifecycle

  public init(ra: Double, raRate: Double, dec: Double, decRate: Double) {
    self.ra = ra
    self.raRate = raRate
    self.dec = dec
    self.decRate = decRate
  }

  // MARK: Public

  /// Right ascension at J2000, degrees.
  public let ra: Double
  /// Right ascension rate, degrees per Julian century.
  public let raRate: Double
  /// Declination at J2000, degrees.
  public let dec: Double
  /// Declination rate, degrees per Julian century.
  public let decRate: Double

  /// Unit vector of the north pole in the J2000 ecliptic frame.
  ///
  /// - Parameter centuries: Julian centuries since J2000.
  public func eclipticDirection(centuries T: Double) -> SIMD3<Double> {
    let alpha = (ra + raRate * T) * Units.degToRad
    let delta = (dec + decRate * T) * Units.degToRad
    let equatorial = SIMD3(cos(delta) * cos(alpha), cos(delta) * sin(alpha), sin(delta))
    let eps = PhysicalConstants.j2000ObliquityDeg * Units.degToRad
    // Equatorial -> ecliptic: rotation about x by -eps.
    return SIMD3(
      equatorial.x,
      equatorial.y * cos(eps) + equatorial.z * sin(eps),
      -equatorial.y * sin(eps) + equatorial.z * cos(eps)
    )
  }
}

// MARK: - PhysicalConstants

/// Physical constants of the bodies from the NASA NAIF generic planetary constants kernel `pck00011.tpc`
/// (<https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc>, N. Bachman 2022-12-27; values follow the
/// IAU/IAG Working Group reports of 2009 and 2015, see the kernel for the per-body references).
///
/// - `BODYnnn_RADII`: the triaxial radii (`radii(of:)`).
/// - `BODYnnn_POLE_RA`, `BODYnnn_POLE_DEC`: the north pole direction, constant and linear-in-T terms only
///   (`pole(of:)`).
///
/// These are separate from `Catalog`, whose `radiusKm` are display values (mostly mean radii) and are not changed.
/// Differences to `Catalog.radiusKm` (km, pck00011 `a` vs Catalog): Mercury 2440.53 vs 2439.7, Earth 6378.1366 vs
/// 6371.0, Mars 3396.19 vs 3389.5, Jupiter 71492 vs 69911, Saturn 60268 vs 58232, Uranus 25559 vs 25362, Neptune
/// 24764 vs 24622. The Catalog values are mean (or reference) radii, so these are not errors, but angular diameters
/// computed from the two will not agree. Sun, Venus, Moon and Pluto agree.
public enum PhysicalConstants {

  /// Mean obliquity of the ecliptic at J2000 (IAU 1976), degrees, as used by SPICE for the J2000 ecliptic frame.
  public static let j2000ObliquityDeg = 23.4392911

  /// The `pck00011.tpc` triaxial radii of a body, or `nil` if the body has none here.
  public static func radii(of id: BodyID) -> TriaxialRadii? {
    switch id {
    case .sun: TriaxialRadii(a: 695_700, b: 695_700, c: 695_700) // BODY10_RADII
    case .mercury: TriaxialRadii(a: 2_440.53, b: 2_440.53, c: 2_438.26) // BODY199_RADII
    case .venus: TriaxialRadii(a: 6_051.8, b: 6_051.8, c: 6_051.8) // BODY299_RADII
    case .earth: TriaxialRadii(a: 6_378.1366, b: 6_378.1366, c: 6_356.7519) // BODY399_RADII
    case .moon: TriaxialRadii(a: 1_737.4, b: 1_737.4, c: 1_737.4) // BODY301_RADII
    case .mars: TriaxialRadii(a: 3_396.19, b: 3_396.19, c: 3_376.20) // BODY499_RADII
    case .jupiter: TriaxialRadii(a: 71_492, b: 71_492, c: 66_854) // BODY599_RADII
    case .saturn: TriaxialRadii(a: 60_268, b: 60_268, c: 54_364) // BODY699_RADII
    case .uranus: TriaxialRadii(a: 25_559, b: 25_559, c: 24_973) // BODY799_RADII
    case .neptune: TriaxialRadii(a: 24_764, b: 24_764, c: 24_341) // BODY899_RADII
    case .pluto: TriaxialRadii(a: 1_188.3, b: 1_188.3, c: 1_188.3) // BODY999_RADII
    }
  }

  /// The `pck00011.tpc` north pole of a body (`BODYnnn_POLE_RA`, `BODYnnn_POLE_DEC`).
  ///
  /// `nil` for the Moon, whose pck00011 pole is dominated by libration terms that this model omits.
  public static func pole(of id: BodyID) -> PoleModel? {
    switch id {
    case .sun: PoleModel(ra: 286.13, raRate: 0, dec: 63.87, decRate: 0)
    case .mercury: PoleModel(ra: 281.0103, raRate: -0.0328, dec: 61.4155, decRate: -0.0049)
    case .venus: PoleModel(ra: 272.76, raRate: 0, dec: 67.16, decRate: 0)
    case .earth: PoleModel(ra: 0, raRate: -0.641, dec: 90, decRate: -0.557)
    case .moon: nil
    case .mars: PoleModel(ra: 317.269202, raRate: -0.10927547, dec: 54.432516, decRate: -0.05827105)
    case .jupiter: PoleModel(ra: 268.056595, raRate: -0.006499, dec: 64.495303, decRate: 0.002413)
    case .saturn: PoleModel(ra: 40.589, raRate: -0.036, dec: 83.537, decRate: -0.004)
    case .uranus: PoleModel(ra: 257.311, raRate: 0, dec: -15.175, decRate: 0)
    case .neptune: PoleModel(ra: 299.36, raRate: 0, dec: 43.46, decRate: 0)
    case .pluto: PoleModel(ra: 132.993, raRate: 0, dec: -6.163, decRate: 0)
    }
  }
}
