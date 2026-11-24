//
//  PlanetRiseSet.swift
//
//  Rise, transit and set times, and topocentric azimuth / elevation, of the planets Mercury–Neptune (and the
//  unverified Pluto) for an ``Observer``.
//
//  The planet's heliocentric J2000 ecliptic position comes from the orbital elements of ``Catalog`` (the same
//  ones ``SolarSystem`` uses); everything else is done here:
//
//  1. Earth → planet vector, corrected for light-time (3 iterations, planet evaluated at t − τ).
//  2. Annual aberration (first order, Earth's velocity by central difference of the Earth–Moon barycentre orbit).
//  3. Ecliptic J2000 → equatorial J2000 (obliquity 23°26'21.448").
//  4. Precession J2000 → date (Meeus chapter 21, rigorous rotation).
//  5. Nutation (Astral's `nutation(juliancentury:)`, Meeus Table 22.A, 20 terms) and apparent sidereal time.
//  6. Diurnal parallax (Meeus chapter 40) for the observer's latitude and height. Only noticeable for Venus and
//     Mars when they are close to Earth (up to ~0.01°).
//  7. Horizontal coordinates; optional refraction with the same `refractionAtZenith(_:)` the Sun uses.
//
//  Not modelled: gravitational light deflection by the Sun (< 0.01″ away from the Sun), ΔT (UTC is used as TT, as in
//  the rest of the ephemeris API; ≤ 0.003° for any planet) and polar motion / UT1−UTC (< 1 s).
//
//  Rise and set use a standard altitude of −34′ (refraction at the horizon; planets are point sources) plus the
//  dip of the observer's elevation, exactly as `sunrise` does.
//

import Foundation
import simd

// MARK: - PlanetError

/// Errors from the planet rise / transit / set calculations.
public enum PlanetError: Error, Sendable, Hashable {
  /// The body is not a planet (the Sun, Earth and the Moon have their own functions).
  case unsupportedBody(BodyID)
  /// The planet stays above the horizon for the whole day (circumpolar): it neither rises nor sets.
  case alwaysAboveHorizon(BodyID)
  /// The planet stays below the horizon for the whole day: it never rises.
  case alwaysBelowHorizon(BodyID)
  /// The planet crosses the horizon (or the meridian) but not on the requested date.
  case noEventOnDate(BodyID, String)
}

// MARK: - PlanetPosition

/// The apparent geocentric place of a planet: true equator and equinox of date.
public struct PlanetPosition: Sendable, Hashable {
  /// Right ascension in degrees, `[0, 360)`.
  public let rightAscension: Degrees
  /// Declination in degrees.
  public let declination: Degrees
  /// Geocentric distance in AU (geometric, at the light-time corrected epoch).
  public let distance: Double
}

// MARK: - Constants

/// Geometric altitude of a planet's centre at rise and set for an observer at sea level: 34′ of refraction.
let planetStandardAltitude = -34.0 / 60.0

private let lightTimeDaysPerAU = 0.0057755183
private let speedOfLightAUPerDay = 173.1446327

// MARK: - Public API

/// Calculates the time (in `tzinfo`) when a planet rises on the given local date.
///
/// `date` is a calendar date in `tzinfo` (only its year, month and day are used); the result is the first rise
/// between local midnight and the next local midnight. Accuracy is about a minute (see the fixture tests against
/// JPL Horizons).
/// - Parameters:
///   - body: The planet (Mercury–Neptune, or the unverified Pluto).
///   - observer: The observer's location; its elevation lowers the horizon like in `sunrise`.
///   - date: The local date as DateComponents.
///   - tzinfo: The time zone of `date` and of the result (default UTC).
/// - Returns: The rise time as DateComponents in `tzinfo`.
/// - Throws: ``PlanetError`` if the planet does not rise on that date.
public func planetRise(
  _ body: BodyID,
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  try planetEvent(.rise, body, observer: observer, date: date, tzinfo: tzinfo)
}

/// Calculates the time (in `tzinfo`) when a planet sets on the given local date.
/// See ``planetRise(_:observer:date:tzinfo:)``.
/// - Throws: ``PlanetError`` if the planet does not set on that date.
public func planetSet(
  _ body: BodyID,
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  try planetEvent(.set, body, observer: observer, date: date, tzinfo: tzinfo)
}

/// Calculates the time (in `tzinfo`) of the planet's upper transit (meridian crossing) on the given local date.
///
/// The transit exists whether or not the planet is above the horizon.
/// - Throws: ``PlanetError/noEventOnDate(_:_:)`` on the rare local day that has no upper transit.
public func planetTransit(
  _ body: BodyID,
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  try planetEvent(.transit, body, observer: observer, date: date, tzinfo: tzinfo)
}

/// `Date` flavour of ``planetRise(_:observer:date:tzinfo:)``: the local day is the one of `date` in `tzinfo`.
public func planetRise(_ body: BodyID, observer: Observer, date: Date, tzinfo: TimeZone = .utc) throws -> DateComponents {
  try planetRise(body, observer: observer, date: date.components(timezone: tzinfo), tzinfo: tzinfo)
}

/// `Date` flavour of ``planetSet(_:observer:date:tzinfo:)``.
public func planetSet(_ body: BodyID, observer: Observer, date: Date, tzinfo: TimeZone = .utc) throws -> DateComponents {
  try planetSet(body, observer: observer, date: date.components(timezone: tzinfo), tzinfo: tzinfo)
}

/// `Date` flavour of ``planetTransit(_:observer:date:tzinfo:)``.
public func planetTransit(_ body: BodyID, observer: Observer, date: Date, tzinfo: TimeZone = .utc) throws -> DateComponents {
  try planetTransit(body, observer: observer, date: date.components(timezone: tzinfo), tzinfo: tzinfo)
}

/// Returns the planet's zenith angle (in degrees) for the given observer and time.
///
/// `dateandtime` without a time zone is taken as UTC, like in the Sun functions.
/// - Throws: ``PlanetError/unsupportedBody(_:)``.
public func planetZenith(
  _ body: BodyID,
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true
) throws -> Double {
  try planetZenith(body, observer: observer, dateandtime: planetInstant(dateandtime), with_refraction: with_refraction)
}

/// Returns the planet's azimuth (in degrees, clockwise from north) for the given observer and time.
public func planetAzimuth(
  _ body: BodyID,
  observer: Observer,
  dateandtime: DateComponents = Date().components()
) throws -> Double {
  try planetAzimuth(body, observer: observer, dateandtime: planetInstant(dateandtime))
}

/// Returns the planet's elevation (in degrees) for the given observer and time.
public func planetElevation(
  _ body: BodyID,
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true
) throws -> Double {
  try planetElevation(body, observer: observer, dateandtime: planetInstant(dateandtime), with_refraction: with_refraction)
}

/// `Date` flavour of ``planetZenith(_:observer:dateandtime:with_refraction:)``.
public func planetZenith(_ body: BodyID, observer: Observer, dateandtime: Date, with_refraction: Bool = true) throws -> Double {
  90.0 - (try planetElevation(body, observer: observer, dateandtime: dateandtime, with_refraction: with_refraction))
}

/// `Date` flavour of ``planetAzimuth(_:observer:dateandtime:)``.
public func planetAzimuth(_ body: BodyID, observer: Observer, dateandtime: Date) throws -> Double {
  let element = try planetBody(body)
  return observePlanet(element, observer: observer, jd: JulianDate(dateandtime).days).azimuth
}

/// `Date` flavour of ``planetElevation(_:observer:dateandtime:with_refraction:)``.
public func planetElevation(
  _ body: BodyID,
  observer: Observer,
  dateandtime: Date,
  with_refraction: Bool = true
) throws -> Double {
  let element = try planetBody(body)
  let geometric = observePlanet(element, observer: observer, jd: JulianDate(dateandtime).days).altitude
  return with_refraction ? geometric + refractionAtZenith(90.0 - geometric) : geometric
}

/// The apparent geocentric right ascension, declination and distance of a planet.
///
/// - Throws: ``PlanetError/unsupportedBody(_:)``.
public func planetPosition(_ body: BodyID, dateandtime: DateComponents = Date().components()) throws -> PlanetPosition {
  try planetPosition(body, dateandtime: planetInstant(dateandtime))
}

/// `Date` flavour of ``planetPosition(_:dateandtime:)``.
public func planetPosition(_ body: BodyID, dateandtime: Date) throws -> PlanetPosition {
  let element = try planetBody(body)
  let place = apparentGeocentric(element, jd: JulianDate(dateandtime).days)
  var ra = degrees(place.rightAscension)
  if ra < 0 { ra += 360 }
  return PlanetPosition(rightAscension: ra, declination: degrees(place.declination), distance: place.distance)
}

// MARK: - ApparentPlace

private struct ApparentPlace {
  var rightAscension: Radians
  var declination: Radians
  var distance: Double
  /// Apparent sidereal time at Greenwich, degrees.
  var gast: Degrees
}

/// The catalog body of a planet.
@discardableResult
private func planetBody(_ id: BodyID) throws -> Body {
  switch id {
  case .mercury: return Catalog.mercury
  case .venus: return Catalog.venus
  case .mars: return Catalog.mars
  case .jupiter: return Catalog.jupiter
  case .saturn: return Catalog.saturn
  case .uranus: return Catalog.uranus
  case .neptune: return Catalog.neptune
  case .pluto: return Catalog.pluto
  case .sun, .earth, .moon, .ceres, .eris, .haumea, .makemake: throw PlanetError.unsupportedBody(id)
  }
}

/// Greenwich mean sidereal time (degrees, `[0, 360)`) for a UT Julian day; same series as `gmst(dateComponents:)`.
func gmstDegrees(jd: Double) -> Degrees {
  let d = jd - julianDayEpoch
  let T = d / julianEC
  let value = 280.46061837 + 360.98564736629 * d + 0.000387933 * T * T + T * T * T / 38_710_000.0
  var r = value.truncatingRemainder(dividingBy: 360.0)
  if r < 0 { r += 360 }
  return r
}

private func rotateX(_ v: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
  let c = cos(angle)
  let s = sin(angle)
  return SIMD3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
}

private func rotateZ(_ v: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
  let c = cos(angle)
  let s = sin(angle)
  return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
}

private func apparentGeocentric(_ body: Body, jd: Double) -> ApparentPlace {
  let T = (jd - julianDayEpoch) / julianEC
  // Catalog planets always carry elements.
  let elements = body.elements!
  let earth = SolarSystem.earthAndMoonPositions(T: T, model: .periodicTerms).earth

  // Light-time: evaluate the planet where it was τ days ago.
  var geocentric = Kepler.position(elements: elements, T: T) - earth
  for _ in 0..<3 {
    let tau = simd_length(geocentric) * lightTimeDaysPerAU
    geocentric = Kepler.position(elements: elements, T: T - tau / julianEC) - earth
  }
  let distance = simd_length(geocentric)

  // Annual aberration, first order, in the ecliptic J2000 frame. The two samples are one day apart.
  let earthElements = Catalog.earth.elements!
  let h = 0.5 / julianEC
  let velocity = Kepler.position(elements: earthElements, T: T + h) - Kepler.position(elements: earthElements, T: T - h)
  let u = geocentric / distance
  let apparent = simd_normalize(u + (velocity - simd_dot(u, velocity) * u) / speedOfLightAUPerDay)

  // Ecliptic J2000 -> equatorial J2000.
  let equatorialJ2000 = rotateX(apparent, radians(mean_obliquity_of_ecliptic(juliancentury: 0)))

  // Precession J2000 -> mean equator of date (Meeus 21.2).
  let arcsec = Double.pi / 180 / 3600
  let zeta = (2306.2181 * T + 0.30188 * T * T + 0.017998 * T * T * T) * arcsec
  let z = (2306.2181 * T + 1.09468 * T * T + 0.018203 * T * T * T) * arcsec
  let theta = (2004.3109 * T - 0.42665 * T * T - 0.041833 * T * T * T) * arcsec
  let cz = cos(zeta)
  let sz = sin(zeta)
  let cZ = cos(z)
  let sZ = sin(z)
  let ct = cos(theta)
  let st = sin(theta)
  let p = equatorialJ2000
  let mean = SIMD3(
    (cz * ct * cZ - sz * sZ) * p.x + (-sz * ct * cZ - cz * sZ) * p.y + (-st * cZ) * p.z,
    (cz * ct * sZ + sz * cZ) * p.x + (-sz * ct * sZ + cz * cZ) * p.y + (-st * sZ) * p.z,
    (cz * st) * p.x + (-sz * st) * p.y + ct * p.z
  )

  // Nutation: mean equator -> ecliptic of date, longitude += Δψ, back to the true equator (ε + Δε).
  let nut = nutation(juliancentury: T)
  let meanObliquity = radians(mean_obliquity_of_ecliptic(juliancentury: T))
  let dpsi = nut.longitude * arcsec
  let trueObliquity = meanObliquity + nut.obliquity * arcsec
  let ecliptic = rotateZ(rotateX(mean, -meanObliquity), dpsi)
  let trueEquatorial = rotateX(ecliptic, trueObliquity)

  let gast = (gmstDegrees(jd: jd) + degrees(dpsi * cos(trueObliquity))).truncatingRemainder(dividingBy: 360)
  return ApparentPlace(
    rightAscension: atan2(trueEquatorial.y, trueEquatorial.x),
    declination: asin(max(-1, min(1, trueEquatorial.z))),
    distance: distance,
    gast: gast
  )
}

// MARK: - Observation

private struct Observation {
  /// Geometric (airless) altitude in degrees, parallax included.
  var altitude: Degrees
  /// Azimuth in degrees, clockwise from north, `[0, 360)`.
  var azimuth: Degrees
  /// Topocentric local hour angle in degrees, `(-180, 180]`.
  var hourAngle: Degrees
}

private func observePlanet(_ body: Body, observer: Observer, jd: Double) -> Observation {
  let place = apparentGeocentric(body, jd: jd)

  let phi = radians(observer.latitude)
  let height: Double =
    switch observer.elevation {
    case .double(let metres): max(metres, 0)
    case .tuple: 0
    }

  // Diurnal parallax (Meeus chapter 40).
  let hourAngle = radians(place.gast + observer.longitude) - place.rightAscension
  let u = atan(0.99664719 * tan(phi))
  let rhoSin = 0.99664719 * sin(u) + height / 6_378_140.0 * sin(phi)
  let rhoCos = cos(u) + height / 6_378_140.0 * cos(phi)
  let sinParallax = sin(radians(8.794 / 3600.0)) / place.distance
  let dec = place.declination
  let deltaRA = atan2(-rhoCos * sinParallax * sin(hourAngle), cos(dec) - rhoCos * sinParallax * cos(hourAngle))
  let topoDec = atan2(
    (sin(dec) - rhoSin * sinParallax) * cos(deltaRA),
    cos(dec) - rhoCos * sinParallax * cos(hourAngle)
  )
  let topoHour = hourAngle - deltaRA

  let sh = sin(topoHour)
  let ch = cos(topoHour)
  let sd = sin(topoDec)
  let cd = cos(topoDec)
  let sl = sin(phi)
  let cl = cos(phi)
  let x = -ch * cd * sl + sd * cl
  let y = -sh * cd
  let z = ch * cd * cl + sd * sl
  var azimuth = degrees(atan2(y, x)).truncatingRemainder(dividingBy: 360)
  if azimuth < 0 { azimuth += 360 }
  return Observation(
    altitude: degrees(atan2(z, (x * x + y * y).squareRoot())),
    azimuth: azimuth,
    hourAngle: degrees(Kepler.wrapPi(topoHour))
  )
}

// MARK: - PlanetEventKind

private enum PlanetEventKind {
  case rise
  case set
  case transit

  var name: String {
    switch self {
    case .rise: "rise"
    case .set: "set"
    case .transit: "transit"
    }
  }
}

/// Converts `DateComponents` to an instant; no time zone means UTC (as in the Sun functions).
private func planetInstant(_ components: DateComponents) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = components.timeZone ?? .utc
  return calendar.date(from: components) ?? Date()
}

/// The dip of the horizon for the observer's elevation, as `time_of_transit` computes it.
private func horizonAdjustment(for observer: Observer) -> Degrees {
  switch observer.elevation {
  case .double(let elevation) where elevation > 0:
    adjust_to_horizon(elevation: elevation)
  case .tuple(let elevation, let distance):
    adjust_to_obscuring_feature(elevation: (elevation, distance))
  default:
    0
  }
}

private func bisect(_ a: Double, _ b: Double, _ f: (Double) -> Double) -> Double {
  var lo = a
  var hi = b
  let negativeAtLo = f(lo) < 0
  for _ in 0..<50 {
    let mid = (lo + hi) / 2
    if (f(mid) < 0) == negativeAtLo { lo = mid } else { hi = mid }
    if hi - lo < 1e-9 { break } // 0.09 ms
  }
  return (lo + hi) / 2
}

private func planetEvent(
  _ kind: PlanetEventKind,
  _ id: BodyID,
  observer: Observer,
  date: DateComponents,
  tzinfo: TimeZone
) throws -> DateComponents {
  let body = try planetBody(id)

  // The local calendar day in tzinfo.
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = tzinfo
  guard
    let year = date.year, let month = date.month, let day = date.day,
    let anyTime = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
    let nextDay = calendar.date(byAdding: .day, value: 1, to: anyTime)
  else {
    throw PlanetError.noEventOnDate(id, "Invalid date")
  }
  let start = JulianDate(calendar.startOfDay(for: anyTime)).days
  let end = JulianDate(calendar.startOfDay(for: nextDay)).days

  let standardAltitude = planetStandardAltitude - horizonAdjustment(for: observer)
  let altitude: (Double) -> Double = { observePlanet(body, observer: observer, jd: $0).altitude - standardAltitude }
  let hourAngle: (Double) -> Double = { observePlanet(body, observer: observer, jd: $0).hourAngle }

  // Sample every ≤ 5 minutes and refine the first sign change by bisection.
  let steps = max(1, Int(((end - start) * 288).rounded(.up)))
  let step = (end - start) / Double(steps)
  var previousJD = start
  var previousAlt = altitude(start)
  var previousHour = hourAngle(start)
  var anyAbove = previousAlt >= 0
  var anyBelow = previousAlt < 0
  var found: Double?

  for i in 1...steps {
    let jd = start + Double(i) * step
    let alt = altitude(jd)
    let hour = hourAngle(jd)
    anyAbove = anyAbove || alt >= 0
    anyBelow = anyBelow || alt < 0
    switch kind {
    case .rise where previousAlt < 0 && alt >= 0:
      found = bisect(previousJD, jd, altitude)
    case .set where previousAlt >= 0 && alt < 0:
      found = bisect(previousJD, jd, altitude)
    case .transit where previousHour < 0 && hour >= 0 && hour - previousHour < 90:
      found = bisect(previousJD, jd, hourAngle)
    default:
      break
    }
    if found != nil { break }
    previousJD = jd
    previousAlt = alt
    previousHour = hour
  }

  guard let jd = found else {
    if kind != .transit {
      if !anyBelow { throw PlanetError.alwaysAboveHorizon(id) }
      if !anyAbove { throw PlanetError.alwaysBelowHorizon(id) }
    }
    throw PlanetError.noEventOnDate(id, "\(id.displayName) has no \(kind.name) on this date")
  }
  return JulianDate(days: jd).date.components(timezone: tzinfo)
}
