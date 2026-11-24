//
//  PlanetaryMagnitude.swift
//

import Foundation

/// Apparent visual magnitudes of the planets, after Mallama & Hilton (2018), "Computing apparent planetary
/// magnitudes for The Astronomical Almanac", Astronomy and Computing 25, 10-24 (arXiv:1808.01973).
///
/// All formulas have the form `V = 5 log10(r d) + V1(0) + phase function`, where `r` is the Sun-planet distance
/// and `d` the Earth-planet distance in AU, and `α` is the Sun-planet-observer phase angle in degrees.
///
/// | Body | Paper | Notes |
/// |---|---|---|
/// | Mercury | Eq. 2 | 6th-order polynomial in α |
/// | Venus | Eq. 3, 4 | piecewise, break at α = 163.7° |
/// | Mars | Eq. 6, 7 | **without** the sub-Earth longitude and areocentric longitude corrections (see below) |
/// | Jupiter | Eq. 8, 9 | Eq. 9 (Cassini phase curve) for α > 12° |
/// | Saturn | Eq. 10, 11, 12 | globe plus rings when α < 6.5° and ring inclination < 27°, otherwise globe only |
/// | Uranus | Eq. 14 | depends on the planetographic sub-observer and sub-solar latitudes; phase term omitted |
/// | Neptune | Eq. 16 | brightness depends on the year; phase term omitted |
///
/// Mars: the paper adds two tabulated corrections to the disk-integrated magnitude, one for the longitude of the
/// sub-Earth meridian of the illuminated disk (which needs the planet's rotation phase and changes by up to
/// ±0.06 mag over 24.6 h, RMS 0.035 mag) and one for the areocentric longitude of the Sun. Both are tables that
/// are not transcribed here, so the Mars magnitude is the longitude-averaged value and carries that scatter.
///
/// Uranus and Neptune: the paper's Eq. 15 and Eq. 17 add a small phase term (at most 0.02 and 0.015 mag as seen
/// from Earth). JPL Horizons does not apply them for geocentric ephemerides, and neither does this
/// implementation, so that the values agree with Horizons.
public enum PlanetaryMagnitude {

  // MARK: Public

  /// The apparent visual magnitude of a body, or `nil` when the formula is not defined for it or the phase
  /// angle is outside the range of the fit.
  ///
  /// - Parameters:
  ///   - id: The body. Mercury, Venus, Mars, Jupiter, Saturn, Uranus and Neptune, plus the Sun
  ///     (`-26.74 + 5 log10(d)`). The Earth, the Moon and Pluto return `nil`.
  ///   - sunDistanceAU: Sun-body distance `r`, AU.
  ///   - earthDistanceAU: Observer-body distance `d`, AU.
  ///   - phaseAngleDeg: Sun-body-observer angle α, degrees.
  ///   - subObserverLatitudeDeg: Planetocentric latitude of the sub-observer point, degrees. For Saturn this is
  ///     the ring inclination `β_E` as seen from the observer. Needed for Saturn's ring term and for Uranus.
  ///   - subSolarLatitudeDeg: Planetocentric latitude of the sub-solar point, degrees (`β_S` for Saturn).
  ///   - year: The date as a decimal CE year, used by Neptune.
  public static func visualMagnitude(
    of id: BodyID,
    sunDistanceAU r: Double,
    earthDistanceAU d: Double,
    phaseAngleDeg a: Double,
    subObserverLatitudeDeg: Double? = nil,
    subSolarLatitudeDeg: Double? = nil,
    year: Double = 2000
  ) -> Double? {
    guard r > 0, d > 0, a >= 0 else { return nil }
    let distanceTerm = 5 * log10(r * d)
    switch id {
    case .sun:
      return -26.74 + 5 * log10(d)

    case .mercury:
      guard a <= 180 else { return nil }
      return distanceTerm + mercury(a)

    case .venus:
      if a <= 163.7 { return distanceTerm + venusLow(a) }
      return a < 179 ? distanceTerm + venusHigh(a) : nil

    case .mars:
      return distanceTerm + (a <= 50 ? marsLow(a) : marsHigh(a))

    case .jupiter:
      if a <= 12 { return distanceTerm + jupiterLow(a) }
      return a < 130 ? distanceTerm + jupiterHigh(a) : nil

    case .saturn:
      return saturn(
        distanceTerm: distanceTerm,
        phaseAngleDeg: a,
        subObserverLatitudeDeg: subObserverLatitudeDeg,
        subSolarLatitudeDeg: subSolarLatitudeDeg
      )

    case .uranus:
      guard let e = subObserverLatitudeDeg, let s = subSolarLatitudeDeg else { return nil }
      return distanceTerm + uranus(subObserverLatitudeDeg: e, subSolarLatitudeDeg: s)

    case .neptune:
      return distanceTerm + neptune(year: year)

    case .earth, .moon, .pluto, .ceres, .eris, .haumea, .makemake:
      return nil
    }
  }

  /// Saturn's magnitude without the rings (Eq. 11 for α ≤ 6°, Eq. 12 up to 150°), or `nil` outside that range.
  public static func saturnGlobeMagnitude(
    sunDistanceAU r: Double,
    earthDistanceAU d: Double,
    phaseAngleDeg a: Double
  ) -> Double? {
    guard r > 0, d > 0, a >= 0 else { return nil }
    return saturnGlobe(distanceTerm: 5 * log10(r * d), phaseAngleDeg: a)
  }

  /// Converts a planetocentric latitude to a planetographic one for a body with flattening `f`
  /// (Eq. 13: `tan φ' = tan φ / (1 - f)^2`), degrees.
  public static func planetographicLatitudeDeg(planetocentricDeg: Double, flattening f: Double) -> Double {
    atan(tan(planetocentricDeg * Units.degToRad) / ((1 - f) * (1 - f))) / Units.degToRad
  }

  // MARK: Private

  /// Uranus flattening from the `pck00011` radii.
  private static let uranusFlattening = 1 - 24_973.0 / 25_559.0

  /// Eq. 2.
  private static func mercury(_ a: Double) -> Double {
    -0.613 + 6.3280e-2 * a - 1.6336e-3 * pow(a, 2) + 3.3644e-5 * pow(a, 3)
      - 3.4265e-7 * pow(a, 4) + 1.6893e-9 * pow(a, 5) - 3.0334e-12 * pow(a, 6)
  }

  /// Eq. 3, 0 < α <= 163.7°.
  private static func venusLow(_ a: Double) -> Double {
    -4.384 - 1.044e-3 * a + 3.687e-4 * pow(a, 2) - 2.814e-6 * pow(a, 3) + 8.938e-9 * pow(a, 4)
  }

  /// Eq. 4, 163.7° < α < 179°.
  private static func venusHigh(_ a: Double) -> Double {
    236.05828 - 2.81914 * a + 8.39034e-3 * a * a
  }

  /// Eq. 6, α <= 50°, without the longitude corrections.
  private static func marsLow(_ a: Double) -> Double {
    -1.601 + 0.02267 * a - 0.0001302 * a * a
  }

  /// Eq. 7, α > 50°, without the longitude corrections.
  private static func marsHigh(_ a: Double) -> Double {
    -0.367 - 0.02573 * a + 0.0003445 * a * a
  }

  /// Eq. 8, α <= 12°.
  private static func jupiterLow(_ a: Double) -> Double {
    -9.395 - 3.7e-4 * a + 6.16e-4 * a * a
  }

  /// Eq. 9, 12° < α < 130°.
  private static func jupiterHigh(_ a: Double) -> Double {
    let x = a / 180
    return -9.428 - 2.5 * log10(1.0 - 1.507 * x - 0.363 * pow(x, 2) - 0.062 * pow(x, 3) + 2.809 * pow(x, 4) - 1.876 * pow(x, 5))
  }

  /// Eq. 10 (globe and rings) when α < 6.5° and the effective inclination is below 27°, otherwise the globe only.
  private static func saturn(
    distanceTerm: Double,
    phaseAngleDeg a: Double,
    subObserverLatitudeDeg: Double?,
    subSolarLatitudeDeg: Double?
  ) -> Double? {
    if let e = subObserverLatitudeDeg, let s = subSolarLatitudeDeg, a < 6.5 {
      // The effective inclination is the geometric mean of the two latitudes when they have the same sign;
      // when they differ the rings are lit from one side and seen from the other (backlit, very faint) and the
      // paper sets it to zero.
      let effective = e * s > 0 ? (abs(e) * abs(s)).squareRoot() : 0
      if effective < 27 {
        let sinB = sin(effective * Units.degToRad)
        return distanceTerm - 8.914 - 1.825 * sinB + 0.026 * a - 0.378 * sinB * exp(-2.25 * a)
      }
    }
    return saturnGlobe(distanceTerm: distanceTerm, phaseAngleDeg: a)
  }

  /// Eq. 11 for α ≤ 6°, Eq. 12 for 6° < α ≤ 150°.
  private static func saturnGlobe(distanceTerm: Double, phaseAngleDeg a: Double) -> Double? {
    guard a <= 150 else { return nil }
    if a <= 6 {
      return distanceTerm - 8.95 - 3.7e-4 * a + 6.16e-4 * a * a
    }
    return distanceTerm - 8.94 + 2.446e-4 * a + 2.672e-4 * a * a - 1.505e-6 * pow(a, 3) + 4.767e-9 * pow(a, 4)
  }

  /// Eq. 14: `-7.110 - 8.4e-4 φ'` with `φ'` the mean of the absolute planetographic sub-observer and sub-solar
  /// latitudes. The inputs are planetocentric and are converted with Eq. 13.
  private static func uranus(subObserverLatitudeDeg: Double, subSolarLatitudeDeg: Double) -> Double {
    let f = uranusFlattening
    let e = abs(planetographicLatitudeDeg(planetocentricDeg: subObserverLatitudeDeg, flattening: f))
    let s = abs(planetographicLatitudeDeg(planetocentricDeg: subSolarLatitudeDeg, flattening: f))
    return -7.110 - 8.4e-4 * (e + s) / 2
  }

  /// Eq. 16 (the year-dependent `V1(0)`; the phase term of Eq. 17 is omitted).
  private static func neptune(year t: Double) -> Double {
    if t < 1980 { return -6.89 }
    if t <= 2000 { return -6.89 - 0.0054 * (t - 1980) }
    return -7.00
  }

}
