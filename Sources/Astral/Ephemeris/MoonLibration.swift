//
//  MoonLibration.swift
//

import Foundation

/// The Moon's libration, orientation and illumination as seen from the centre of the Earth.
///
/// Implements Jean Meeus, *Astronomical Algorithms* (2nd ed.), chapter 53 ("Ephemeris for Physical Observations
/// of the Moon": optical and physical libration, position angle of the axis, selenographic position of the Sun)
/// and chapter 48 ("Illuminated Fraction of the Disk of a Planet": illuminated fraction, position angle of the
/// bright limb).
///
/// The geocentric Moon position comes from Astral's lunar series (the same one behind
/// ``MoonEphemeris/geocentricPositionSeries(T:)``) and the Sun from Astral's solar position, both with the
/// nutation of the existing `nutation(juliancentury:)`.
///
/// Conventions (those of Meeus and of NASA's "Moon Phase and Libration" tables):
/// - ``longitude`` and ``latitude`` are the selenographic coordinates of the sub-Earth point, the apparent centre of
///   the disc. Longitudes are positive east, latitudes positive north.
/// - Position angles are measured from celestial north through east, in degrees, 0...360.
///   ``positionAngleOfAxis`` and ``brightLimbPositionAngle`` refer to the equator and equinox of date (Meeus);
///   ``positionAngleOfAxisJ2000`` refers to the J2000 pole, which is what NASA's tables use.
/// - ``subSolarLongitude`` and ``subSolarLatitude`` locate the point where the Sun is at the zenith.
///
/// UTC is treated as TT: no ΔT is applied (about 69 s at present, which changes the angles by about 0.01°).
///
/// ```swift
/// let libration = MoonLibration(date: Date())
/// print(libration.longitude, libration.latitude, libration.illuminatedFraction)
/// ```
public struct MoonLibration: Sendable, Hashable {

  // MARK: Lifecycle

  /// Creates the libration from explicit geocentric apparent positions (Meeus's inputs).
  ///
  /// - Parameters:
  ///   - time: The instant (UTC is treated as TT). Used for the mean arguments and the nutation.
  ///   - moonLongitude: Moon's geocentric apparent ecliptic longitude (including nutation), degrees.
  ///   - moonLatitude: Moon's geocentric ecliptic latitude, degrees.
  ///   - moonDistanceKm: Earth-centre to Moon-centre distance, km.
  ///   - sunLongitude: Sun's geocentric apparent ecliptic longitude, degrees.
  ///   - sunDistanceAU: Earth–Sun distance, astronomical units.
  public init(
    at time: JulianDate,
    moonLongitude: Double,
    moonLatitude: Double,
    moonDistanceKm: Double,
    sunLongitude: Double,
    sunDistanceAU: Double
  ) {
    let T = time.centuriesSinceJ2000
    let jd2000 = time.days - JulianDate.j2000.days
    let d2r = Units.degToRad
    let r2d = 1 / d2r

    // Mean arguments (degrees), Meeus chapter 47 / 53.
    let Mp = moon_mean_anomaly(jd2000: jd2000) * 360 // M'
    let F = moon_argument_of_latitude(jd2000: jd2000) * 360
    let D = moon_mean_elongation_from_sun(jd2000: jd2000) * 360
    let M = sun_mean_anomoly(jd2000: jd2000) * 360
    let Om = longitude_lunar_ascending_node(jd2000: jd2000) * 360 // Ω

    let nut = nutation(juliancentury: T)
    let dPsi = nut.longitude / 3600 // degrees
    let dEps = nut.obliquity / 3600
    let epsilon = mean_obliquity_of_ecliptic(juliancentury: T) + dEps // true obliquity, degrees

    // Inclination of the mean lunar equator to the ecliptic: 1°32'32.7".
    let I = 1.54242 * d2r

    // Physical libration, degrees (Meeus p. 373).
    let (rho, sigma, tau) = Self.physicalLibrationTerms(T: T, M: M, Mp: Mp, F: F, D: D, Om: Om)

    // Optical + physical libration of a given geocentric direction (λ, β) as seen from the Moon.
    func libration(longitude lam: Double, latitude bet: Double) -> (l: Double, b: Double, optical: (l: Double, b: Double)) {
      let W = (lam - dPsi - Om) * d2r
      let beta = bet * d2r
      let A = atan2(sin(W) * cos(beta) * cos(I) - sin(beta) * sin(I), cos(W) * cos(beta))
      let lOptical = Self.wrapSigned(A * r2d - F)
      let bOptical = asin(-sin(W) * cos(beta) * sin(I) - sin(beta) * cos(I)) * r2d
      let lPhysical = -tau + (rho * cos(A) + sigma * sin(A)) * tan(bOptical * d2r)
      let bPhysical = sigma * cos(A) - rho * sin(A)
      return (Self.wrapSigned(lOptical + lPhysical), bOptical + bPhysical, (lOptical, bOptical))
    }

    // Sub-Earth point (the libration proper).
    let earth = libration(longitude: moonLongitude, latitude: moonLatitude)
    longitude = earth.l
    latitude = earth.b
    opticalLongitude = earth.optical.l
    opticalLatitude = earth.optical.b
    physicalLongitude = Self.wrapSigned(earth.l - earth.optical.l)
    physicalLatitude = earth.b - earth.optical.b

    // Position angle of the axis (Meeus p. 373).
    let V = (Om + dPsi + sigma / sin(I)) * d2r
    let eps = epsilon * d2r
    let X = sin(I + rho * d2r) * sin(V)
    let Y = sin(I + rho * d2r) * cos(V) * cos(eps) - cos(I + rho * d2r) * sin(eps)
    let omega = atan2(X, Y)
    let moonEquatorial = Self.equatorial(longitude: moonLongitude, latitude: moonLatitude, epsilon: eps)
    let sinP = (X * X + Y * Y).squareRoot() * cos(moonEquatorial.ra - omega) / cos(earth.b * d2r)
    // P is small (|P| < ~25°) so the arcsine is unambiguous; wrap to 0...360 like the NASA tables.
    let axisAngle = asin(max(-1, min(1, sinP))) * r2d
    positionAngleOfAxis = Self.wrapPositive(axisAngle)
    let precessionRotation = (2004.3109 * T / 3600) * sin(moonEquatorial.ra) / cos(moonEquatorial.dec)
    positionAngleOfAxisJ2000 = Self.wrapPositive(axisAngle - precessionRotation)

    // Sub-solar point (Meeus p. 372): the Sun as seen from the Moon.
    let sunDistanceKm = sunDistanceAU * Units.kmPerAU
    let ratio = moonDistanceKm / sunDistanceKm
    let lamH = sunLongitude + 180 + ratio * cos(moonLatitude * d2r) * sin((sunLongitude - moonLongitude) * d2r) * r2d
    let betH = ratio * moonLatitude
    let sun = libration(longitude: lamH, latitude: betH)
    subSolarLongitude = sun.l
    subSolarLatitude = sun.b
    colongitude = Self.wrapPositive(90 - sun.l)

    // Illuminated fraction and bright limb (Meeus chapter 48).
    let cosPsi = cos(moonLatitude * d2r) * cos((moonLongitude - sunLongitude) * d2r)
    let psi = acos(max(-1, min(1, cosPsi)))
    elongation = psi * r2d
    // Meeus: tan i = R sin ψ / (Δ − R cos ψ), R = Earth–Sun and Δ = Earth–Moon distance.
    let phase = atan2(sunDistanceKm * sin(psi), moonDistanceKm - sunDistanceKm * cos(psi))
    phaseAngle = Self.wrapSigned(phase * r2d)
    illuminatedFraction = (1 + cos(phase)) / 2

    let sunEquatorial = Self.equatorial(longitude: sunLongitude, latitude: 0, epsilon: eps)
    let dRA = sunEquatorial.ra - moonEquatorial.ra
    let chi = atan2(
      cos(sunEquatorial.dec) * sin(dRA),
      sin(sunEquatorial.dec) * cos(moonEquatorial.dec) - cos(sunEquatorial.dec) * sin(moonEquatorial.dec) * cos(dRA)
    )
    brightLimbPositionAngle = Self.wrapPositive(chi * r2d)
    distanceKm = moonDistanceKm
  }

  /// Creates the libration at a Julian date from Astral's lunar series and solar position.
  ///
  /// - Parameter time: The instant (UTC is treated as TT).
  public init(at time: JulianDate) {
    let T = time.centuriesSinceJ2000
    let jd2000 = time.days - JulianDate.j2000.days

    // Moon: right ascension/declination of date (no nutation) → ecliptic longitude/latitude of date.
    let position = moonPosition(jd2000: jd2000)
    let epsMean = obliquity_of_ecliptic(jd2000: jd2000)
    let alpha = position.right_ascension
    let delta = position.declination
    let lonRad = atan2(sin(alpha) * cos(epsMean) + tan(delta) * sin(epsMean), cos(alpha))
    let latRad = asin(sin(delta) * cos(epsMean) - cos(delta) * sin(epsMean) * sin(alpha))
    let dPsi = nutation(juliancentury: T).longitude / 3600
    let moonLongitude = Self.wrapPositive(lonRad / Units.degToRad + dPsi)

    self.init(
      at: time,
      moonLongitude: moonLongitude,
      moonLatitude: latRad / Units.degToRad,
      moonDistanceKm: position.distance * MoonEphemeris.earthEquatorialRadiusKm,
      sunLongitude: sun_apparent_long(juliancentury: T),
      sunDistanceAU: sun_rad_vector(juliancentury: T)
    )
  }

  /// Creates the libration at a date from Astral's lunar series and solar position.
  ///
  /// - Parameter date: The instant (UTC is treated as TT).
  public init(date: Date) {
    self.init(at: JulianDate(date))
  }

  // MARK: Public

  /// Total libration in longitude (optical + physical), degrees, positive to the east. Selenographic longitude of
  /// the sub-Earth point.
  public let longitude: Double
  /// Total libration in latitude (optical + physical), degrees, positive to the north. Selenographic latitude of
  /// the sub-Earth point.
  public let latitude: Double
  /// Optical (geometric) libration in longitude, degrees.
  public let opticalLongitude: Double
  /// Optical (geometric) libration in latitude, degrees.
  public let opticalLatitude: Double
  /// Physical libration in longitude (the Moon's real rocking), degrees; about ±0.04°.
  public let physicalLongitude: Double
  /// Physical libration in latitude, degrees; about ±0.04°.
  public let physicalLatitude: Double
  /// Position angle of the Moon's rotation axis (north pole) from celestial north of date, degrees, 0...360
  /// (values near 0 and 360 mean a small angle either side of north). Meeus's `P`.
  public let positionAngleOfAxis: Double
  /// ``positionAngleOfAxis`` referred to the J2000 celestial pole (the reference of NASA's tables), degrees,
  /// 0...360.
  ///
  /// Obtained by removing the first-order effect of precession on the direction of north,
  /// `θ · sin α / cos δ` with `θ = 2004.3″ × T` (Julian centuries `T` since J2000); the neglected second-order
  /// terms stay below about 0.003° within a century of J2000.
  public let positionAngleOfAxisJ2000: Double
  /// Position angle of the midpoint of the bright limb from celestial north through east, degrees, 0...360.
  /// Add 90° or subtract it (modulo 360) to get the direction of the cusps.
  public let brightLimbPositionAngle: Double
  /// Fraction of the disc that is sunlit as seen from the Earth's centre, 0...1.
  public let illuminatedFraction: Double
  /// Phase angle (Sun–Moon–Earth angle at the Moon), degrees.
  public let phaseAngle: Double
  /// Geocentric angular distance of the Moon from the Sun (elongation), degrees, 0...180.
  public let elongation: Double
  /// Selenographic longitude of the sub-solar point (the Sun's position as seen from the Moon), degrees, positive
  /// to the east.
  public let subSolarLongitude: Double
  /// Selenographic latitude of the sub-solar point, degrees.
  public let subSolarLatitude: Double
  /// Selenographic colongitude of the Sun, `90° − subSolarLongitude` normalised to 0...360. It is 0° when the
  /// sunrise terminator lies on the prime meridian (about first quarter), around 90° at full moon, 180° at last
  /// quarter and 270° at new moon.
  public let colongitude: Double
  /// Distance from the Earth's centre to the Moon's centre, km.
  public let distanceKm: Double

  // MARK: Private

  /// Physical-libration quantities ρ, σ, τ in degrees (Meeus p. 373). All angles in degrees.
  private static func physicalLibrationTerms(
    T: Double,
    M: Double,
    Mp: Double,
    F: Double,
    D: Double,
    Om: Double
  ) -> (rho: Double, sigma: Double, tau: Double) {
    let d = Units.degToRad
    let K1 = (119.75 + 131.849 * T) * d
    let K2 = (72.56 + 20.186 * T) * d
    let E = 1 - 0.002516 * T - 0.0000074 * T * T
    let m = M * d
    let mp = Mp * d
    let f = F * d
    let dd = D * d
    let om = Om * d

    let rho = -0.02752 * cos(mp)
      - 0.02245 * sin(f)
      + 0.00684 * cos(mp - 2 * f)
      - 0.00293 * cos(2 * f)
      - 0.00085 * cos(2 * f - 2 * dd)
      - 0.00054 * cos(mp - 2 * dd)
      - 0.00020 * sin(mp + f)
      - 0.00020 * cos(mp + 2 * f)
      - 0.00020 * cos(mp - f)
      + 0.00014 * cos(mp + 2 * f - 2 * dd)

    let sigma = -0.02816 * sin(mp)
      + 0.02244 * cos(f)
      - 0.00682 * sin(mp - 2 * f)
      - 0.00279 * sin(2 * f)
      - 0.00083 * sin(2 * f - 2 * dd)
      + 0.00069 * sin(mp - 2 * dd)
      + 0.00040 * cos(mp + f)
      - 0.00025 * sin(2 * mp)
      - 0.00023 * sin(mp + 2 * f)
      + 0.00020 * cos(mp - f)
      + 0.00019 * sin(mp - f)
      + 0.00013 * sin(mp + 2 * f - 2 * dd)
      - 0.00010 * cos(mp - 3 * f)

    let tau = 0.02520 * E * sin(m)
      + 0.00473 * sin(2 * mp - 2 * f)
      - 0.00467 * sin(mp)
      + 0.00396 * sin(K1)
      + 0.00276 * sin(2 * mp - 2 * dd)
      + 0.00196 * sin(om)
      - 0.00183 * cos(mp - f)
      + 0.00115 * sin(mp - 2 * dd)
      - 0.00096 * sin(mp - dd)
      + 0.00046 * sin(2 * f - 2 * dd)
      - 0.00039 * sin(mp - f)
      - 0.00032 * sin(mp - m - dd)
      + 0.00027 * sin(2 * mp - m - 2 * dd)
      + 0.00023 * sin(K2)
      - 0.00014 * sin(2 * dd)
      + 0.00014 * cos(2 * mp - 2 * f)
      - 0.00012 * sin(mp - 2 * f)
      - 0.00012 * sin(2 * mp)
      + 0.00011 * sin(2 * mp - 2 * m - 2 * dd)

    return (rho, sigma, tau)
  }

  /// Ecliptic (degrees) to equatorial (radians) for a given obliquity (radians).
  private static func equatorial(longitude: Double, latitude: Double, epsilon: Double) -> (ra: Double, dec: Double) {
    let lam = longitude * Units.degToRad
    let bet = latitude * Units.degToRad
    let ra = atan2(sin(lam) * cos(epsilon) - tan(bet) * sin(epsilon), cos(lam))
    let dec = asin(sin(bet) * cos(epsilon) + cos(bet) * sin(epsilon) * sin(lam))
    return (ra, dec)
  }

  /// Wraps degrees to (-180, 180].
  private static func wrapSigned(_ degrees: Double) -> Double {
    var x = degrees.truncatingRemainder(dividingBy: 360)
    if x > 180 { x -= 360 }
    if x <= -180 { x += 360 }
    return x
  }

  /// Wraps degrees to [0, 360).
  private static func wrapPositive(_ degrees: Double) -> Double {
    var x = degrees.truncatingRemainder(dividingBy: 360)
    if x < 0 { x += 360 }
    return x
  }
}
