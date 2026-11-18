// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import simd
import Testing

/// The three Moon models against the geocentric Moon from the Horizons fixture (Moon 301 minus Earth 399), at all
/// five fixture epochs (the three main dates and the two eclipse epochs).
///
/// Measured errors (longitude / latitude / distance), as printed by `MOONACC` lines:
///
/// | Model         | Longitude        | Latitude        | Distance          |
/// | ------------- | ---------------- | --------------- | ----------------- |
/// | meanElements  | up to ~5300″     | up to ~430″     | up to ~1.4 %      |
/// | periodicTerms | up to ~370″      | up to ~430″     | up to ~1.4 %      |
/// | series        | up to ~39″       | up to ~63″      | up to ~0.006 %    |
///
/// The series tolerances below are two to three times the measured worst case and were chosen after measuring;
/// the mean-element tolerances are the spec's (3° / 1° / 6 %).
@Suite("Moon models vs JPL Horizons", .tags(.ephemeris, .lunar, .accuracy, .integration))
struct MoonModelAccuracyTests {

  // MARK: Internal

  static let epochs = Epoch.main + [Epoch.lunarFixture, Epoch.solarFixture]

  @Test(arguments: MoonModel.allCases)
  func moonMatchesHorizonsAtAllFixtureEpochs(model: MoonModel) throws {
    let fixture = try HorizonsFixture.load()
    for jd in Self.epochs {
      let ref = Spherical(try fixture.vector("moon", jd: jd) - fixture.vector("earth", jd: jd))
      let s = SolarSystem(moonModel: model).snapshot(at: JulianDate(days: jd))
      let m = Spherical(try #require(s.states[.moon]?.position) - s.states[.earth]!.position)
      let lon = abs(wrapPi(m.lon - ref.lon)) * arcsecPerRad
      let lat = abs(m.lat - ref.lat) * arcsecPerRad
      let dist = abs(m.r - ref.r) / ref.r
      print(
        "MOONACC \(model) JD \(jd): lon \(fmt(lon, 1))\" lat \(fmt(lat, 1))\" dist \(fmt(dist * 100, 4))% "
          + "[\(fmt(ref.r * Units.kmPerAU, 0)) km ref]"
      )
      let tol = Self.tolerance(for: model)
      #expect(lon <= tol.lonArcsec, "\(model) JD \(jd) lon \(lon)\"")
      #expect(lat <= tol.latArcsec, "\(model) JD \(jd) lat \(lat)\"")
      #expect(dist <= tol.distFraction, "\(model) JD \(jd) dist \(dist * 100)%")
    }
  }

  /// The series is clearly more accurate than Level B in longitude, latitude and distance at every epoch.
  @Test
  func seriesBeatsPeriodicTermsAtEveryEpoch() throws {
    let fixture = try HorizonsFixture.load()
    let elements = try #require(Catalog.moon.elements)
    for jd in Self.epochs {
      let ref = Spherical(try fixture.vector("moon", jd: jd) - fixture.vector("earth", jd: jd))
      let T = JulianDate(days: jd).centuriesSinceJ2000
      let b = Spherical(MoonEphemeris.geocentricPosition(elements: elements, T: T, periodicTerms: true))
      let s = Spherical(MoonEphemeris.geocentricPositionSeries(T: T))
      #expect(abs(wrapPi(s.lon - ref.lon)) < abs(wrapPi(b.lon - ref.lon)) / 3, "lon at JD \(jd)")
      #expect(abs(s.lat - ref.lat) < abs(b.lat - ref.lat), "lat at JD \(jd)")
      #expect(abs(s.r - ref.r) < abs(b.r - ref.r) / 100, "dist at JD \(jd)")
    }
  }

  @Test
  func seriesAtJulianDateMatchesSeriesAtCenturies() {
    let jd = JulianDate(days: Epoch.jd2026)
    #expect(
      MoonEphemeris.geocentricPositionSeries(at: jd)
        == MoonEphemeris.geocentricPositionSeries(T: jd.centuriesSinceJ2000)
    )
  }

  // MARK: Private

  private struct Tolerance {
    let lonArcsec: Double
    let latArcsec: Double
    let distFraction: Double
  }

  private static func tolerance(for model: MoonModel) -> Tolerance {
    switch model {
    case .meanElements, .periodicTerms:
      // The spec's Level A tolerance, also applied to Level B: 3 deg, 1 deg, 6 %.
      Tolerance(lonArcsec: 3 * 3600, latArcsec: 1 * 3600, distFraction: 0.06)
    case .series:
      Tolerance(lonArcsec: 90, latArcsec: 130, distFraction: 0.0002)
    }
  }
}
