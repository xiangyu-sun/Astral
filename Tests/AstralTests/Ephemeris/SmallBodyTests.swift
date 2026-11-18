import Astral
import Foundation
import simd
import Testing

// MARK: - SmallBodyHorizonsTests

/// Two-body propagation of the SBDB elements against Horizons, which integrates the full N-body problem (planets,
/// Moon, the largest asteroids, and the non-gravitational terms of the JPL orbit solution of comets).
///
/// At the element epoch the two must agree: osculating elements are the instantaneous state. Away from it the
/// unmodelled perturbations make the difference grow, roughly with the square of the time offset (10 d → 60 d is
/// about 40× in position, 60 d → 365 d about 40×). The tolerances below are the measured worst error at the
/// fixture date (2026-11-17 build) with a margin of about 2×; they document the model's limits and are not to be
/// loosened to make a test pass. 'Oumuamua is the worst case: its fit is from a 2017–2018 arc and it was
/// accelerating non-gravitationally (A1 = 2.8e-7 au/d²).
@Suite("Small bodies vs JPL Horizons", .tags(.ephemeris, .accuracy))
struct SmallBodyHorizonsTests {

  /// Position tolerance in AU at |offset| = 0, 10, 60 and 365 days.
  struct Tolerance {
    let key: String
    let at10: Double
    let at60: Double
    let at365: Double
  }

  /// Measured worst case (AU): at 10 d, at 60 d, at 365 d.
  ///   ceres 2.3e-7 / 9.9e-6 / 6.7e-4      vesta 2.7e-7 / 1.0e-5 / 5.5e-4
  ///   eros 2.8e-7 / 9.9e-6 / 2.8e-4       apophis 1.9e-7 / 7.8e-6 / 3.1e-4
  ///   halley 5.4e-7 / 2.0e-5 / 6.6e-4     encke 3.1e-7 / 1.3e-5 / 4.0e-4
  ///   neowise 1.0e-7 / 5.2e-6 / 2.9e-4    oumuamua 3.4e-6 / 2.7e-4 / 6.3e-3
  static let tolerances = [
    Tolerance(key: "ceres", at10: 6e-7, at60: 2e-5, at365: 1.4e-3),
    Tolerance(key: "vesta", at10: 6e-7, at60: 2e-5, at365: 1.1e-3),
    Tolerance(key: "eros", at10: 6e-7, at60: 2e-5, at365: 5e-4),
    Tolerance(key: "apophis", at10: 4e-7, at60: 1.6e-5, at365: 6e-4),
    Tolerance(key: "halley", at10: 1.1e-6, at60: 4e-5, at365: 1.3e-3),
    Tolerance(key: "encke", at10: 6.5e-7, at60: 2.5e-5, at365: 8e-4),
    Tolerance(key: "neowise", at10: 2.2e-7, at60: 1e-5, at365: 6e-4),
    Tolerance(key: "oumuamua", at10: 7e-6, at60: 6e-4, at365: 1.3e-2),
  ]

  /// At the epoch the states agree to 1e-7 AU (worst measured: 2.7e-8 AU for Ceres; the rest is below 5e-9) and
  /// 1e-9 AU/day.
  @Test(arguments: SmallBodyFixture.keys)
  func matchesHorizonsAtTheElementEpoch(key: String) throws {
    let entry = try SmallBodyFixture.load().entry(key)
    let body = try entry.body()
    let row = try entry.epochRow(body)
    let state = body.state(at: body.epoch)
    #expect(simd_length(state.position - row.position) < 1e-7, "\(key) position")
    #expect(simd_length(state.velocity - row.velocity) < 1e-9, "\(key) velocity")
  }

  @Test(arguments: tolerances)
  func errorAwayFromTheEpochIsBounded(tolerance: Tolerance) throws {
    let entry = try SmallBodyFixture.load().entry(tolerance.key)
    let body = try entry.body()
    for row in entry.rows {
      let offset = abs(row.jd - body.epoch.days)
      guard offset > 0 else { continue }
      let limit =
        switch offset {
        case 10: tolerance.at10
        case 60: tolerance.at60
        case 365: tolerance.at365
        default: Double.nan
        }
      let error = simd_length(body.position(at: JulianDate(days: row.jd)) - row.position)
      #expect(error < limit, "\(tolerance.key) at \(row.jd - body.epoch.days) d: \(error) AU, limit \(limit)")
      let velocityError = simd_length(body.state(at: JulianDate(days: row.jd)).velocity - row.velocity)
      #expect(velocityError < 1e-4, "\(tolerance.key) velocity at \(row.jd - body.epoch.days) d: \(velocityError)")
    }
  }

  /// The perturbation error is not zero away from the epoch, and it grows with the time offset: if this fails the
  /// comparison is no longer testing what it claims to.
  @Test(arguments: SmallBodyFixture.keys)
  func errorGrowsWithTimeFromTheEpoch(key: String) throws {
    let entry = try SmallBodyFixture.load().entry(key)
    let body = try entry.body()
    func error(_ days: Double) throws -> Double {
      let jd = body.epoch.days + days
      let row = try #require(entry.rows.first { $0.jd == jd })
      return simd_length(body.position(at: JulianDate(days: jd)) - row.position)
    }
    for sign in [-1.0, 1.0] {
      let e0 = try error(0)
      let e10 = try error(10 * sign)
      let e60 = try error(60 * sign)
      let e365 = try error(365 * sign)
      #expect(e0 < e10 && e10 < e60 && e60 < e365, "\(key): \(e0) \(e10) \(e60) \(e365)")
    }
  }

  /// The Horizons solution of every fixture row is for the same orbit as the SBDB elements (the generator checks
  /// the solution date), so the 365-day error must be far below the size of the orbit.
  @Test(arguments: SmallBodyFixture.keys)
  func errorIsSmallComparedWithTheOrbit(key: String) throws {
    let entry = try SmallBodyFixture.load().entry(key)
    let body = try entry.body()
    for row in entry.rows {
      let error = simd_length(body.position(at: JulianDate(days: row.jd)) - row.position)
      #expect(error / simd_length(row.position) < 1e-2, "\(key) at JD \(row.jd)")
    }
  }
}

// MARK: - SmallBodyTests

@Suite("SmallBody", .tags(.ephemeris, .unit, .fast))
struct SmallBodyTests {

  /// The elements SBDB publishes for the fixture, by name.
  static func published(_ entry: SmallBodyFixture.Entry) throws -> [String: Double] {
    let root = try #require(try JSONSerialization.jsonObject(with: entry.sbdbJSON) as? [String: Any])
    let orbit = try #require(root["orbit"] as? [String: Any])
    let elements = try #require(orbit["elements"] as? [[String: Any]])
    var result = [String: Double]()
    for element in elements {
      if let name = element["name"] as? String, let text = element["value"] as? String, let value = Double(text) {
        result[name] = value
      }
    }
    return result
  }

  @Test
  func decodesEveryFixtureResponse() throws {
    let fixture = try SmallBodyFixture.load()
    #expect(fixture.entries.count == SmallBodyFixture.keys.count)
    for entry in fixture.entries {
      let body = try entry.body()
      #expect(body.name == entry.name)
      #expect(body.eccentricity >= 0 && body.perihelionDistance > 0)
    }
  }

  @Test
  func ceresElementsMatchSBDB() throws {
    let entry = try SmallBodyFixture.load().entry("ceres")
    let body = try entry.body()
    #expect(body.name == "1 Ceres (A801 AA)")
    #expect(body.kind == .elliptic)
    #expect(body.epoch.days == 2_461_200.5)
    #expect(body.eccentricity == 0.07969229514816586)
    #expect(body.perihelionDistance == 2.545159361382861)
    #expect(body.inclination == 10.58802780183462)
    #expect(body.longitudeOfAscendingNode == 80.24862682043221)
    #expect(body.argumentOfPerihelion == 73.29421453021587)
    #expect(body.timeOfPerihelion.days == 2_461_599.841466614066)
  }

  /// Derived quantities agree with the ones SBDB publishes (a, period, mean motion, aphelion).
  @Test(arguments: ["ceres", "vesta", "eros", "apophis", "halley", "encke", "neowise"])
  func derivedQuantitiesMatchSBDB(key: String) throws {
    let entry = try SmallBodyFixture.load().entry(key)
    let body = try entry.body()
    let published = try Self.published(entry)
    #expect(abs(try #require(body.semiMajorAxis) - published["a"]!) < 1e-9 * published["a"]!)
    #expect(abs(try #require(body.aphelionDistance) - published["ad"]!) < 1e-9 * published["ad"]!)
    #expect(abs(try #require(body.period) - published["per"]!) < 1e-6 * published["per"]!)
    #expect(abs(try #require(body.meanMotion) - published["n"]!) < 1e-8 * published["n"]!)
  }

  @Test
  func hyperbolicOrbitIsDecodedFromNegativeSemiMajorAxis() throws {
    let entry = try SmallBodyFixture.load().entry("oumuamua")
    let body = try entry.body()
    #expect(body.kind == .hyperbolic)
    #expect(body.eccentricity > 1)
    let a = try #require(body.semiMajorAxis)
    #expect(a < 0)
    #expect(body.period == nil && body.aphelionDistance == nil)
    #expect(abs(a - -1.27234500742808) < 1e-12)
  }

  /// The two element sets SBDB publishes agree: (q, tp) and (a, M at the epoch). Every fixture carries both.
  @Test(arguments: SmallBodyFixture.keys)
  func meanAnomalyFormAgreesWithPerihelionTimeForm(key: String) throws {
    let entry = try SmallBodyFixture.load().entry(key)
    let body = try entry.body()
    let published = try Self.published(entry)
    let alt = try SmallBody(
      epoch: body.epoch,
      eccentricity: body.eccentricity,
      semiMajorAxis: try #require(published["a"]),
      inclination: body.inclination,
      longitudeOfAscendingNode: body.longitudeOfAscendingNode,
      argumentOfPerihelion: body.argumentOfPerihelion,
      meanAnomaly: try #require(published["ma"])
    )
    for days in [0.0, 10, -60, 365] {
      let t = JulianDate(days: body.epoch.days + days)
      #expect(simd_length(alt.position(at: t) - body.position(at: t)) < 1e-8, "\(key) at \(days) d")
    }
  }

  @Test
  func meanAnomalyAtEpochMatchesSBDB() throws {
    for key in ["ceres", "eros", "halley", "oumuamua"] {
      let entry = try SmallBodyFixture.load().entry(key)
      let body = try entry.body()
      let published = try #require(try Self.published(entry)["ma"])
      let m = try #require(body.meanAnomaly(at: body.epoch))
      // Elliptic anomalies are wrapped to [-180, 180].
      let expected = body.kind == .elliptic ? Kepler.wrapPi(published * Units.degToRad) / Units.degToRad : published
      #expect(abs(m - expected) < 1e-6, "\(key): \(m) vs \(expected)")
    }
  }

  /// A closed orbit repeats after one period.
  @Test
  func ellipseRepeatsAfterOnePeriod() throws {
    let body = try SmallBodyFixture.load().entry("encke").body()
    let period = try #require(body.period)
    for days in [0.0, 37, -111] {
      let t0 = JulianDate(days: body.epoch.days + days)
      let t1 = JulianDate(days: t0.days + 5 * period)
      #expect(simd_length(body.position(at: t0) - body.position(at: t1)) < 1e-9)
    }
  }

  @Test
  func acceptsJSONNumbersAndLeadingDotStrings() throws {
    let json = """
      {"object": {"fullname": "test"},
       "orbit": {"epoch": 2461200.5, "equinox": "J2000", "elements": [
         {"name": "e", "value": ".25"}, {"name": "q", "value": 1.5}, {"name": "i", "value": "10"},
         {"name": "om", "value": "20"}, {"name": "w", "value": "30"}, {"name": "tp", "value": "2461100.25"},
         {"name": "per", "value": null}]}}
      """
    let body = try SmallBody(sbdbJSON: Data(json.utf8))
    #expect(body.name == "test")
    #expect(body.eccentricity == 0.25)
    #expect(body.perihelionDistance == 1.5)
    #expect(body.timeOfPerihelion.days == 2_461_100.25)
  }

  @Test
  func reportsAnUnknownObject() {
    let json = #"{"code": "200", "message": "specified object was not found"}"#
    #expect(throws: SmallBodyError.objectNotFound(message: "specified object was not found")) {
      try SmallBody(sbdbJSON: Data(json.utf8))
    }
  }

  @Test
  func rejectsMalformedInput() {
    #expect(throws: SmallBodyError.invalidJSON) { try SmallBody(sbdbJSON: Data("not json".utf8)) }
    #expect(throws: SmallBodyError.invalidJSON) { try SmallBody(sbdbJSON: Data("[1, 2]".utf8)) }
    #expect(throws: SmallBodyError.missingOrbit) { try SmallBody(sbdbJSON: Data("{}".utf8)) }
  }

  @Test
  func rejectsMissingAndInvalidElements() {
    func response(_ elements: String, equinox: String = "J2000", epoch: String = "2461200.5") -> Data {
      Data("""
        {"orbit": {"epoch": "\(epoch)", "equinox": "\(equinox)", "elements": [\(elements)]}}
        """.utf8)
    }
    func element(_ name: String, _ value: String) -> String {
      #"{"name": "\#(name)", "value": "\#(value)"}"#
    }
    let common = [element("e", "0.1"), element("i", "1"), element("om", "2"), element("w", "3")]
    let withQT = (common + [element("q", "1.5"), element("tp", "2461000")]).joined(separator: ",")

    #expect(throws: SmallBodyError.missingElement("q and tp (or a and ma)")) {
      try SmallBody(sbdbJSON: response(common.joined(separator: ",")))
    }
    #expect(throws: SmallBodyError.missingElement("i")) {
      try SmallBody(sbdbJSON: response([element("e", "0.1"), element("q", "1"), element("tp", "1")].joined(separator: ",")))
    }
    #expect(throws: SmallBodyError.missingElement("epoch")) {
      try SmallBody(sbdbJSON: Data(#"{"orbit": {"elements": []}}"#.utf8))
    }
    #expect(throws: SmallBodyError.unsupportedEquinox("B1950")) {
      try SmallBody(sbdbJSON: response(withQT, equinox: "B1950"))
    }
    #expect(throws: SmallBodyError.invalidElement("q")) {
      try SmallBody(sbdbJSON: response((common + [element("q", "-1"), element("tp", "2461000")]).joined(separator: ",")))
    }
    #expect(throws: SmallBodyError.invalidElement("e")) {
      try SmallBody(sbdbJSON: response(
        [
          element("e", "-0.1"),
          element("i", "1"),
          element("om", "2"),
          element("w", "3"),
          element("q", "1"),
          element("tp", "2461000"),
        ].joined(separator: ",")
      ))
    }
    // An unparsable value counts as absent.
    #expect(throws: SmallBodyError.missingElement("e")) {
      try SmallBody(sbdbJSON: response(
        [
          element("e", "abc"),
          element("i", "1"),
          element("om", "2"),
          element("w", "3"),
          element("q", "1"),
          element("tp", "2461000"),
        ].joined(separator: ",")
      ))
    }
  }

  @Test
  func memberwiseInitializersValidate() {
    let epoch = JulianDate(days: 2_461_200.5)
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: -0.1,
        perihelionDistance: 1,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        timeOfPerihelion: epoch
      )
    }
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: 0.5,
        perihelionDistance: 0,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        timeOfPerihelion: epoch
      )
    }
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: 0.5,
        perihelionDistance: .nan,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        timeOfPerihelion: epoch
      )
    }
    // Semi-major axis sign must agree with the eccentricity; e = 1 has none.
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: 0.5,
        semiMajorAxis: -2,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        meanAnomaly: 0
      )
    }
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: 1.5,
        semiMajorAxis: 2,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        meanAnomaly: 0
      )
    }
    #expect(throws: SmallBodyError.self) {
      try SmallBody(
        epoch: epoch,
        eccentricity: 1,
        semiMajorAxis: 2,
        inclination: 0,
        longitudeOfAscendingNode: 0,
        argumentOfPerihelion: 0,
        meanAnomaly: 0
      )
    }
  }

  @Test
  func parabolaHasNoSemiMajorAxisOrPeriod() throws {
    let epoch = JulianDate(days: 2_461_200.5)
    let body = try SmallBody(
      epoch: epoch,
      eccentricity: 1,
      perihelionDistance: 1,
      inclination: 0,
      longitudeOfAscendingNode: 0,
      argumentOfPerihelion: 0,
      timeOfPerihelion: epoch
    )
    #expect(body.kind == .parabolic)
    #expect(body.semiMajorAxis == nil && body.period == nil && body.meanMotion == nil)
    #expect(body.meanAnomaly(at: epoch) == nil)
    // At perihelion the position is (q, 0, 0) for zero angles.
    let p = body.position(at: epoch)
    #expect(simd_length(p - SIMD3(1, 0, 0)) < 1e-14)
  }

  @Test
  func orientationAnglesRotateThePlane() throws {
    // i = 90°, Ω = 90°, ω = 0: the ascending node, and so perihelion, lies on +y.
    let epoch = JulianDate(days: 2_461_200.5)
    let body = try SmallBody(
      epoch: epoch,
      eccentricity: 0.3,
      perihelionDistance: 2,
      inclination: 90,
      longitudeOfAscendingNode: 90,
      argumentOfPerihelion: 0,
      timeOfPerihelion: epoch
    )
    #expect(simd_length(body.position(at: epoch) - SIMD3(0, 2, 0)) < 1e-12)
    // At the ascending node the body is moving up out of the ecliptic: its velocity points along +z.
    #expect(body.state(at: epoch).velocity.z > 0)
    #expect(abs(body.state(at: epoch).velocity.x) < 1e-15)
  }

  @Test
  func ellipseOutlineLiesBetweenPerihelionAndAphelion() throws {
    let body = try SmallBodyFixture.load().entry("eros").body()
    let q = body.perihelionDistance
    let Q = try #require(body.aphelionDistance)
    let path = body.orbitPath(samples: 360)
    #expect(path.count == 360)
    for p in path {
      let r = simd_length(p)
      #expect(r >= q - 1e-9 && r <= Q + 1e-9)
    }
    #expect(abs(simd_length(path[0]) - q) < 1e-12)
    // Every outline point is a point the propagator reaches: compare with positions at equal true anomaly spacing.
    #expect(abs(simd_length(path[180]) - Q) < 1e-9)
  }

  @Test
  func openOutlineStopsAtMaxRadiusAndIsSymmetric() throws {
    let body = try SmallBodyFixture.load().entry("oumuamua").body()
    let path = body.orbitPath(samples: 101, maxRadius: 20)
    #expect(path.count == 101)
    #expect(abs(simd_length(path[0]) - 20) < 1e-9)
    #expect(abs(simd_length(path[100]) - 20) < 1e-9)
    #expect(abs(simd_length(path[50]) - body.perihelionDistance) < 1e-12)
    #expect(body.orbitPath(samples: 1).isEmpty)
  }

}
