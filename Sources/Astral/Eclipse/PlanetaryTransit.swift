//
//  PlanetaryTransit.swift
//

import Foundation
import simd

// MARK: - TransitPlanet

/// An inferior planet that can cross the Sun's disk as seen from Earth.
public enum TransitPlanet: String, Sendable, Hashable, CaseIterable {
  case mercury
  case venus

  var bodyID: BodyID { self == .mercury ? .mercury : .venus }
}

// MARK: - PlanetaryTransit

/// A transit of Mercury or Venus across the Sun, seen from the centre of the Earth.
///
/// Contacts follow NASA GSFC's definitions: I external tangency (ingress begins), II internal tangency (the whole disk
/// is on the Sun), III internal tangency at egress, IV external tangency (egress ends), and greatest transit, the
/// instant of least angular separation of the centres. Times are geocentric.
///
/// The geometry comes from Astral's planetary ephemeris (heliocentric Earth and planet positions, with light-time
/// correction for the planet and the Sun) and the Sun's semi-diameter 959.63″ at 1 AU. The default closed-form model
/// is the JPL "Approximate Positions of the Planets" Keplerian fit, nominally good to about 15–20″ for Mercury, Venus
/// and the Earth. A transit chord is crossed at 5″ per minute, so **expect contact times to be off by several minutes**
/// (measured against NASA in `PlanetaryTransitTests`). Pass an SPK kernel (DE440) for contact times accurate to seconds.
///
/// ```swift
/// let transit = PlanetaryTransit.next(of: .mercury, after: Date())
/// print(transit?.greatest.date, transit?.minimumSeparationArcseconds)
/// ```
public struct PlanetaryTransit: Sendable, Hashable {

  // MARK: Public

  public let planet: TransitPlanet
  /// Contact I: the planet's disk touches the Sun's limb from outside.
  public let contact1: LunarEclipseContact
  /// Contact II: the planet's disk is entirely inside the Sun's limb.
  public let contact2: LunarEclipseContact
  /// Greatest transit: the centres are closest.
  public let greatest: LunarEclipseContact
  /// Contact III: the planet's disk touches the Sun's limb from inside at egress.
  public let contact3: LunarEclipseContact
  /// Contact IV: the planet's disk leaves the Sun's limb.
  public let contact4: LunarEclipseContact
  /// Least angular separation of the centres of the planet and the Sun, arcseconds.
  public let minimumSeparationArcseconds: Double
  /// The Sun's apparent semi-diameter at greatest transit, arcseconds.
  public let sunSemiDiameterArcseconds: Double
  /// The planet's apparent semi-diameter at greatest transit, arcseconds.
  public let planetSemiDiameterArcseconds: Double

  /// Duration from contact I to contact IV in seconds.
  public var duration: TimeInterval { contact4.date.timeIntervalSince(contact1.date) }

  /// The Sun's semi-diameter at 1 AU in arcseconds (the IAU 1976 value 959.63″ used by NASA).
  public static let sunSemiDiameterAt1AU = 959.63

  /// The transits of `planet` whose greatest transit lies in `range`, using the closed-form planetary model.
  public static func transits(of planet: TransitPlanet, in range: ClosedRange<Date>) -> [PlanetaryTransit] {
    search(planet: planet, from: JulianDate(range.lowerBound).terrestrialTime.days,
           to: JulianDate(range.upperBound).terrestrialTime.days, limit: .max, positions: closedForm(planet))
  }

  /// The next transit of `planet` after `date`, searching up to `years` years ahead (Mercury transits are 3 to 13
  /// years apart, Venus transits up to 121 years apart, so use `years: 130` for Venus).
  public static func next(of planet: TransitPlanet, after date: Date, years: Double = 14) -> PlanetaryTransit? {
    let start = JulianDate(date).terrestrialTime.days
    return search(planet: planet, from: start, to: start + years * 365.25, limit: 1, positions: closedForm(planet)).first
  }

  /// The transits of `planet` in `range`, with positions from a JPL SPK kernel (which must cover the range for the
  /// Sun, Earth/Earth–Moon barycentre and the planet).
  public static func transits(
    of planet: TransitPlanet,
    in range: ClosedRange<Date>,
    kernel: SPKFile) throws -> [PlanetaryTransit]
  {
    let box = ErrorBox()
    let positions: (Double) -> (earth: SIMD3<Double>, planet: SIMD3<Double>) = { jd in
      do {
        let earth = try kernel.heliocentricEclipticPosition(of: .earth, at: JulianDate(days: jd))
        let p = try kernel.heliocentricEclipticPosition(of: planet.bodyID, at: JulianDate(days: jd))
        return (earth, p)
      } catch {
        box.set(error)
        return (SIMD3(1, 0, 0), SIMD3(-1, 0, 0))
      }
    }
    let result = search(
      planet: planet, from: JulianDate(range.lowerBound).terrestrialTime.days,
      to: JulianDate(range.upperBound).terrestrialTime.days, limit: .max, positions: positions)
    if let error = box.error { throw error }
    return result
  }

  // MARK: Private

  private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Error?
    var error: Error? { lock.lock(); defer { lock.unlock() }; return stored }
    func set(_ error: Error) { lock.lock(); stored = stored ?? error; lock.unlock() }
  }

  private static let lightDaysPerAU = 149_597_870.7 / 299_792.458 / 86_400

  /// Heliocentric J2000 ecliptic positions of the Earth's centre (with the accurate lunar series for the barycentre
  /// correction) and of the planet, AU.
  private static func closedForm(_ planet: TransitPlanet) -> (Double) -> (earth: SIMD3<Double>, planet: SIMD3<Double>) {
    let elements = (planet == .mercury ? Catalog.mercury : Catalog.venus).elements!
    return { jd in
      let T = (jd - 2_451_545.0) / 36_525
      let earth = SolarSystem.earthAndMoonPositions(T: T, model: .series).earth
      return (earth, Kepler.position(elements: elements, T: T))
    }
  }

  /// Angular quantities at one TT instant (days).
  private struct Geometry {
    var separation: Double // arcsec
    var sunSD: Double
    var planetSD: Double
    var planetIsNearer: Bool
  }

  private static func geometry(
    at jd: Double,
    planet: TransitPlanet,
    positions: (Double) -> (earth: SIMD3<Double>, planet: SIMD3<Double>)) -> Geometry
  {
    let (earth, p0) = positions(jd)
    let sunDistance = simd_length(earth)
    // Planet position at the time its light left it.
    var pos = p0
    var tau = simd_length(p0 - earth) * lightDaysPerAU
    for _ in 0..<3 {
      pos = positions(jd - tau).planet
      tau = simd_length(pos - earth) * lightDaysPerAU
    }
    let toSun = -earth
    let toPlanet = pos - earth
    let cosAngle = simd_dot(simd_normalize(toSun), simd_normalize(toPlanet))
    let cross = simd_length(simd_cross(simd_normalize(toSun), simd_normalize(toPlanet)))
    let angle = atan2(cross, cosAngle)
    let radius = (planet == .mercury ? Catalog.mercury : Catalog.venus).radiusKm
    let planetDistance = simd_length(toPlanet)
    return Geometry(
      separation: angle * 180 / .pi * 3600,
      sunSD: sunSemiDiameterAt1AU / sunDistance,
      planetSD: atan(radius / (planetDistance * Units.kmPerAU)) * 180 / .pi * 3600,
      planetIsNearer: planetDistance < sunDistance)
  }

  fileprivate static func search(
    planet: TransitPlanet,
    from start: Double,
    to end: Double,
    limit: Int,
    positions: (Double) -> (earth: SIMD3<Double>, planet: SIMD3<Double>)) -> [PlanetaryTransit]
  {
    var result: [PlanetaryTransit] = []
    let step = 0.5
    var t = start - step
    var s0 = geometry(at: t, planet: planet, positions: positions)
    t += step
    var s1 = geometry(at: t, planet: planet, positions: positions)
    while t < end + step, result.count < limit {
      let t2 = t + step
      let s2 = geometry(at: t2, planet: planet, positions: positions)
      if s1.separation <= s0.separation, s1.separation < s2.separation, s1.separation < 7200, s1.planetIsNearer {
        if let transit = refine(planet: planet, around: t, positions: positions),
           transit.greatest.terrestrialTime.days >= start, transit.greatest.terrestrialTime.days <= end
        {
          result.append(transit)
        }
      }
      s0 = s1
      s1 = s2
      t = t2
    }
    return result
  }

  private static func refine(
    planet: TransitPlanet,
    around centre: Double,
    positions: (Double) -> (earth: SIMD3<Double>, planet: SIMD3<Double>)) -> PlanetaryTransit?
  {
    func sep(_ t: Double) -> Double { geometry(at: t, planet: planet, positions: positions).separation }
    var lo = centre - 0.5, hi = centre + 0.5
    let phi = (sqrt(5.0) - 1) / 2
    var c = hi - phi * (hi - lo), d = lo + phi * (hi - lo)
    var fc = sep(c), fd = sep(d)
    for _ in 0..<80 {
      if fc < fd { hi = d; d = c; fd = fc; c = hi - phi * (hi - lo); fc = sep(c) }
      else { lo = c; c = d; fc = fd; d = lo + phi * (hi - lo); fd = sep(d) }
      if hi - lo < 1e-9 { break }
    }
    let tg = (lo + hi) / 2
    let g = geometry(at: tg, planet: planet, positions: positions)
    guard g.separation < g.sunSD + g.planetSD else { return nil }

    func root(_ radius: (Geometry) -> Double, sign: Double) -> Double {
      func f(_ t: Double) -> Double {
        let s = geometry(at: t, planet: planet, positions: positions)
        return s.separation - radius(s)
      }
      var inside = tg
      var outside = tg + sign * 0.6
      for _ in 0..<80 {
        let m = (inside + outside) / 2
        if f(m) < 0 { inside = m } else { outside = m }
        if abs(outside - inside) < 1e-9 { break }
      }
      return (inside + outside) / 2
    }
    func make(_ t: Double) -> LunarEclipseContact {
      let tt = JulianDate(days: t)
      return LunarEclipseContact(date: tt.utcFromTerrestrialTime.date, terrestrialTime: tt)
    }
    // Contacts II and III only exist for a full transit (the planet's whole disk inside the Sun).
    let full = g.separation < g.sunSD - g.planetSD
    let outer: (Geometry) -> Double = { $0.sunSD + $0.planetSD }
    let inner: (Geometry) -> Double = { $0.sunSD - $0.planetSD }
    guard full else { return nil } // grazing transits are not reported
    return PlanetaryTransit(
      planet: planet,
      contact1: make(root(outer, sign: -1)),
      contact2: make(root(inner, sign: -1)),
      greatest: make(tg),
      contact3: make(root(inner, sign: 1)),
      contact4: make(root(outer, sign: 1)),
      minimumSeparationArcseconds: g.separation,
      sunSemiDiameterArcseconds: g.sunSD,
      planetSemiDiameterArcseconds: g.planetSD)
  }
}
