//
//  SolarEclipse.swift
//

import Foundation

// MARK: - SolarEclipseContact

/// One instant of a solar eclipse as seen from a place: a contact or the maximum.
public struct SolarEclipseContact: Sendable, Hashable {
  /// The instant in UT (≈ UTC to within a second), see ``BesselianElements``.
  public let date: Date
  /// The instant as a UT Julian date.
  public let julianDate: JulianDate
  /// Hours after the elements' `t0` (TDT).
  public let hoursFromT0: Double
  /// Geometric altitude of the Sun's centre above the horizon (no refraction), degrees.
  public let sunAltitude: Degrees
  /// Azimuth of the Sun's centre, degrees clockwise from north.
  public let sunAzimuth: Degrees

  /// Whether the Sun's centre is above the geometric horizon.
  public var isSunAboveHorizon: Bool { sunAltitude > 0 }
}

// MARK: - SolarEclipseLocalType

/// What an observer sees of a solar eclipse.
public enum SolarEclipseLocalType: String, Sendable, Hashable, CaseIterable {
  case partial
  case annular
  case total
}

// MARK: - SolarEclipseLocalCircumstances

/// Local circumstances of a solar eclipse: contacts, maximum, magnitude and obscuration.
public struct SolarEclipseLocalCircumstances: Sendable, Hashable {
  /// What the observer sees. A central eclipse that is entirely below the horizon during the central phase is
  /// reported as `.partial` (as NASA's calculator does) and has no `c2`/`c3`.
  public let type: SolarEclipseLocalType
  /// C1: the first contact, the start of the partial eclipse.
  public let c1: SolarEclipseContact
  /// C2: the start of totality or annularity; `nil` for a partial eclipse.
  public let c2: SolarEclipseContact?
  /// Maximum eclipse.
  public let maximum: SolarEclipseContact
  /// C3: the end of totality or annularity; `nil` for a partial eclipse.
  public let c3: SolarEclipseContact?
  /// C4: the last contact, the end of the partial eclipse.
  public let c4: SolarEclipseContact
  /// Magnitude at maximum: the fraction of the Sun's diameter covered (more than 1 for a total eclipse).
  public let magnitude: Double
  /// Obscuration at maximum: the fraction of the Sun's disk area covered, 0 to 1.
  public let obscuration: Double
  /// Apparent diameter of the Moon divided by that of the Sun at maximum (more than 1 for total, less for annular).
  public let moonSunRatio: Double

  /// Duration of totality or annularity in seconds, `nil` for a partial eclipse.
  public var centralDuration: TimeInterval? {
    guard let c2, let c3 else { return nil }
    return (c3.julianDate.days - c2.julianDate.days) * 86_400
  }

  /// Duration of the partial eclipse (C1 to C4) in seconds.
  public var partialDuration: TimeInterval {
    (c4.julianDate.days - c1.julianDate.days) * 86_400
  }
}

// MARK: - SolarEclipseGreatest

/// Global circumstances at the instant of greatest eclipse (the shadow axis passes closest to the Earth's centre).
public struct SolarEclipseGreatest: Sendable, Hashable {
  /// Greatest eclipse in UT.
  public let date: Date
  /// Greatest eclipse as a UT Julian date.
  public let julianDate: JulianDate
  /// Greatest eclipse in TDT, as a Julian date.
  public let terrestrialTime: JulianDate
  /// Least distance of the shadow axis from the Earth's centre in Earth radii, signed: positive when it passes north.
  public let gamma: Double
  /// Eclipse magnitude at greatest eclipse (NASA's catalogue definition: the Moon/Sun diameter ratio for a central
  /// eclipse, the fraction of the Sun's diameter covered for a partial one).
  public let magnitude: Double
  /// Geodetic latitude of the point of greatest eclipse (the point of the Earth closest to the axis), degrees.
  public let latitude: Degrees
  /// East longitude of the point of greatest eclipse, degrees in -180...180.
  public let longitude: Degrees
  /// Altitude of the Sun at that point, degrees.
  public let sunAltitude: Degrees
  /// Whether the shadow axis crosses the Earth's surface (a central eclipse).
  public let isCentral: Bool
  /// Duration of totality or annularity on the axis at that point in seconds, `nil` if not central.
  public let centralDuration: TimeInterval?
}

// MARK: - Computation

extension BesselianElements {

  /// The geodetic flattening factor `b/a` of the reference ellipsoid used by NASA (1 - 1/298.257).
  static let earthPolarRatio = 0.99664719
  /// Earth's equatorial radius in metres (the unit of the elements is this radius).
  static let earthRadiusMetres = 6_378_140.0
  /// Radians per second of the Earth's rotation, `1 / 13713.44`.
  static let earthRotationRadPerSecond = 1.0 / 13_713.44

  /// The eclipse type, from the geometry of the shadow over the Earth.
  ///
  /// Sampled over the validity interval: a total eclipse has `l2 − ζ tan f2 < 0` on the central line, an annular one
  /// `> 0`, a hybrid one both. When the axis misses the Earth but the umbra touches it the sign of the umbra at
  /// the limb decides (a non-central total or annular eclipse); otherwise the eclipse is partial.
  public var eclipseType: SolarEclipseType {
    var sawTotal = false
    var sawAnnular = false
    var minLimbDistance = Double.infinity
    var limbSign = 0.0
    let step = 0.01
    var t = validHours.lowerBound
    while t <= validHours.upperBound {
      let s = state(at: t)
      if let zeta = axisSurfaceZeta(s) {
        let l2p = s.l2 - zeta * tanF2
        if l2p < 0 { sawTotal = true } else { sawAnnular = true }
      } else {
        let distance = Self.limbDistance(s) // distance of axis from the Earth's projected limb
        if distance < minLimbDistance {
          minLimbDistance = distance
          limbSign = s.l2
        }
      }
      t += step
    }
    if sawTotal && sawAnnular { return .hybrid }
    if sawTotal { return .total }
    if sawAnnular { return .annular }
    if minLimbDistance < abs(limbSign) { return limbSign < 0 ? .total : .annular }
    return .partial
  }

  /// Circumstances at the instant of greatest eclipse.
  public var greatestEclipse: SolarEclipseGreatest {
    // Least distance of the axis from the centre: minimise x² + y².
    var t = 0.0
    for _ in 0..<50 {
      let s = state(at: t)
      let dd = s.dx * s.dx + s.dy * s.dy
      let step = (s.x * s.dx + s.y * s.dy) / dd
      t -= step
      if abs(step) < 1e-10 { break }
    }
    let s = state(at: t)
    let gamma = (s.y >= 0 ? 1.0 : -1.0) * hypot(s.x, s.y)

    // The point of the Earth closest to the axis, and the shadow there.
    let b = Self.earthPolarRatio
    var xi: Double, eta: Double, zeta: Double
    var central = true
    if let z = axisSurfaceZeta(s) {
      xi = s.x
      eta = s.y
      zeta = z
    } else {
      // Nearest point of the projected Earth limb (an ellipse with semi-axes 1 and e), radially approximated.
      central = false
      let e = sqrt(b * b * cos(s.d) * cos(s.d) + sin(s.d) * sin(s.d))
      let scale = 1 / sqrt(s.x * s.x + (s.y / e) * (s.y / e))
      xi = s.x * scale
      eta = s.y * scale
      zeta = 0
    }
    // Invert xi/eta/zeta to the geocentric position; see `fundamentalToGeographic`.
    let sinD = sin(s.d), cosD = cos(s.d)
    let p = eta * cosD + zeta * sinD // rho sin(phi')
    let q = zeta * cosD - eta * sinD // rho cos(phi') cos H
    let r = xi // rho cos(phi') sin H
    let geocentricLat = atan2(p, sqrt(q * q + r * r))
    let latitude = atan(tan(geocentricLat) / (b * b))
    let hourAngle = atan2(r, q)
    // H = mu - lambdaWest - omega dT  =>  lambdaEast = H - mu + omega dT
    var lonEast = hourAngle - s.mu + Self.earthRotationRadPerSecond * deltaT
    lonEast = atan2(sin(lonEast), cos(lonEast))
    let altitude = asin(sinD * sin(latitude) + cosD * cos(latitude) * cos(hourAngle))

    let l1p = s.l1 - zeta * tanF1
    let l2p = s.l2 - zeta * tanF2
    let m = hypot(s.x - xi, s.y - eta)
    // NASA's catalogue magnitude: for a central eclipse the ratio of the Moon's to the Sun's apparent diameter
    // (more than 1 for total, less for annular); for a partial one the fraction of the diameter covered.
    let magnitude = central ? (l1p - l2p) / (l1p + l2p) : (l1p - m) / (l1p + l2p)

    var duration: TimeInterval?
    if central {
      let observer = Observer(latitude: latitude * 180 / .pi, longitude: lonEast * 180 / .pi, elevation: .double(0))
      if let local = localCircumstances(observer: observer) {
        duration = local.centralDuration
      }
    }
    let ut = universalTime(atHoursFromT0: t)
    return SolarEclipseGreatest(
      date: ut.date,
      julianDate: ut,
      terrestrialTime: JulianDate(days: t0.days + t / 24),
      gamma: gamma,
      magnitude: magnitude,
      latitude: latitude * 180 / .pi,
      longitude: lonEast * 180 / .pi,
      sunAltitude: altitude * 180 / .pi,
      isCentral: central,
      centralDuration: duration)
  }

  /// Local circumstances for an observer.
  ///
  /// Contacts are found by the standard Besselian iteration (Explanatory Supplement; Meeus), using the observer's
  /// geocentric coordinates `ρ sin φ'`, `ρ cos φ'` on the ellipsoid (with the elevation of ``Observer``; the
  /// obscuring-feature distance of the tuple form is ignored), and the Earth rotation corrected for ΔT.
  ///
  /// - Returns: `nil` if the eclipse is not visible from there: the Sun is not touched by the penumbra, or the Sun is
  ///   below the geometric horizon at C1, maximum and C4.
  public func localCircumstances(observer: Observer) -> SolarEclipseLocalCircumstances? {
    let site = LocalSite(observer: observer)

    // Maximum eclipse.
    var tm = 0.0
    var iterations = 0
    var step = 1.0
    var loc = locate(at: tm, site: site)
    while abs(step) > 1e-9, iterations < 50 {
      step = (loc.u * loc.a + loc.v * loc.b) / loc.n2
      tm -= step
      loc = locate(at: tm, site: site)
      iterations += 1
    }
    let mid = loc
    let m = hypot(mid.u, mid.v)
    let magnitude = (mid.l1p - m) / (mid.l1p + mid.l2p)
    guard magnitude > 0 else { return nil }

    // C1 and C4 from the penumbra.
    let c1 = contact(from: mid, radius: { $0.l1p }, sign: -1, site: site)
    let c4 = contact(from: mid, radius: { $0.l1p }, sign: 1, site: site)

    // Central eclipse at this place?
    let isCentral = m < abs(mid.l2p)
    var c2: Local?
    var c3: Local?
    var localType = SolarEclipseLocalType.partial
    if isCentral {
      c2 = contact(from: mid, radius: { $0.l2p }, sign: -1, site: site)
      c3 = contact(from: mid, radius: { $0.l2p }, sign: 1, site: site)
      localType = mid.l2p < 0 ? .total : .annular
    }

    // Not visible: the Sun is below the horizon throughout.
    if c1.altitude <= 0, c4.altitude <= 0, mid.altitude <= 0 { return nil }
    // Central phase entirely below the horizon: a partial eclipse for this observer.
    if let a = c2, let b = c3, a.altitude <= 0, b.altitude <= 0 {
      localType = .partial
      c2 = nil
      c3 = nil
    }

    return SolarEclipseLocalCircumstances(
      type: localType,
      c1: makeContact(c1),
      c2: c2.map(makeContact),
      maximum: makeContact(mid),
      c3: c3.map(makeContact),
      c4: makeContact(c4),
      magnitude: magnitude,
      obscuration: obscuration(mid: mid, magnitude: magnitude, central: isCentral),
      moonSunRatio: (mid.l1p - mid.l2p) / (mid.l1p + mid.l2p))
  }

  // MARK: Private

  /// Observer constants.
  private struct LocalSite {
    let latitude: Double // geodetic, radians
    let lonWest: Double // radians
    let rhoSin: Double
    let rhoCos: Double

    init(observer: Observer) {
      let rad = Double.pi / 180
      latitude = observer.latitude * rad
      lonWest = -observer.longitude * rad
      let height: Double
      switch observer.elevation {
      case .double(let h): height = h
      case .tuple(let h, _): height = h
      }
      let u = atan(BesselianElements.earthPolarRatio * tan(latitude))
      rhoSin = BesselianElements.earthPolarRatio * sin(u) + height / BesselianElements.earthRadiusMetres * sin(latitude)
      rhoCos = cos(u) + height / BesselianElements.earthRadiusMetres * cos(latitude)
    }
  }

  /// Time and place dependent quantities (Meeus ch. 54 / Explanatory Supplement).
  private struct Local {
    var t: Double
    var u: Double
    var v: Double
    var a: Double
    var b: Double
    var l1p: Double
    var l2p: Double
    var n2: Double
    var altitude: Double // radians
    var azimuth: Double // radians
  }

  private func locate(at t: Double, site: LocalSite) -> Local {
    let s = state(at: t)
    let h = s.mu - site.lonWest - Self.earthRotationRadPerSecond * deltaT
    let sinH = sin(h), cosH = cos(h)
    let sinD = sin(s.d), cosD = cos(s.d)
    let xi = site.rhoCos * sinH
    let eta = site.rhoSin * cosD - site.rhoCos * cosH * sinD
    let zeta = site.rhoSin * sinD + site.rhoCos * cosH * cosD
    let dxi = s.dmu * site.rhoCos * cosH
    let deta = s.dmu * xi * sinD - zeta * s.dd
    let u = s.x - xi
    let v = s.y - eta
    let a = s.dx - dxi
    let b = s.dy - deta
    let sinLat = sin(site.latitude), cosLat = cos(site.latitude)
    let altitude = asin(sinD * sinLat + cosD * cosLat * cosH)
    let azimuth = atan2(-sinH * cosD, sinD * cosLat - cosH * sinLat * cosD)
    return Local(
      t: t, u: u, v: v, a: a, b: b,
      l1p: s.l1 - zeta * tanF1,
      l2p: s.l2 - zeta * tanF2,
      n2: a * a + b * b,
      altitude: altitude,
      azimuth: azimuth)
  }

  /// Iterates a contact with the circle of radius `|radius(local)|` around the shadow axis.
  /// `sign` is -1 for the contact before maximum and +1 for the one after.
  private func contact(
    from mid: Local,
    radius: (Local) -> Double,
    sign: Double,
    site: LocalSite)
    -> Local
  {
    var n = sqrt(mid.n2)
    let r0 = abs(radius(mid))
    var q = (mid.a * mid.v - mid.u * mid.b) / n / r0
    q = sqrt(max(0, 1 - q * q)) * r0 / n
    var t = mid.t + sign * q
    var loc = locate(at: t, site: site)
    for _ in 0..<50 {
      n = sqrt(loc.n2)
      let r = abs(radius(loc))
      var tmp = (loc.a * loc.v - loc.u * loc.b) / n / r
      tmp = sign * sqrt(max(0, 1 - tmp * tmp)) * r / n
      let correction = (loc.u * loc.a + loc.v * loc.b) / loc.n2 - tmp
      t -= correction
      loc = locate(at: t, site: site)
      if abs(correction) < 1e-9 { break }
    }
    return loc
  }

  private func makeContact(_ l: Local) -> SolarEclipseContact {
    let ut = universalTime(atHoursFromT0: l.t)
    var azimuth = l.azimuth * 180 / .pi
    if azimuth < 0 { azimuth += 360 }
    return SolarEclipseContact(
      date: ut.date,
      julianDate: ut,
      hoursFromT0: l.t,
      sunAltitude: l.altitude * 180 / .pi,
      sunAzimuth: azimuth)
  }

  /// Fraction of the Sun's disk covered at maximum.
  private func obscuration(mid: Local, magnitude: Double, central: Bool) -> Double {
    if magnitude <= 0 { return 0 }
    if magnitude >= 1 { return 1 }
    let ratio = (mid.l1p - mid.l2p) / (mid.l1p + mid.l2p)
    if central { return ratio * ratio } // annular: the Moon's disk lies fully inside the Sun's
    let m = hypot(mid.u, mid.v)
    let l1 = mid.l1p, l2 = mid.l2p
    let c = acos(clamp((l1 * l1 + l2 * l2 - 2 * m * m) / (l1 * l1 - l2 * l2)))
    let bb = acos(clamp((l1 * l2 + m * m) / m / (l1 + l2)))
    let a = Double.pi - bb - c
    return ((ratio * ratio * a + bb) - ratio * sin(c)) / Double.pi
  }

  private func clamp(_ v: Double) -> Double { min(1, max(-1, v)) }

  /// `zeta` of the point where the shadow axis meets the near side of the Earth's ellipsoid; `nil` if it misses.
  private func axisSurfaceZeta(_ s: BesselianState) -> Double? {
    let b = Self.earthPolarRatio
    let sinD = sin(s.d), cosD = cos(s.d)
    // (eta cosD + z sinD)² / b² + (z cosD - eta sinD)² + x² = 1, a quadratic in z.
    let A = sinD * sinD / (b * b) + cosD * cosD
    let B = 2 * s.y * cosD * sinD / (b * b) - 2 * s.y * sinD * cosD
    let C = s.y * s.y * cosD * cosD / (b * b) + s.y * s.y * sinD * sinD + s.x * s.x - 1
    let disc = B * B - 4 * A * C
    guard disc >= 0 else { return nil }
    return (-B + sqrt(disc)) / (2 * A)
  }

  /// Distance of the shadow axis from the Earth's projected limb (positive if outside), in Earth radii.
  private static func limbDistance(_ s: BesselianState) -> Double {
    let b = earthPolarRatio
    let e = sqrt(b * b * cos(s.d) * cos(s.d) + sin(s.d) * sin(s.d))
    let r = sqrt(s.x * s.x + (s.y / e) * (s.y / e))
    let scale = 1 / r
    return hypot(s.x - s.x * scale, s.y - s.y * scale)
  }
}

// MARK: - SolarEclipseCatalog

/// Lookup helpers for the built-in table ``BesselianElements/catalog``.
public enum SolarEclipseCatalog {

  /// All built-in eclipses in chronological order (2023 to 2035).
  public static var all: [BesselianElements] { BesselianElements.catalog }

  /// The first built-in eclipse whose greatest eclipse (UT) is after `date`.
  public static func next(after date: Date) -> BesselianElements? {
    all.first { $0.greatestEclipse.date > date }
  }

  /// The built-in eclipse whose greatest eclipse lies within `window` seconds of `date` (default one day).
  public static func eclipse(near date: Date, window: TimeInterval = 86_400) -> BesselianElements? {
    all.first { abs($0.greatestEclipse.date.timeIntervalSince(date)) <= window }
  }
}
