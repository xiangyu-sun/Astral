//
//  LunarEclipse.swift
//

import Foundation
import simd

// MARK: - LunarEclipseType

/// The type of a lunar eclipse.
public enum LunarEclipseType: String, Sendable, Hashable, CaseIterable {
  /// The Moon only enters the Earth's penumbra.
  case penumbral
  /// Part of the Moon enters the umbra.
  case partial
  /// The whole Moon enters the umbra.
  case total
}

// MARK: - LunarEclipseContact

/// A contact of a lunar eclipse, geocentric.
public struct LunarEclipseContact: Sendable, Hashable {
  /// The instant in UTC (`TT − UTC` from ``LeapSeconds``, or ΔT before 1972).
  public let date: Date
  /// The instant in TT as a Julian date.
  public let terrestrialTime: JulianDate
}

// MARK: - LunarEclipse

/// A lunar eclipse predicted from the shadow geometry of Astral's Sun and Moon positions.
///
/// The Earth's shadow is built the way NASA GSFC does (F. Espenak, Danjon's rule): the Earth's radius is enlarged by
/// 1/85 to allow for the atmosphere and the umbra and penumbra are the cones tangent to the Sun and to this enlarged
/// Earth. The Moon's centre, from Astral's lunar series (``MoonModel/series``), is compared with the shadow axis
/// (the geometric anti-solar direction, from the planetary ephemeris). All times are geocentric.
///
/// - `p1`, `p4`: first and last contact with the penumbra,
/// - `u1`, `u4`: first and last contact with the umbra (partial and total eclipses),
/// - `u2`, `u3`: the beginning and end of totality (total eclipses),
/// - `greatest`: the instant the Moon is closest to the shadow axis.
///
/// ```swift
/// if let eclipse = LunarEclipse.next(after: Date()) {
///   print(eclipse.type, eclipse.greatest.date, eclipse.umbralMagnitude)
/// }
/// ```
///
/// ### Accuracy
/// Measured in `LunarEclipseTests` against NASA GSFC's 2025-2026 eclipses (VSOP87/ELP2000-85, ΔT = 75 s): contacts
/// agree within about 2 minutes (worst case 122 s, typically 50-100 s) and magnitudes within 0.016. Most of the
/// error comes from the closed-form Earth/Sun position (about 15″ nominal, 30 km at the Moon, about 30 s of
/// Moon motion); with JPL Horizons' Sun and Moon the same shadow model reproduces NASA's magnitudes to 0.004, so the
/// rest is the Danjon edge definition. The Earth's shadow edge is itself uncertain at that level.
public struct LunarEclipse: Sendable, Hashable {

  // MARK: Public

  /// The eclipse type.
  public let type: LunarEclipseType
  /// Greatest eclipse (the Moon's centre closest to the shadow axis).
  public let greatest: LunarEclipseContact
  /// Penumbral magnitude at greatest eclipse: the fraction of the Moon's diameter inside the penumbra's edge, as NASA
  /// defines it (above 1 once the Moon is inside the penumbra).
  public let penumbralMagnitude: Double
  /// Umbral magnitude at greatest eclipse: the fraction of the Moon's diameter immersed in the umbra
  /// (1 or more for a total eclipse, 0 to 1 for a partial eclipse, negative for a penumbral one).
  public let umbralMagnitude: Double
  /// Least distance of the Moon's centre from the shadow axis, in Earth equatorial radii (NASA's gamma, unsigned).
  public let gamma: Double
  /// P1: the Moon touches the penumbra.
  public let p1: LunarEclipseContact
  /// U1: the Moon touches the umbra (`nil` for a penumbral eclipse).
  public let u1: LunarEclipseContact?
  /// U2: the Moon is entirely in the umbra (`nil` unless total).
  public let u2: LunarEclipseContact?
  /// U3: the Moon begins to leave the umbra (`nil` unless total).
  public let u3: LunarEclipseContact?
  /// U4: the Moon leaves the umbra (`nil` for a penumbral eclipse).
  public let u4: LunarEclipseContact?
  /// P4: the Moon leaves the penumbra.
  public let p4: LunarEclipseContact

  /// Duration of the penumbral phase (P1 to P4) in seconds.
  public var penumbralDuration: TimeInterval { p4.date.timeIntervalSince(p1.date) }
  /// Duration of the umbral phase (U1 to U4) in seconds, `nil` for a penumbral eclipse.
  public var partialDuration: TimeInterval? {
    guard let u1, let u4 else { return nil }
    return u4.date.timeIntervalSince(u1.date)
  }

  /// Duration of totality (U2 to U3) in seconds, `nil` unless total.
  public var totalityDuration: TimeInterval? {
    guard let u2, let u3 else { return nil }
    return u3.date.timeIntervalSince(u2.date)
  }

  /// The lunar eclipse of the full Moon nearest to `date` (within about 15 days), or `nil` if the Moon misses the
  /// penumbra.
  ///
  /// - Parameters:
  ///   - date: Any instant near the full Moon (UTC).
  ///   - moonModel: How the Moon's position is computed; the default is the accurate lunar series.
  public static func eclipse(nearFullMoon date: Date, moonModel: MoonModel = .series) -> LunarEclipse? {
    let tt = JulianDate(date).terrestrialTime
    let geometry = ShadowGeometry(model: moonModel)
    // Find the opposition nearest to `tt`, by stepping to the next one and the previous one.
    let next = geometry.opposition(after: JulianDate(days: tt.days - 14.8))
    return geometry.eclipse(aroundOpposition: next)
  }

  /// The next lunar eclipse (including penumbral ones) after `date`, searching up to `years` years ahead.
  public static func next(after date: Date, years: Double = 2, moonModel: MoonModel = .series) -> LunarEclipse? {
    let geometry = ShadowGeometry(model: moonModel)
    let start = JulianDate(date).terrestrialTime
    var from = start
    let end = start.days + years * 365.25
    while from.days < end {
      let opposition = geometry.opposition(after: from)
      if let eclipse = geometry.eclipse(aroundOpposition: opposition), eclipse.greatest.terrestrialTime.days > start.days {
        return eclipse
      }
      from = JulianDate(days: opposition.days + 1)
    }
    return nil
  }

  /// All lunar eclipses (including penumbral ones) whose greatest eclipse lies in `range`.
  public static func eclipses(in range: ClosedRange<Date>, moonModel: MoonModel = .series) -> [LunarEclipse] {
    let geometry = ShadowGeometry(model: moonModel)
    var result: [LunarEclipse] = []
    let start = JulianDate(range.lowerBound).terrestrialTime
    let end = JulianDate(range.upperBound).terrestrialTime
    var from = JulianDate(days: start.days - 1)
    while from.days < end.days + 1 {
      let opposition = geometry.opposition(after: from)
      if let eclipse = geometry.eclipse(aroundOpposition: opposition),
         range.contains(eclipse.greatest.date)
      {
        result.append(eclipse)
      }
      from = JulianDate(days: opposition.days + 1)
    }
    return result
  }

  /// Shadow geometry constants (NASA conventions).
  public enum Constants {
    /// Earth's equatorial radius in km.
    public static let earthRadiusKm = 6378.14
    /// Danjon's enlargement of the Earth's radius for the atmosphere: 1/85.
    public static let danjonEnlargement = 1.0 / 85.0
    /// The Sun's radius in km (959.63″ at 1 AU).
    public static let sunRadiusKm = 695_990.0
    /// The Moon's radius as a fraction of the Earth's equatorial radius (0.2725076, IAU).
    public static let moonRadiusInEarthRadii = 0.2725076
  }
}

// MARK: - Shadow geometry

/// Earth shadow geometry at an instant.
struct ShadowState {
  /// Distance of the Moon's centre from the shadow axis, km.
  var separationKm: Double
  /// Radii of the umbra and penumbra at the Moon's distance along the axis, km.
  var umbraKm: Double
  var penumbraKm: Double
  /// Moon's radius, km.
  var moonKm: Double
}

struct ShadowGeometry {
  let model: MoonModel

  func state(atTT jd: Double) -> ShadowState {
    let T = (jd - 2_451_545.0) / 36_525
    let (earth, moon) = SolarSystem.earthAndMoonPositions(T: T, model: model)
    let sunDistance = simd_length(earth) * Units.kmPerAU
    let axis = simd_normalize(earth) // Sun -> Earth: the direction of the shadow
    let geo = (moon - earth) * Units.kmPerAU
    let along = simd_dot(geo, axis)
    let perpendicular = geo - along * axis
    let R = LunarEclipse.Constants.earthRadiusKm * (1 + LunarEclipse.Constants.danjonEnlargement)
    let Rs = LunarEclipse.Constants.sunRadiusKm
    let sinU = (Rs - R) / sunDistance
    let sinP = (Rs + R) / sunDistance
    let tanU = sinU / sqrt(1 - sinU * sinU)
    let tanP = sinP / sqrt(1 - sinP * sinP)
    return ShadowState(
      separationKm: simd_length(perpendicular),
      umbraKm: R - along * tanU,
      penumbraKm: R + along * tanP,
      moonKm: LunarEclipse.Constants.moonRadiusInEarthRadii * LunarEclipse.Constants.earthRadiusKm)
  }

  /// Moon − Sun ecliptic longitude minus 180°, in (-π, π].
  func oppositionOffset(atTT jd: Double) -> Double {
    let T = (jd - 2_451_545.0) / 36_525
    let (earth, moon) = SolarSystem.earthAndMoonPositions(T: T, model: model)
    let sunLongitude = atan2(-earth.y, -earth.x)
    let moonLongitude = atan2((moon - earth).y, (moon - earth).x)
    var d = moonLongitude - sunLongitude - .pi
    d = atan2(sin(d), cos(d))
    return d
  }

  /// The first instant at or after `jd` when the Moon is opposite the Sun in ecliptic longitude.
  func opposition(after start: JulianDate) -> JulianDate {
    // The offset increases by about 12.2° per day; find a sign change from negative to positive.
    var t = start.days
    var previous = oppositionOffset(atTT: t)
    let step = 0.25
    while true {
      let next = t + step
      let value = oppositionOffset(atTT: next)
      if previous < 0, value >= 0, abs(value - previous) < 1 {
        // Bisect/secant.
        var a = t, b = next, fa = previous, fb = value
        for _ in 0..<60 {
          let m = b - (b - a) * fb / (fb - fa)
          let fm = oppositionOffset(atTT: m)
          if fm < 0 { a = m; fa = fm } else { b = m; fb = fm }
          if abs(b - a) < 1e-9 { break }
        }
        return JulianDate(days: (a + b) / 2)
      }
      t = next
      previous = value
    }
  }

  /// Builds the eclipse around an opposition, or `nil` when the Moon misses the penumbra.
  func eclipse(aroundOpposition opposition: JulianDate) -> LunarEclipse? {
    // Greatest eclipse: minimise the separation within a few hours of opposition (golden section).
    func separation(_ t: Double) -> Double { state(atTT: t).separationKm }
    var lo = opposition.days - 0.25, hi = opposition.days + 0.25
    let phi = (sqrt(5.0) - 1) / 2
    var c = hi - phi * (hi - lo), d = lo + phi * (hi - lo)
    var fc = separation(c), fd = separation(d)
    for _ in 0..<80 {
      if fc < fd { hi = d; d = c; fd = fc; c = hi - phi * (hi - lo); fc = separation(c) }
      else { lo = c; c = d; fc = fd; d = lo + phi * (hi - lo); fd = separation(d) }
      if hi - lo < 1e-9 { break }
    }
    let tg = (lo + hi) / 2
    let g = state(atTT: tg)
    let penumbralMagnitude = (g.penumbraKm + g.moonKm - g.separationKm) / (2 * g.moonKm)
    let umbralMagnitude = (g.umbraKm + g.moonKm - g.separationKm) / (2 * g.moonKm)
    guard penumbralMagnitude > 0 else { return nil }

    func contact(_ radius: (ShadowState) -> Double, sign: Double) -> Double {
      // Root of f(t) = separation - radius(t); f < 0 at greatest, > 0 outside.
      func f(_ t: Double) -> Double { let s = state(atTT: t); return s.separationKm - radius(s) }
      var inside = tg
      var outside = tg + sign * 0.3
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

    let p1 = make(contact({ $0.penumbraKm + $0.moonKm }, sign: -1))
    let p4 = make(contact({ $0.penumbraKm + $0.moonKm }, sign: 1))
    var u1: LunarEclipseContact?, u4: LunarEclipseContact?, u2: LunarEclipseContact?, u3: LunarEclipseContact?
    var type = LunarEclipseType.penumbral
    if umbralMagnitude > 0 {
      type = .partial
      u1 = make(contact({ $0.umbraKm + $0.moonKm }, sign: -1))
      u4 = make(contact({ $0.umbraKm + $0.moonKm }, sign: 1))
      if umbralMagnitude >= 1 {
        type = .total
        u2 = make(contact({ $0.umbraKm - $0.moonKm }, sign: -1))
        u3 = make(contact({ $0.umbraKm - $0.moonKm }, sign: 1))
      }
    }
    return LunarEclipse(
      type: type,
      greatest: make(tg),
      penumbralMagnitude: penumbralMagnitude,
      umbralMagnitude: umbralMagnitude,
      gamma: g.separationKm / LunarEclipse.Constants.earthRadiusKm,
      p1: p1, u1: u1, u2: u2, u3: u3, u4: u4, p4: p4)
  }
}
