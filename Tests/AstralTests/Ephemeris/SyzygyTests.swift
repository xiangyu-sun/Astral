import Foundation
import Testing
import simd
import Astral

// Eclipse times in the architecture doc are "recalled". They are checked here against the
// Horizons fixture geometry (Sun-Earth-Moon angle from bodies 399 and 301 at the fixture epoch).

private func modelAngle(_ jd: Double, moonTerms: Bool) -> Double {
  let s = snapshot(jd, moonTerms: moonTerms)
  return sunEarthMoonAngleDeg(earth: s.states[.earth]!.position, moon: s.states[.moon]!.position)
}

private func horizonsAngle(_ jd: Double) throws -> Double {
  let f = try HorizonsFixture.load()
  return sunEarthMoonAngleDeg(earth: try f.vector("earth", jd: jd), moon: try f.vector("moon", jd: jd))
}

@Suite("Syzygy sanity", .tags(.ephemeris, .lunar, .integration))
struct SyzygyTests {
  @Test func horizonsConfirmsSolarEclipseGeometry() throws {
    let a = try horizonsAngle(Epoch.solarFixture)
    print("SYZYGY Horizons Sun-Earth-Moon @ solar fixture: \(fmt(a)) deg")
    #expect(a < 3)
  }

  @Test func horizonsConfirmsLunarEclipseGeometry() throws {
    let a = try horizonsAngle(Epoch.lunarFixture)
    print("SYZYGY Horizons Sun-Earth-Moon @ lunar fixture: \(fmt(a)) deg")
    #expect(a > 177)
  }

  @Test(arguments: [false, true])
  func solarEclipseAngleBelow3Degrees(moonTerms: Bool) {
    let a = modelAngle(Epoch.solarFixture, moonTerms: moonTerms)
    print("SYZYGY model solar eclipse 2026-08-12 17:46 (level \(moonTerms ? "B" : "A")): \(fmt(a)) deg")
    #expect(a < 3, "Sun-Earth-Moon \(a) deg")
  }

  @Test(arguments: [false, true])
  func lunarEclipseAngleAbove177Degrees(moonTerms: Bool) {
    let jd = JulianDate(utcDate(2025, 9, 7, 18, 12)).days
    let a = modelAngle(jd, moonTerms: moonTerms)
    print("SYZYGY model lunar eclipse 2025-09-07 18:12 (level \(moonTerms ? "B" : "A")), JD \(jd): \(fmt(a)) deg")
    #expect(a > 177, "Sun-Earth-Moon \(a) deg")
  }

  @Test(arguments: [false, true])
  func modelAgreesWithHorizonsGeometryAtFixtureEpochs(moonTerms: Bool) throws {
    for jd in [Epoch.solarFixture, Epoch.lunarFixture] {
      let model = modelAngle(jd, moonTerms: moonTerms)
      let ref = try horizonsAngle(jd)
      print("SYZYGY angle @JD \(jd) level \(moonTerms ? "B" : "A"): model \(fmt(model)) vs Horizons \(fmt(ref)) deg")
      #expect(abs(model - ref) <= 3, "model \(model) vs Horizons \(ref)")
    }
  }
}
