//
//  MoonEphemeris.swift
//

import Foundation
import simd

/// Geocentric Moon position in the J2000 ecliptic frame, in AU.
///
/// Three models are available (see ``MoonModel``):
/// - mean elements only ("Level A", error up to about 2° in longitude),
/// - mean elements plus the three largest periodic longitude terms ("Level B"),
/// - Astral's lunar series (``geocentricPositionSeries(T:)``).
public enum MoonEphemeris {

  // MARK: Public

  /// Moon position relative to Earth's centre, J2000 ecliptic, AU, from the mean elements.
  ///
  /// - Parameters:
  ///   - elements: The Moon's mean elements (see ``Catalog/moon``).
  ///   - T: Julian centuries since J2000.
  ///   - periodicTerms: When `true`, adds the evection, variation and annual equation terms to the longitude
  ///     (`+1.274°·sin(2D − M′)`, `+0.658°·sin(2D)`, `−0.186°·sin(M☉)`) at the same radius and latitude.
  public static func geocentricPosition(
    elements: OrbitalElements,
    T: Double,
    periodicTerms: Bool
  ) -> SIMD3<Double> {
    let p = Kepler.position(elements: elements, T: T, longitudeOffsetDeg: frameOffsetDeg(T: T))
    guard periodicTerms else { return p }

    let d = Units.degToRad
    let D = (297.8501921 + 445_267.1114034 * T) * d // mean elongation
    let Mm = (134.9633964 + 477_198.8675055 * T) * d // Moon mean anomaly
    let Ms = (357.5291092 + 35_999.0502909 * T) * d // Sun mean anomaly
    let dLon = (1.274 * sin(2 * D - Mm) + 0.658 * sin(2 * D) - 0.186 * sin(Ms)) * d

    // Same radius and latitude, shifted longitude.
    let r = simd_length(p)
    let lat = asin(p.z / r)
    let lon = atan2(p.y, p.x) + dLon
    return SIMD3(r * cos(lat) * cos(lon), r * cos(lat) * sin(lon), r * sin(lat))
  }

  /// Moon position relative to Earth's centre from Astral's lunar series, J2000 ecliptic, AU.
  ///
  /// Astral's series (the internal `moonPosition(jd2000:)`, also behind ``moon_true_longitude(jd2000:)``) returns
  /// right ascension and declination referred to the equinox of date, and a distance in Earth equatorial radii.
  /// This function converts that to the same frame and unit as the other models:
  ///
  /// 1. RA/declination of date → ecliptic longitude/latitude of date, using the mean obliquity of date
  ///    (IAU 1980, as used by `moon_true_longitude(jd2000:)`).
  /// 2. Longitude → J2000 by subtracting general precession, `1.3969713° × T`: the same offset ``MoonEphemeris``
  ///    applies to the mean-element models. Latitude is not adjusted for the (≈47″/century) motion of the ecliptic
  ///    plane.
  /// 3. Distance: Earth radii × 6378.14 km ÷ 149 597 870.7 km per AU.
  ///
  /// No nutation and no ΔT are applied.
  ///
  /// - Parameter T: Julian centuries since J2000.
  /// - Returns: The geocentric Moon position in the J2000 ecliptic frame, AU.
  public static func geocentricPositionSeries(T: Double) -> SIMD3<Double> {
    let jd2000 = T * 36_525
    let position = moonPosition(jd2000: jd2000)
    let ε = obliquity_of_ecliptic(jd2000: jd2000)
    let α = position.right_ascension
    let δ = position.declination

    // Equatorial → ecliptic of date.
    let lonOfDate = atan2(sin(α) * cos(ε) + tan(δ) * sin(ε), cos(α))
    let lat = asin(sin(δ) * cos(ε) - cos(δ) * sin(ε) * sin(α))

    // Precess the longitude to J2000, consistently with the mean-element models.
    let lon = lonOfDate + frameOffsetDeg(T: T) * Units.degToRad
    let r = position.distance * earthEquatorialRadiusKm / Units.kmPerAU
    return SIMD3(r * cos(lat) * cos(lon), r * cos(lat) * sin(lon), r * sin(lat))
  }

  /// Moon position relative to Earth's centre from Astral's lunar series, J2000 ecliptic, AU.
  ///
  /// See ``geocentricPositionSeries(T:)`` for the conventions.
  public static func geocentricPositionSeries(at time: JulianDate) -> SIMD3<Double> {
    geocentricPositionSeries(T: time.centuriesSinceJ2000)
  }

  // MARK: Internal

  /// General precession in longitude, degrees per Julian century.
  ///
  /// The lunar elements (and the series) are referred to the ecliptic of date; subtracting this moves them to the
  /// J2000 frame used everywhere else.
  static let precessionDegPerCentury = 1.3969713

  /// Earth's equatorial radius in km, the unit of the distance returned by Astral's lunar series.
  static let earthEquatorialRadiusKm = 6378.14

  /// Offset in degrees that moves of-date longitudes to the J2000 frame.
  static func frameOffsetDeg(T: Double) -> Double {
    -precessionDegPerCentury * T
  }

}
