//
//  PhysicalEphemeris.swift
//

import Foundation
import simd

// MARK: - ApparentPhysical

/// Geocentric physical observing quantities of a body at one instant.
///
/// Light-time is applied: the body is placed where it was when the light that reaches the Earth at `time` left it,
/// and the Sun-body-Earth geometry is evaluated with that position. Aberration, light deflection and nutation are
/// not modelled, and the Sun is taken at the origin of the heliocentric frame (its displacement from the
/// solar-system barycentre is ignored).
public struct ApparentPhysical: Sendable, Hashable {

  // MARK: Lifecycle

  public init(
    body: BodyID,
    distanceAU: Double,
    sunDistanceAU: Double,
    lightTimeMinutes: Double,
    angularDiameterArcsec: Double,
    phaseAngleDeg: Double,
    illuminatedFraction: Double,
    elongationDeg: Double,
    visualMagnitude: Double?,
    subObserverLatitudeDeg: Double?,
    subSolarLatitudeDeg: Double?)
  {
    self.body = body
    self.distanceAU = distanceAU
    self.sunDistanceAU = sunDistanceAU
    self.lightTimeMinutes = lightTimeMinutes
    self.angularDiameterArcsec = angularDiameterArcsec
    self.phaseAngleDeg = phaseAngleDeg
    self.illuminatedFraction = illuminatedFraction
    self.elongationDeg = elongationDeg
    self.visualMagnitude = visualMagnitude
    self.subObserverLatitudeDeg = subObserverLatitudeDeg
    self.subSolarLatitudeDeg = subSolarLatitudeDeg
  }

  // MARK: Public

  public let body: BodyID
  /// Earth-body distance, AU (light-time corrected, like JPL Horizons' `delta`).
  public let distanceAU: Double
  /// Sun-body distance at the time the light left the body, AU.
  public let sunDistanceAU: Double
  /// One-way light time, minutes.
  public let lightTimeMinutes: Double
  /// Equatorial angular diameter of the full disk, arcseconds, from the `pck00011` equatorial radius.
  public let angularDiameterArcsec: Double
  /// Sun-body-Earth angle at the body, degrees (0 = full, 180 = new).
  public let phaseAngleDeg: Double
  /// Illuminated fraction of the disk, `(1 + cos α) / 2`, in `0...1`.
  public let illuminatedFraction: Double
  /// Sun-Earth-body angle at the Earth (solar elongation), degrees.
  public let elongationDeg: Double
  /// Apparent visual magnitude, see ``PlanetaryMagnitude``; `nil` for the Moon and Pluto.
  public let visualMagnitude: Double?
  /// Planetocentric latitude of the sub-Earth point, degrees; `nil` for the Moon.
  ///
  /// From the mean `pck00011` pole (no nutation or libration terms). For Saturn this is the ring inclination `B`.
  public let subObserverLatitudeDeg: Double?
  /// Planetocentric latitude of the sub-solar point, degrees; `nil` for the Moon and the Sun.
  public let subSolarLatitudeDeg: Double?
}

// MARK: - SolarSystem physical quantities

extension SolarSystem {

  /// The geocentric physical observing quantities of `id` at `time`.
  ///
  /// ```swift
  /// let saturn = SolarSystem().physical(of: .saturn, at: JulianDate(Date()))
  /// saturn?.visualMagnitude   // includes the rings when they are visible
  /// ```
  ///
  /// Time is treated as TT (see ``JulianDate``). The planetary positions come from the Keplerian element model
  /// (see ``SolarSystem``), so the results are only as good as it is: expect about 0.1° in the phase angle, a few
  /// tenths of a percent in the angular diameter and a few hundredths of a magnitude, with larger errors for
  /// the giant planets (see the tests for measured values).
  ///
  /// - Returns: `nil` for the Earth, or when the system lacks the Earth or the body.
  public func physical(of id: BodyID, at time: JulianDate) -> ApparentPhysical? {
    guard id != .earth, body(id) != nil, let radii = PhysicalConstants.radii(of: id),
          let earth = snapshot(at: time).position(of: .earth)
    else { return nil }

    // Light-time: place the body where it was `tau` ago.
    var tau = 0.0
    var target = SIMD3<Double>.zero
    if id != .sun {
      for _ in 0..<4 {
        let retarded = snapshot(at: JulianDate(days: time.days - tau))
        guard let position = retarded.position(of: id) else { return nil }
        target = position
        tau = simd_length(target - earth) / Self.speedOfLightAUPerDay
      }
    }

    let toObserver = earth - target
    let toSun = -target
    let distance = simd_length(toObserver)
    let sunDistance = simd_length(toSun)

    let phase: Double
    let elongation: Double
    if id == .sun {
      phase = 0
      elongation = 0
    } else {
      phase = Self.angle(between: toSun, toObserver)
      elongation = Self.angle(between: -earth, target - earth)
    }

    let radiusAU = radii.a / Units.kmPerAU
    let angularDiameter = 2 * asin(min(1, radiusAU / distance)) / Units.degToRad * 3600

    // Sub-observer and sub-solar latitudes from the pole direction.
    var subObserver: Double?
    var subSolar: Double?
    if let pole = PhysicalConstants.pole(of: id)?.eclipticDirection(centuries: time.centuriesSinceJ2000) {
      subObserver = asin(max(-1, min(1, simd_dot(pole, toObserver / distance)))) / Units.degToRad
      if id != .sun {
        subSolar = asin(max(-1, min(1, simd_dot(pole, toSun / sunDistance)))) / Units.degToRad
      }
    }

    let year = 2000 + (time.days - JulianDate.j2000.days) / 365.25
    let magnitude = PlanetaryMagnitude.visualMagnitude(
      of: id, sunDistanceAU: id == .sun ? 1 : sunDistance, earthDistanceAU: distance, phaseAngleDeg: phase,
      subObserverLatitudeDeg: subObserver, subSolarLatitudeDeg: subSolar, year: year)

    return ApparentPhysical(
      body: id,
      distanceAU: distance,
      sunDistanceAU: sunDistance,
      lightTimeMinutes: tau * 1440,
      angularDiameterArcsec: angularDiameter,
      phaseAngleDeg: phase,
      illuminatedFraction: (1 + cos(phase * Units.degToRad)) / 2,
      elongationDeg: elongation,
      visualMagnitude: magnitude,
      subObserverLatitudeDeg: subObserver,
      subSolarLatitudeDeg: subSolar)
  }

  // MARK: Internal

  /// Speed of light, AU per day (299 792.458 km/s).
  static let speedOfLightAUPerDay = 299_792.458 * 86_400 / Units.kmPerAU

  /// Angle between two vectors, degrees.
  static func angle(between a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    let c = simd_dot(a, b) / (simd_length(a) * simd_length(b))
    return acos(max(-1, min(1, c))) / Units.degToRad
  }
}
