import Astral
import Foundation
import simd
import Testing

// MARK: - HorizonsFixture

/// JPL Horizons vectors (heliocentric, ecliptic J2000, AU), see Fixtures/make_fixture.py.
struct HorizonsFixture: Decodable {
  struct Row: Decodable {
    let jd: Double
    let date: String
    let x: Double
    let y: Double
    let z: Double

    var vector: SIMD3<Double> {
      SIMD3(x, y, z)
    }
  }

  let bodies: [String: [Row]]

  static func load() throws -> HorizonsFixture {
    let url = try #require(
      Bundle.module.url(forResource: "horizons", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "horizons", withExtension: "json"),
      "horizons.json missing from test bundle"
    )
    return try JSONDecoder().decode(HorizonsFixture.self, from: Data(contentsOf: url))
  }

  func vector(_ body: String, jd: Double) throws -> SIMD3<Double> {
    let rows = try #require(bodies[body], "no fixture rows for \(body)")
    let row = try #require(rows.first { $0.jd == jd }, "no fixture row for \(body) at JD \(jd)")
    return row.vector
  }
}

// MARK: - Epoch

enum Epoch {
  static let jd1900 = 2_415_021.0
  static let jd2000 = 2_451_545.0
  static let jd2026 = 2_461_359.0
  /// The three main fixture dates (12:00 on 1900-01-01, 2000-01-01, 2026-11-14).
  static let main = [jd1900, jd2000, jd2026]
  /// Fixture epoch of the 2025-09-07 total lunar eclipse.
  static let lunarFixture = 2_460_926.2583
  /// Fixture epoch of the 2026-08-12 total solar eclipse.
  static let solarFixture = 2_461_265.2403
}

// MARK: - Geometry helpers

let arcsecPerRad = 180.0 / .pi * 3600
let degPerRad = 180.0 / .pi

// MARK: - Spherical

struct Spherical {
  init(_ v: SIMD3<Double>) {
    r = simd_length(v)
    lon = atan2(v.y, v.x)
    lat = asin(v.z / r)
  }

  let lon: Double // radians, (-pi, pi]
  let lat: Double // radians
  let r: Double
}

func wrapPi(_ x: Double) -> Double {
  x.remainder(dividingBy: 2 * .pi)
}

/// Angle in degrees between two vectors.
func angleDeg(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
  let c = simd_dot(a, b) / (simd_length(a) * simd_length(b))
  return acos(max(-1, min(1, c))) * degPerRad
}

/// Angle Sun–Earth–Moon (degrees) at the vertex Earth, from heliocentric positions.
func sunEarthMoonAngleDeg(earth: SIMD3<Double>, moon: SIMD3<Double>) -> Double {
  angleDeg(-earth, moon - earth)
}

func utcDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
  var cal = Calendar(identifier: .gregorian)
  cal.timeZone = TimeZone(identifier: "UTC")!
  return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
}

func snapshot(_ jd: Double, moonTerms: Bool = true) -> SystemSnapshot {
  SolarSystem(bodies: Catalog.all, moonPeriodicTerms: moonTerms).snapshot(at: JulianDate(days: jd))
}

func snapshot(_ jd: Double, model: MoonModel) -> SystemSnapshot {
  SolarSystem(bodies: Catalog.all, moonModel: model).snapshot(at: JulianDate(days: jd))
}

func fmt(_ x: Double, _ digits: Int = 3) -> String {
  String(format: "%.\(digits)f", x)
}
