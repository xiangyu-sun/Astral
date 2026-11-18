import Astral
import Foundation
import Testing

// MARK: - SVSLibrationFixture

/// Sampled rows of NASA SVS "Moon Phase and Libration" (2025 and 2026, hourly, geocentric, JPL DE421),
/// see Fixtures/make_svs_libration_fixture.py.
struct SVSLibrationFixture: Decodable {
  struct Row: Decodable {
    let utc: String
    let jd: Double
    let phasePercent: Double
    let ageDays: Double
    let distanceKm: Double
    let subSolarLon: Double
    let subSolarLat: Double
    let libLon: Double
    let libLat: Double
    let axisPA: Double
    let raHours: Double
    let decDeg: Double
  }

  let rows: [Row]

  static func load() throws -> SVSLibrationFixture {
    let url = try #require(
      Bundle.module.url(forResource: "svs_libration", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "svs_libration", withExtension: "json"),
      "svs_libration.json missing from test bundle"
    )
    return try JSONDecoder().decode(SVSLibrationFixture.self, from: Data(contentsOf: url))
  }
}

/// Difference `a - b` of two angles in degrees, wrapped to (-180, 180].
private func angleDifference(_ a: Double, _ b: Double) -> Double {
  var x = (a - b).truncatingRemainder(dividingBy: 360)
  if x > 180 { x -= 360 }
  if x <= -180 { x += 360 }
  return x
}

// MARK: - MoonLibrationTests

@Suite("Moon libration", .tags(.ephemeris, .lunar, .accuracy))
struct MoonLibrationTests {

  /// Meeus, Astronomical Algorithms, examples 47.a, 48.a and 53.a: 1992 April 12, 0h TD.
  @Test
  func meeusWorkedExample() {
    let libration = MoonLibration(
      at: JulianDate(days: 2_448_724.5),
      moonLongitude: 133.167265, // example 47.a, apparent
      moonLatitude: -3.229126,
      moonDistanceKm: 368_409.7,
      sunLongitude: 22.339773, // from example 48.a: α0 = 20.6579°, δ0 = +8.6964°
      sunDistanceAU: 149_971_520 / 149_597_870.7
    ) // R = 149 971 520 km

    // Optical libration: l' = -1.206°, b' = +4.194°.
    #expect(abs(libration.opticalLongitude - -1.206) < 0.001)
    #expect(abs(libration.opticalLatitude - 4.194) < 0.001)
    // Physical libration: l'' = -0.025°, b'' = +0.006°, hence l = -1.231°, b = +4.200°.
    #expect(abs(libration.physicalLongitude - -0.025) < 0.001)
    #expect(abs(libration.physicalLatitude - 0.006) < 0.001)
    #expect(abs(libration.longitude - -1.231) < 0.002)
    #expect(abs(libration.latitude - 4.200) < 0.002)
    // Position angle of the axis: P = 15.08°.
    #expect(abs(libration.positionAngleOfAxis - 15.08) < 0.01)
    // Illuminated fraction k = 0.6786 and position angle of the bright limb χ = 285.0°.
    #expect(abs(libration.illuminatedFraction - 0.6786) < 0.0001)
    #expect(abs(libration.brightLimbPositionAngle - 285.0) < 0.1)
    #expect(libration.distanceKm == 368_409.7)
  }

  /// Astral's own Moon and Sun against NASA's tables. The fixture times are UT and, like the rest of the ephemeris
  /// API, are used as TT (ΔT ≈ 69 s, worth ≈ 0.01° in libration).
  ///
  /// Measured maxima over the 92 sampled rows: libration longitude 0.014°, latitude 0.039°, sub-solar longitude
  /// 0.018°, sub-solar latitude 0.027°, axis position angle 0.014° (J2000), illuminated fraction 0.026 percentage
  /// points, distance 71 km.
  @Test
  func matchesNASASVSTable() throws {
    let rows = try SVSLibrationFixture.load().rows
    #expect(rows.count >= 50)

    var maxima = [String: Double]()
    func record(_ name: String, _ error: Double) {
      maxima[name] = max(maxima[name] ?? 0, abs(error))
    }

    for row in rows {
      let libration = MoonLibration(at: JulianDate(days: row.jd))
      record("libration longitude", angleDifference(libration.longitude, row.libLon))
      record("libration latitude", libration.latitude - row.libLat)
      record("sub-solar longitude", angleDifference(libration.subSolarLongitude, row.subSolarLon))
      record("sub-solar latitude", libration.subSolarLatitude - row.subSolarLat)
      record("axis position angle (J2000)", angleDifference(libration.positionAngleOfAxisJ2000, row.axisPA))
      record("illuminated fraction (percentage points)", libration.illuminatedFraction * 100 - row.phasePercent)
      record("distance (km)", libration.distanceKm - row.distanceKm)
    }

    // About twice the measured maxima.
    let tolerances: [String: Double] = [
      "libration longitude": 0.03,
      "libration latitude": 0.07,
      "sub-solar longitude": 0.035,
      "sub-solar latitude": 0.05,
      "axis position angle (J2000)": 0.03,
      "illuminated fraction (percentage points)": 0.05,
      "distance (km)": 150,
    ]
    for (name, tolerance) in tolerances {
      let worst = maxima[name] ?? .infinity
      #expect(worst < tolerance, "\(name): max error \(worst) exceeds \(tolerance)")
    }
  }

  /// The axis angle of date differs from the J2000 one by the precession of the pole (about 0.14°·sin α/cos δ now).
  @Test
  func axisAngleOfDateVersusJ2000() throws {
    let rows = try SVSLibrationFixture.load().rows
    for row in rows {
      let libration = MoonLibration(at: JulianDate(days: row.jd))
      let difference = angleDifference(libration.positionAngleOfAxis, libration.positionAngleOfAxisJ2000)
      #expect(abs(difference) < 0.2)
    }
    // At J2000 itself the two coincide.
    let atJ2000 = MoonLibration(at: .j2000)
    #expect(abs(angleDifference(atJ2000.positionAngleOfAxis, atJ2000.positionAngleOfAxisJ2000)) < 1e-9)
  }

  @Test
  func brightLimbPointsTowardsTheSun() throws {
    // The Moon is east of the Sun when waxing, so its bright limb faces west (PA 180...360); the opposite when
    // waning. Skip the thin phases, where the right-ascension difference is near 0 or 180°.
    for row in try SVSLibrationFixture.load().rows where row.phasePercent > 3 && row.phasePercent < 97 {
      let waxing = row.ageDays < 14.77
      let libration = MoonLibration(at: JulianDate(days: row.jd))
      let angle = libration.brightLimbPositionAngle
      #expect(waxing ? (angle > 180 && angle < 360) : (angle > 0 && angle < 180), "age \(row.ageDays), PA \(angle)")
    }
  }

  @Test
  func colongitudeIsNinetyMinusSubSolarLongitude() throws {
    for row in try SVSLibrationFixture.load().rows {
      let libration = MoonLibration(at: JulianDate(days: row.jd))
      let expected = 90 - libration.subSolarLongitude
      #expect(abs(angleDifference(libration.colongitude, expected)) < 1e-9)
      #expect(libration.colongitude >= 0 && libration.colongitude < 360)
    }
  }

  @Test
  func newAndFullMoon() {
    // 2026-08-12 total solar eclipse: new moon, subsolar point on the far side.
    let new = MoonLibration(at: JulianDate(days: Epoch.solarFixture))
    #expect(new.illuminatedFraction < 0.001)
    #expect(abs(angleDifference(new.subSolarLongitude, 180)) < 10)
    #expect(abs(new.colongitude - 270) < 10)

    // 2025-09-07 total lunar eclipse: full moon, subsolar point near the centre of the disc.
    let full = MoonLibration(at: JulianDate(days: Epoch.lunarFixture))
    #expect(full.illuminatedFraction > 0.999)
    #expect(abs(angleDifference(full.subSolarLongitude, full.longitude)) < 1)
    #expect(abs(full.colongitude - 90) < 10)
    #expect(full.elongation > 179)
  }

  @Test
  func dateInitialiserMatchesJulianDate() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(MoonLibration(date: date) == MoonLibration(at: JulianDate(date)))
  }

  @Test
  func librationStaysWithinPhysicalLimits() {
    // Libration never exceeds about ±8° in longitude and ±7° in latitude; scan two years.
    var maxLon = 0.0
    var maxLat = 0.0
    for step in 0..<1460 {
      let libration = MoonLibration(at: JulianDate(days: 2_460_676.5 + Double(step) * 0.5))
      maxLon = max(maxLon, abs(libration.longitude))
      maxLat = max(maxLat, abs(libration.latitude))
      #expect(libration.illuminatedFraction >= 0 && libration.illuminatedFraction <= 1)
      #expect(libration.positionAngleOfAxis >= 0 && libration.positionAngleOfAxis < 360)
      #expect(libration.brightLimbPositionAngle >= 0 && libration.brightLimbPositionAngle < 360)
    }
    #expect(maxLon > 6 && maxLon < 8.5)
    #expect(maxLat > 6 && maxLat < 7.5)
  }
}
