import Foundation
import Testing
import simd
import Astral

// MARK: - Fixture

/// JPL Horizons OBSERVER-table quantities, see Fixtures/make_physical_fixture.py.
struct PhysicalFixture: Decodable {
  struct Row: Decodable {
    let jd: Double
    let apmag: Double?
    let illuPercent: Double
    let angDiamArcsec: Double
    let rangeAU: Double
    let elongationDeg: Double
    let phaseDeg: Double
    let obsSubLatDeg: Double?
    let sunSubLatDeg: Double?
  }

  let bodies: [String: [Row]]

  static func load() throws -> PhysicalFixture {
    let url = try #require(
      Bundle.module.url(forResource: "physical", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "physical", withExtension: "json"),
      "physical.json missing from test bundle")
    return try JSONDecoder().decode(PhysicalFixture.self, from: Data(contentsOf: url))
  }

  func rows(_ body: String) throws -> [Row] {
    try #require(bodies[body], "no fixture rows for \(body)")
  }
}

/// The planets covered by the Horizons comparison, with their fixture key and honest tolerances.
///
/// The tolerances come from measuring this model against Horizons (see the printed `PHYSICAL` lines) and rounding up
/// a little. They reflect the Keplerian element positions: the giant planets are limited by the 20-600" longitude
/// error of the JPL element tables, and the Moon by the mean-element lunar model.
struct PhysicalTolerance: Sendable, CustomTestStringConvertible {
  let id: BodyID
  let key: String
  /// Relative error of the distance.
  let distance: Double
  /// Relative error of the angular diameter (same as the distance, apart from light-time and asin).
  let diameter: Double
  let phaseDeg: Double
  let elongationDeg: Double
  let illuminated: Double
  /// Magnitude error. `nil` when the magnitude is not modelled (Moon, Pluto).
  let magnitude: Double?
  var testDescription: String { id.displayName }
}

private let physicalTable: [PhysicalTolerance] = [
  // distance, diameter, phase, elongation, illuminated fraction, magnitude
  .init(id: .mercury, key: "mercury", distance: 0.0002, diameter: 0.0002, phaseDeg: 0.02, elongationDeg: 0.02, illuminated: 0.0005, magnitude: 0.005),
  .init(id: .venus, key: "venus", distance: 0.0003, diameter: 0.0003, phaseDeg: 0.02, elongationDeg: 0.02, illuminated: 0.0005, magnitude: 0.005),
  // Mars: the magnitude omits the two surface-feature corrections of the paper (up to 0.06 mag, see PlanetaryMagnitude).
  .init(id: .mars, key: "mars", distance: 0.001, diameter: 0.001, phaseDeg: 0.03, elongationDeg: 0.03, illuminated: 0.0005, magnitude: 0.1),
  .init(id: .jupiter, key: "jupiter", distance: 0.002, diameter: 0.002, phaseDeg: 0.03, elongationDeg: 0.15, illuminated: 0.0005, magnitude: 0.01),
  .init(id: .saturn, key: "saturn", distance: 0.0035, diameter: 0.0035, phaseDeg: 0.04, elongationDeg: 0.3, illuminated: 0.0005, magnitude: 0.02),
  .init(id: .uranus, key: "uranus", distance: 0.001, diameter: 0.001, phaseDeg: 0.02, elongationDeg: 0.08, illuminated: 0.0005, magnitude: 0.01),
  .init(id: .neptune, key: "neptune", distance: 0.0006, diameter: 0.0006, phaseDeg: 0.02, elongationDeg: 0.05, illuminated: 0.0005, magnitude: 0.01),
]

@Suite("Fixture: physical quantities vs JPL Horizons", .tags(.ephemeris, .accuracy, .integration))
struct PhysicalFixtureTests {
  @Test(arguments: physicalTable)
  func planetMatchesHorizons(entry: PhysicalTolerance) throws {
    let fixture = try PhysicalFixture.load()
    let system = SolarSystem()
    var worst = (distance: 0.0, diameter: 0.0, phase: 0.0, elongation: 0.0, illuminated: 0.0, magnitude: 0.0)
    for row in try fixture.rows(entry.key) {
      let p = try #require(system.physical(of: entry.id, at: JulianDate(days: row.jd)))
      let dDist = abs(p.distanceAU - row.rangeAU) / row.rangeAU
      let dDiam = abs(p.angularDiameterArcsec - row.angDiamArcsec) / row.angDiamArcsec
      let dPhase = abs(p.phaseAngleDeg - row.phaseDeg)
      let dElong = abs(p.elongationDeg - row.elongationDeg)
      let dIllu = abs(p.illuminatedFraction - row.illuPercent / 100)
      worst.distance = max(worst.distance, dDist)
      worst.diameter = max(worst.diameter, dDiam)
      worst.phase = max(worst.phase, dPhase)
      worst.elongation = max(worst.elongation, dElong)
      worst.illuminated = max(worst.illuminated, dIllu)
      #expect(dDist <= entry.distance, "\(entry.id) JD \(row.jd) distance \(dDist)")
      #expect(dDiam <= entry.diameter, "\(entry.id) JD \(row.jd) diameter \(dDiam)")
      #expect(dPhase <= entry.phaseDeg, "\(entry.id) JD \(row.jd) phase \(dPhase) deg")
      #expect(dElong <= entry.elongationDeg, "\(entry.id) JD \(row.jd) elongation \(dElong) deg")
      #expect(dIllu <= entry.illuminated, "\(entry.id) JD \(row.jd) illuminated fraction \(dIllu)")
      if let tol = entry.magnitude, let ref = row.apmag {
        let m = try #require(p.visualMagnitude)
        worst.magnitude = max(worst.magnitude, abs(m - ref))
        #expect(abs(m - ref) <= tol, "\(entry.id) JD \(row.jd) magnitude \(m) vs \(ref)")
      }
    }
    print("PHYSICAL \(entry.id.displayName): worst distance \(fmt(worst.distance * 100, 3))%, diameter \(fmt(worst.diameter * 100, 3))%, "
      + "phase \(fmt(worst.phase, 3)) deg, elongation \(fmt(worst.elongation, 3)) deg, illuminated \(fmt(worst.illuminated, 4)), "
      + "magnitude \(fmt(worst.magnitude, 3))")
  }
}
