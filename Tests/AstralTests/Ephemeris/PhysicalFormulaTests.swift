// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import simd
import Testing

private func planetocentric(fromPlanetographic g: Double, flattening f: Double) -> Double {
  atan(tan(g * .pi / 180) * (1 - f) * (1 - f)) * 180 / .pi
}

// MARK: - PhysicalOtherBodiesTests

@Suite("Fixture: Sun, Moon and Pluto geometry vs JPL Horizons", .tags(.ephemeris, .accuracy, .integration))
struct PhysicalOtherBodiesTests {
  @Test
  func sunMatchesHorizons() throws {
    let fixture = try PhysicalFixture.load()
    let system = SolarSystem()
    var worstDiameter = 0.0
    var worstMag = 0.0
    for row in try fixture.rows("sun") {
      let p = try #require(system.physical(of: .sun, at: JulianDate(days: row.jd)))
      let dDiam = abs(p.angularDiameterArcsec - row.angDiamArcsec) / row.angDiamArcsec
      worstDiameter = max(worstDiameter, dDiam)
      #expect(dDiam <= 0.0001, "Sun JD \(row.jd) diameter \(dDiam)")
      #expect(p.phaseAngleDeg == 0 && p.illuminatedFraction == 1 && p.elongationDeg == 0)
      let ref = try #require(row.apmag)
      let m = try #require(p.visualMagnitude)
      worstMag = max(worstMag, abs(m - ref))
      #expect(abs(m - ref) <= 0.01, "Sun JD \(row.jd) magnitude \(m) vs \(ref)")
    }
    print("PHYSICAL Sun: worst diameter \(fmt(worstDiameter * 100, 3))%, magnitude \(fmt(worstMag, 4))")
  }

  /// The default Moon model (mean elements plus periodic terms) is only good to a degree or so in longitude.
  @Test
  func moonMatchesHorizons() throws {
    let fixture = try PhysicalFixture.load()
    let system = SolarSystem()
    var worst = (distance: 0.0, phase: 0.0, elongation: 0.0, illuminated: 0.0)
    for row in try fixture.rows("moon") {
      let p = try #require(system.physical(of: .moon, at: JulianDate(days: row.jd)))
      let dDist = abs(p.distanceAU - row.rangeAU) / row.rangeAU
      let dPhase = abs(p.phaseAngleDeg - row.phaseDeg)
      let dElong = abs(p.elongationDeg - row.elongationDeg)
      let dIllu = abs(p.illuminatedFraction - row.illuPercent / 100)
      worst = (max(worst.distance, dDist), max(worst.phase, dPhase), max(worst.elongation, dElong), max(worst.illuminated, dIllu))
      #expect(dDist <= 0.025, "Moon JD \(row.jd) distance \(dDist)")
      #expect(dPhase <= 0.4, "Moon JD \(row.jd) phase \(dPhase) deg")
      #expect(dElong <= 0.4, "Moon JD \(row.jd) elongation \(dElong) deg")
      #expect(p.visualMagnitude == nil, "no Moon magnitude model")
      #expect(p.subObserverLatitudeDeg == nil, "no Moon libration model")
    }
    print("PHYSICAL Moon: worst distance \(fmt(worst.distance * 100, 3))%, phase \(fmt(worst.phase, 3)) deg, "
      + "elongation \(fmt(worst.elongation, 3)) deg, illuminated \(fmt(worst.illuminated, 4))")
  }

  /// Pluto's elements are unverified (see `Catalog.pluto`): this only records the error with a generous bound.
  @Test
  func plutoRecordedAgainstHorizons() throws {
    let fixture = try PhysicalFixture.load()
    let system = SolarSystem(bodies: Catalog.allWithPluto)
    var worstDistance = 0.0
    var worstPhase = 0.0
    for row in try fixture.rows("pluto") {
      let p = try #require(system.physical(of: .pluto, at: JulianDate(days: row.jd)))
      let dDist = abs(p.distanceAU - row.rangeAU) / row.rangeAU
      worstDistance = max(worstDistance, dDist)
      worstPhase = max(worstPhase, abs(p.phaseAngleDeg - row.phaseDeg))
      #expect(dDist <= 0.05, "Pluto JD \(row.jd) distance \(dDist)")
      #expect(p.visualMagnitude == nil, "no Pluto magnitude model")
    }
    print("PHYSICAL Pluto (unverified elements): worst distance \(fmt(worstDistance * 100, 3))%, phase \(fmt(worstPhase, 3)) deg")
  }
}

// MARK: - SubLatitudeTests

@Suite("Sub-observer and sub-solar latitudes vs JPL Horizons", .tags(.ephemeris, .accuracy, .integration))
struct SubLatitudeTests {
  /// Horizons reports planetographic latitudes; the model's are planetocentric, so convert with the `pck00011` radii.
  /// The model uses the mean pole (no nutation terms, e.g. Neptune's pole wobbles by about 0.5 deg).
  ///
  /// Mars: pck00011 carries the IAU 2015 Mars pole (RA 317.269, Dec 54.433), whereas Horizons' `IAU_MARS` frame
  /// still reproduces the IAU 2009 pole (RA 317.681, Dec 52.887); the latitudes differ by up to 1.6 deg for that
  /// reason (verified: using the 2009 pole matches Horizons to 0.003 deg). The Mars tolerance is that difference.
  @Test(arguments: [
    (BodyID.mars, "mars", 2.0),
    (.jupiter, "jupiter", 0.05),
    (.saturn, "saturn", 0.15),
    (.uranus, "uranus", 0.1),
    (.neptune, "neptune", 0.8),
  ])
  func latitudesMatchHorizons(id: BodyID, key: String, toleranceDeg: Double) throws {
    let fixture = try PhysicalFixture.load()
    let system = SolarSystem()
    let f = try #require(PhysicalConstants.radii(of: id)).flattening
    var worst = 0.0
    for row in try fixture.rows(key) {
      let p = try #require(system.physical(of: id, at: JulianDate(days: row.jd)))
      let obs = try #require(p.subObserverLatitudeDeg)
      let sun = try #require(p.subSolarLatitudeDeg)
      let refObs = planetocentric(fromPlanetographic: try #require(row.obsSubLatDeg), flattening: f)
      let refSun = planetocentric(fromPlanetographic: try #require(row.sunSubLatDeg), flattening: f)
      worst = max(worst, abs(obs - refObs), abs(sun - refSun))
      #expect(abs(obs - refObs) <= toleranceDeg, "\(id) JD \(row.jd) sub-observer \(obs) vs \(refObs)")
      #expect(abs(sun - refSun) <= toleranceDeg, "\(id) JD \(row.jd) sub-solar \(sun) vs \(refSun)")
    }
    print("PHYSICAL \(id.displayName) sub-latitudes: worst \(fmt(worst, 3)) deg")
  }
}

// MARK: - PlanetaryMagnitudeTests

@Suite("Planetary magnitude formulas (Mallama & Hilton 2018)", .tags(.ephemeris, .accuracy, .unit))
struct PlanetaryMagnitudeTests {
  /// Feeds the formulas Horizons' own geometry (Sun-Earth distance from the Sun rows, Sun-planet distance from the
  /// triangle Sun-Earth-planet) so that only the transcription of the formulas is tested. Horizons uses the same
  /// model, so they agree to rounding, except Mars (surface-feature corrections omitted).
  @Test(arguments: [
    (BodyID.mercury, "mercury", 0.004),
    (.venus, "venus", 0.004),
    (.mars, "mars", 0.1),
    (.jupiter, "jupiter", 0.004),
    (.saturn, "saturn", 0.005),
    (.uranus, "uranus", 0.004),
    (.neptune, "neptune", 0.005),
  ])
  func formulasMatchHorizonsGivenItsGeometry(id: BodyID, key: String, tolerance: Double) throws {
    let fixture = try PhysicalFixture.load()
    let sunRows = try fixture.rows("sun")
    let f = try #require(PhysicalConstants.radii(of: id)).flattening
    var worst = 0.0
    for (row, sunRow) in zip(try fixture.rows(key), sunRows) {
      let R = sunRow.rangeAU
      let d = row.rangeAU
      let eps = row.elongationDeg * .pi / 180
      let r = (R * R + d * d - 2 * R * d * cos(eps)).squareRoot()
      let year = 2000 + (row.jd - 2_451_545.0) / 365.25
      let obs = row.obsSubLatDeg.map { planetocentric(fromPlanetographic: $0, flattening: f) }
      let sun = row.sunSubLatDeg.map { planetocentric(fromPlanetographic: $0, flattening: f) }
      let m = try #require(PlanetaryMagnitude.visualMagnitude(
        of: id,
        sunDistanceAU: r,
        earthDistanceAU: d,
        phaseAngleDeg: row.phaseDeg,
        subObserverLatitudeDeg: obs,
        subSolarLatitudeDeg: sun,
        year: year
      ))
      let ref = try #require(row.apmag)
      worst = max(worst, abs(m - ref))
      #expect(abs(m - ref) <= tolerance, "\(id) JD \(row.jd): \(m) vs Horizons \(ref)")
    }
    print("PHYSICAL \(id.displayName) magnitude formula given Horizons geometry: worst \(fmt(worst, 4))")
  }

  /// The paper (section 4.5) quotes Jupiter's brightest magnitude, -2.94, on 2034-10-01.
  @Test
  func jupiterBrightestMatchesPaper() throws {
    let time = try #require(JulianDate(DateComponents(year: 2034, month: 10, day: 1)))
    let p = try #require(SolarSystem().physical(of: .jupiter, at: time))
    #expect(abs(try #require(p.visualMagnitude) - -2.94) < 0.02)
  }

  @Test
  func saturnRingsBrightenTheGlobe() throws {
    func saturn(_ e: Double?, _ s: Double?, alpha: Double = 3) -> Double? {
      PlanetaryMagnitude.visualMagnitude(
        of: .saturn,
        sunDistanceAU: 9.5,
        earthDistanceAU: 8.6,
        phaseAngleDeg: alpha,
        subObserverLatitudeDeg: e,
        subSolarLatitudeDeg: s
      )
    }
    let withRings = try #require(saturn(20, 20))
    let globe = try #require(PlanetaryMagnitude.saturnGlobeMagnitude(sunDistanceAU: 9.5, earthDistanceAU: 8.6, phaseAngleDeg: 3))
    #expect(globe - withRings > 0.5)
    let edgeOn = try #require(saturn(0, 0))
    // Eq. 10 at B = 0 keeps the 0.026 mag/deg slope, so it is a little fainter than the globe-only Eq. 11.
    #expect(edgeOn > globe && edgeOn - globe < 0.15)
    // Rings seen from one side and lit from the other: effective inclination 0.
    #expect(try #require(saturn(20, -20)) == edgeOn)
    // Without latitudes only the globe is available; beyond 150 degrees nothing is.
    #expect(saturn(nil, nil) == globe)
    #expect(saturn(nil, nil, alpha: 160) == nil)
    // Beyond the 27 degree effective inclination limit the paper falls back to the globe.
    #expect(saturn(30, 30) == globe)
  }

  @Test
  func piecewiseFormulasAreContinuous() throws {
    func v(_ id: BodyID, _ alpha: Double) -> Double {
      PlanetaryMagnitude.visualMagnitude(of: id, sunDistanceAU: 1, earthDistanceAU: 1, phaseAngleDeg: alpha) ?? .nan
    }
    #expect(abs(v(.venus, 163.7) - v(.venus, 163.7 + 1e-9)) < 0.03) // Eq. 3 / Eq. 4
    #expect(abs(v(.mars, 50) - v(.mars, 50 + 1e-9)) < 0.01) // Eq. 6 / Eq. 7
    #expect(abs(v(.jupiter, 12) - v(.jupiter, 12 + 1e-9)) < 0.01) // Eq. 8 / Eq. 9
    let g6 = try #require(PlanetaryMagnitude.saturnGlobeMagnitude(sunDistanceAU: 1, earthDistanceAU: 1, phaseAngleDeg: 6))
    let g6b = try #require(PlanetaryMagnitude.saturnGlobeMagnitude(sunDistanceAU: 1, earthDistanceAU: 1, phaseAngleDeg: 6 + 1e-9))
    #expect(abs(g6 - g6b) < 0.01) // Eq. 11 / Eq. 12
  }

  @Test
  func neptuneBrightensBetween1980And2000() {
    func v(_ year: Double) -> Double {
      PlanetaryMagnitude
        .visualMagnitude(of: .neptune, sunDistanceAU: 30, earthDistanceAU: 29, phaseAngleDeg: 1, year: year) ?? .nan
    }
    #expect(v(1970) == v(1900))
    #expect(v(1990) < v(1980))
    #expect(abs(v(2000) - v(2020)) < 0.01)
    #expect(abs((v(1980) - v(2000)) - 0.108) < 1e-9)
  }

  @Test
  func unsupportedBodiesHaveNoMagnitude() {
    for id in [BodyID.earth, .moon, .pluto] {
      #expect(PlanetaryMagnitude.visualMagnitude(of: id, sunDistanceAU: 1, earthDistanceAU: 1, phaseAngleDeg: 0) == nil)
    }
    // Uranus needs its latitudes.
    #expect(PlanetaryMagnitude.visualMagnitude(of: .uranus, sunDistanceAU: 19, earthDistanceAU: 18, phaseAngleDeg: 1) == nil)
    #expect(PlanetaryMagnitude.visualMagnitude(of: .mercury, sunDistanceAU: -1, earthDistanceAU: 1, phaseAngleDeg: 0) == nil)
  }
}

// MARK: - PhysicalConstantsTests

@Suite("Physical constants and API", .tags(.ephemeris, .unit))
struct PhysicalConstantsTests {
  /// pck00011.tpc `BODYnnn_RADII`, copied from the kernel.
  @Test
  func radiiMatchPck00011() throws {
    let expected: [(BodyID, Double, Double, Double)] = [
      (.sun, 695_700, 695_700, 695_700),
      (.mercury, 2440.53, 2440.53, 2438.26),
      (.venus, 6051.8, 6051.8, 6051.8),
      (.earth, 6378.1366, 6378.1366, 6356.7519),
      (.moon, 1737.4, 1737.4, 1737.4),
      (.mars, 3396.19, 3396.19, 3376.20),
      (.jupiter, 71_492, 71_492, 66_854),
      (.saturn, 60_268, 60_268, 54_364),
      (.uranus, 25_559, 25_559, 24_973),
      (.neptune, 24_764, 24_764, 24_341),
      (.pluto, 1188.3, 1188.3, 1188.3),
    ]
    #expect(expected.count == BodyID.allCases.count - BodyID.dwarfPlanets.count)
    for id in BodyID.dwarfPlanets { #expect(PhysicalConstants.radii(of: id) == nil, "\(id)") }
    for (id, a, b, c) in expected {
      let r = try #require(PhysicalConstants.radii(of: id))
      #expect(r.a == a && r.b == b && r.c == c, "\(id)")
    }
    #expect(abs(try #require(PhysicalConstants.radii(of: .saturn)).flattening - 0.098) < 0.001)
  }

  @Test
  func saturnPoleIsNearTheSaturnAxisTilt() throws {
    // The angle between Saturn's pole and the ecliptic pole is the axial tilt to the ecliptic, about 28 deg.
    let pole = try #require(PhysicalConstants.pole(of: .saturn)).eclipticDirection(centuries: 0)
    let tilt = acos(pole.z) * 180 / .pi
    #expect(abs(tilt - 28.05) < 0.1)
    #expect(abs(simd_length(pole) - 1) < 1e-12)
    #expect(PhysicalConstants.pole(of: .moon) == nil)
  }

  @Test
  func lightTimeAndDerivedQuantitiesAreConsistent() throws {
    let time = JulianDate(days: 2_461_359.0)
    let p = try #require(SolarSystem().physical(of: .saturn, at: time))
    #expect(abs(p.lightTimeMinutes - p.distanceAU * 8.3167) < 0.01) // 499.005 s per AU
    #expect(abs(p.illuminatedFraction - (1 + cos(p.phaseAngleDeg * .pi / 180)) / 2) < 1e-12)
    #expect(p.sunDistanceAU > 9 && p.sunDistanceAU < 10)
  }

  @Test
  func unsupportedRequestsReturnNil() {
    let system = SolarSystem()
    let time = JulianDate(days: 2_461_359.0)
    #expect(system.physical(of: .earth, at: time) == nil)
    #expect(system.physical(of: .pluto, at: time) == nil, "Pluto is not in the default system")
    #expect(SolarSystem(bodies: [Catalog.sun, Catalog.mars]).physical(of: .mars, at: time) == nil, "no Earth")
  }
}
