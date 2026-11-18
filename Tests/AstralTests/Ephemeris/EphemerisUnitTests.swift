import Astral
import Foundation
import simd
import Testing

// MARK: - Helpers

private func earthPosition(_ jd: Double, moonTerms: Bool = true) -> SIMD3<Double> {
  snapshot(jd, moonTerms: moonTerms).states[.earth]!.position
}

private func moonGeocentric(_ jd: Double, moonTerms: Bool) -> SIMD3<Double> {
  let s = snapshot(jd, moonTerms: moonTerms)
  return s.states[.moon]!.position - s.states[.earth]!.position
}

/// Finds x in [lo, hi] where f changes sign (f must be continuous there), by bisection.
private func bisect(_ lo: Double, _ hi: Double, _ f: (Double) -> Double) -> Double {
  var a = lo
  var b = hi
  let fa = f(a)
  for _ in 0..<60 {
    let m = 0.5 * (a + b)
    if (f(m) < 0) == (fa < 0) { a = m } else { b = m }
  }
  return 0.5 * (a + b)
}

// MARK: - EarthOrbitTests

@Suite("Earth orbit", .tags(.ephemeris, .accuracy))
struct EarthOrbitTests {
  @Test
  func atJ2000LongitudeAndDistance_barycentre() throws {
    let p = Kepler.position(elements: try #require(Catalog.earth.elements), T: 0)
    let s = Spherical(p)
    #expect(abs(s.lon * degPerRad - 100.38) <= 0.1, "lon \(s.lon * degPerRad)")
    #expect(abs(s.r - 0.9833) <= 0.0005, "r \(s.r)")
  }

  @Test(arguments: [false, true])
  func atJ2000LongitudeAndDistance_snapshotEarth(moonTerms: Bool) {
    let s = Spherical(earthPosition(Epoch.jd2000, moonTerms: moonTerms))
    let lon = (s.lon < 0 ? s.lon + 2 * .pi : s.lon) * degPerRad
    #expect(abs(lon - 100.38) <= 0.1, "lon \(lon)")
    #expect(abs(s.r - 0.9833) <= 0.0005, "r \(s.r)")
  }

  /// Distances use the barycentre-corrected Earth (snapshot). The *dates* of the extremes use the
  /// Earth-Moon barycentre track: Earth's centre wobbles +-4,700 km (3e-5 AU) around it every
  /// month, which is comparable to the distance change over several days near perihelion, so the
  /// centre's minimum can fall a few days either side of the barycentre's (e.g. 31 Dec).
  @Test(arguments: [1950, 2000, 2026])
  func perihelionAndAphelionOverOneYear(year: Int) throws {
    let start = JulianDate(utcDate(year, 1, 1)).days
    let end = JulianDate(utcDate(year + 1, 1, 1)).days
    let emb = try #require(Catalog.earth.elements)
    var minR = Double.infinity
    var maxR = 0.0
    var minEmb = Double.infinity
    var maxEmb = 0.0
    var minAt = 0.0
    var maxAt = 0.0
    var jd = start
    while jd <= end {
      let r = simd_length(earthPosition(jd))
      minR = min(minR, r)
      maxR = max(maxR, r)
      let rb = simd_length(Kepler.position(elements: emb, T: JulianDate(days: jd).centuriesSinceJ2000))
      if rb < minEmb { minEmb = rb
        minAt = jd
      }
      if rb > maxEmb { maxEmb = rb
        maxAt = jd
      }
      jd += 0.05
    }
    #expect(abs(minR - 0.9833) <= 0.0005, "min \(minR)")
    #expect(abs(maxR - 1.0167) <= 0.0005, "max \(maxR)")
    #expect(abs(minEmb - 0.9833) <= 0.0005, "barycentre min \(minEmb)")
    #expect(abs(maxEmb - 1.0167) <= 0.0005, "barycentre max \(maxEmb)")
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = try #require(TimeZone(identifier: "UTC"))
    let minParts = cal.dateComponents([.month, .day], from: JulianDate(days: minAt).date)
    let maxParts = cal.dateComponents([.month, .day], from: JulianDate(days: maxAt).date)
    #expect(minParts.month == 1 && minParts.day! <= 10, "perihelion on \(minParts)")
    #expect(maxParts.month == 7 && maxParts.day! <= 10, "aphelion on \(maxParts)")
  }

  @Test(arguments: [Epoch.jd1900, Epoch.jd2000, Epoch.jd2026])
  func returnsToSameLongitudeAfterSiderealYear(start: Double) {
    let lon0 = Spherical(earthPosition(start)).lon
    // Signed longitude difference is monotonic through zero near one sidereal year.
    let f: (Double) -> Double = { wrapPi(Spherical(earthPosition(start + $0)).lon - lon0) }
    let period = bisect(365.0, 365.5, f)
    #expect(abs(period - 365.256) <= 0.01, "period \(period)")
  }
}

// MARK: - MoonOrbitTests

@Suite("Moon orbit", .tags(.ephemeris, .lunar, .slow))
struct MoonOrbitTests {
  /// Mean sidereal period from total unwrapped geocentric longitude advance over ~120 revolutions.
  /// (Single-revolution return times wobble by ~0.03 d from the equation of centre, so the
  /// spec's "sidereal period" is measured as a mean.)
  @Test(arguments: [false, true], [Epoch.jd2000, Epoch.jd2026])
  func siderealPeriod(moonTerms: Bool, start: Double) {
    let system = SolarSystem(bodies: Catalog.all, moonPeriodicTerms: moonTerms)
    func lon(_ jd: Double) -> Double {
      let s = system.snapshot(at: JulianDate(days: jd))
      return Spherical(s.states[.moon]!.position - s.states[.earth]!.position).lon
    }
    let span = 3_278.0
    var prev = lon(start)
    var total = 0.0
    var t = 0.0
    let step = 0.5
    while t < span {
      let cur = lon(start + t + step)
      total += wrapPi(cur - prev)
      prev = cur
      t += step
    }
    let period = t / (total / (2 * .pi))
    #expect(abs(period - 27.32) <= 0.02, "sidereal period \(period)")
  }

  /// Mean synodic month: 12 consecutive lunations (new moon to new moon) divided by 12.
  @Test(arguments: [false, true], [Epoch.jd2000, Epoch.jd2026])
  func synodicPeriodOver12Lunations(moonTerms: Bool, start: Double) {
    let system = SolarSystem(bodies: Catalog.all, moonPeriodicTerms: moonTerms)
    func elongation(_ jd: Double) -> Double {
      let s = system.snapshot(at: JulianDate(days: jd))
      let earth = s.states[.earth]!.position
      let moon = Spherical(s.states[.moon]!.position - earth).lon
      let sun = Spherical(-earth).lon
      return wrapPi(moon - sun)
    }
    // New moons: elongation crosses 0 going upward.
    var newMoons = [Double]()
    var t = start
    var prev = elongation(t)
    while newMoons.count < 13 {
      let next = t + 0.25
      let cur = elongation(next)
      if prev < 0, cur >= 0, abs(prev) < 1, abs(cur) < 1 {
        newMoons.append(bisect(t, next, elongation))
      }
      prev = cur
      t = next
    }
    let period = (newMoons[12] - newMoons[0]) / 12
    #expect(abs(period - 29.53) <= 0.05, "synodic period \(period)")
  }

  @Test(arguments: [false, true])
  func distanceAlwaysBetween355000And407000km(moonTerms: Bool) {
    var lo = Double.infinity
    var hi = 0.0
    for start in [Epoch.jd1900, Epoch.jd2000, Epoch.jd2026] {
      var d = 0.0
      while d < 6_800 { // ~ 18.6 years, one full node cycle, plus margin
        let r = simd_length(moonGeocentric(start + d, moonTerms: moonTerms)) * Units.kmPerAU
        lo = min(lo, r)
        hi = max(hi, r)
        d += 0.37
      }
    }
    #expect(lo >= 355_000, "min distance \(lo) km")
    #expect(hi <= 407_000, "max distance \(hi) km")
  }
}

// MARK: - OrientationTests

@Suite("Orientation and snapshot", .tags(.ephemeris, .unit))
struct OrientationTests {
  @Test
  func subSolarLongitudeAtJ2000WithinTwoDegrees() throws {
    let s = snapshot(Epoch.jd2000)
    let earth = try #require(s.states[.earth])
    let sunDirEcliptic = simd_normalize(-earth.position)
    let body = earth.orientation.inverse.act(sunDirEcliptic)
    let lonDeg = atan2(body.y, body.x) * degPerRad
    #expect(abs(lonDeg) <= 2, "sub-solar longitude \(lonDeg) deg")
  }

  @Test
  func earthPoleIsTiltedByObliquity() throws {
    let earth = try #require(snapshot(Epoch.jd2026).states[.earth])
    let pole = earth.orientation.act(SIMD3(0, 0, 1))
    let eps = 23.4393 * Units.degToRad
    #expect(simd_length(pole - SIMD3(0, sin(eps), cos(eps))) < 1e-12)
  }

  @Test
  func earthSpinsEastwardOncePerSiderealDay() {
    let t0 = JulianDate(days: Epoch.jd2000)
    let q0 = BodyOrientation.earth(at: t0)
    let t1 = JulianDate(days: Epoch.jd2000 + 1 / 1.00273781191135448)
    let q1 = BodyOrientation.earth(at: t1)
    let x0 = q0.act(SIMD3(1, 0, 0))
    let x1 = q1.act(SIMD3(1, 0, 0))
    #expect(simd_length(x0 - x1) < 1e-7) // double rounding of JD ~2.4e6 is ~3e-9 rad
    // Quarter sidereal day later the prime meridian has moved counter-clockwise about the pole.
    let tq = JulianDate(days: Epoch.jd2000 + 0.25 / 1.00273781191135448)
    let xq = BodyOrientation.earth(at: tq).act(SIMD3(1, 0, 0))
    let pole = q0.act(SIMD3(0, 0, 1))
    #expect(simd_dot(simd_cross(x0, xq), pole) > 0)
  }

  @Test
  func moonIsTidallyLockedToEarth() throws {
    let s = snapshot(Epoch.jd2026)
    let earth = try #require(s.states[.earth])
    let moon = try #require(s.states[.moon])
    let towardEarth = simd_normalize(earth.position - moon.position)
    let bodyX = moon.orientation.act(SIMD3(1, 0, 0))
    #expect(simd_length(bodyX - towardEarth) < 1e-9)
    let north = moon.orientation.act(SIMD3(0, 0, 1))
    #expect(north.z > 0.9)
    #expect(abs(simd_length(moon.orientation.vector) - 1) < 1e-9)
  }

  @Test
  func snapshotContainsEveryCatalogBodyWithSunAtOrigin() throws {
    let s = snapshot(Epoch.jd2000)
    for body in Catalog.all {
      #expect(s.states[body.id] != nil, "missing \(body.id)")
    }
    #expect(s.states[.pluto] == nil)
    #expect(simd_length(try #require(s.states[.sun]).position) == 0)
    #expect(SolarSystem(bodies: Catalog.allWithPluto).snapshot(at: .j2000).states[.pluto] != nil)
  }

  @Test
  func earthIsBarycentreMinusMoonOver82() throws {
    let s = snapshot(Epoch.jd2026, moonTerms: false)
    let emb = Kepler.position(
      elements: try #require(Catalog.earth.elements),
      T: JulianDate(days: Epoch.jd2026).centuriesSinceJ2000
    )
    let earth = try #require(s.states[.earth]).position
    let moon = try #require(s.states[.moon]).position
    let geo = moon - earth
    #expect(simd_length(earth - (emb - geo / 82.30057)) < 1e-12)
    // barycentre sits on the line, 1/82.3 of the way from Earth to the Moon
    #expect(simd_length((earth + geo / 82.30057) - emb) < 1e-12)
  }

  @Test
  func orbitPathIsClosedLoopOnTheOrbit() throws {
    let system = SolarSystem()
    let time = JulianDate(days: Epoch.jd2026)
    let path = system.orbitPath(of: .mars, at: time, samples: 256)
    #expect(path.count == 256)
    let el = try #require(Catalog.mars.elements)
    let T = time.centuriesSinceJ2000
    let a = el.a + el.aRate * T
    let e = el.e + el.eRate * T
    for p in path {
      let r = simd_length(p)
      #expect(r >= a * (1 - e) - 1e-9 && r <= a * (1 + e) + 1e-9)
    }
    #expect(system.orbitPath(of: .sun, at: time, samples: 10).isEmpty)
    // Moon's path is geocentric-sized
    let moonPath = system.orbitPath(of: .moon, at: time, samples: 64)
    #expect(moonPath.allSatisfy { simd_length($0) * Units.kmPerAU < 410_000 })
  }
}
