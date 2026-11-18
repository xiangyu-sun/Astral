// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import Testing

// MARK: - TransitFixture

struct TransitFixture: Decodable {
  struct Entry: Decodable, Sendable {
    let planet: String
    let date: String
    let I: String
    let II: String
    let greatest: String
    let III: String
    let IV: String
    let minimumSeparationArcsec: Double
  }

  let transits: [Entry]

  static func load() throws -> TransitFixture {
    try JSONDecoder().decode(TransitFixture.self, from: EclipseFixture.data("transits"))
  }
}

func transitKeys() -> [String] {
  (try? TransitFixture.load())?.transits.map { "\($0.planet) \($0.date)" } ?? []
}

// MARK: - PlanetaryTransitTests

@Suite("Transits of Mercury and Venus vs NASA GSFC", .tags(.accuracy, .integration))
struct PlanetaryTransitTests {

  // MARK: Internal

  @Test(arguments: transitKeys())
  func matchesNASA(key: String) throws {
    let fixture = try TransitFixture.load()
    let ref = try #require(fixture.transits.first { "\($0.planet) \($0.date)" == key })
    let planet = try #require(TransitPlanet(rawValue: ref.planet))
    let midnight = utcMidnight(ref.date)
    let greatestRef = try #require(Double(ref.greatest.prefix(2))) * 3600 + Double(ref.greatest.suffix(2))! * 60
    let window = midnight.addingTimeInterval(-86_400)...midnight.addingTimeInterval(2 * 86_400)
    let found = PlanetaryTransit.transits(of: planet, in: window)
    let transit = try #require(found.first, "no transit found")
    #expect(found.count == 1)

    func dt(_ c: LunarEclipseContact, _ hhmm: String) -> Double {
      c.date.timeIntervalSince(midnight) - seconds(hhmm, greatest: greatestRef)
    }
    let e = [
      dt(transit.contact1, ref.I),
      dt(transit.contact2, ref.II),
      dt(transit.greatest, ref.greatest),
      dt(transit.contact3, ref.III),
      dt(transit.contact4, ref.IV),
    ]
    let dSep = transit.minimumSeparationArcseconds - ref.minimumSeparationArcsec
    print(String(
      format: "TRANSIT %@: I %+.0fs II %+.0fs greatest %+.0fs III %+.0fs IV %+.0fs (NASA times to the minute, ±30 s); " +
        "dMinSep %+.1f\" duration %.0f min",
      key,
      e[0],
      e[1],
      e[2],
      e[3],
      e[4],
      dSep,
      transit.duration / 60
    ))
    // Honest tolerances from the measurements above: Mercury's worst contact error is 2.8 min (2032), Venus's 6.3 min
    // (2012). The Keplerian model is good to 15-20 arcsec, i.e. 3-6 minutes of transit motion (about 5 arcsec per
    // minute), plus the minute rounding of the catalogue.
    let tolerance = planet == .mercury ? 200.0 : 420.0
    for v in e { #expect(abs(v) < tolerance, "contact error \(v) s") }
    #expect(abs(dSep) < 25)
  }

  @Test
  func nextMercuryTransitAfter2019IsIn2032() throws {
    let after = utcMidnight("2019-12-01")
    let t = try #require(PlanetaryTransit.next(of: .mercury, after: after))
    #expect(Calendar(identifier: .gregorian).dateComponents(in: try #require(TimeZone(identifier: "UTC")), from: t.greatest.date)
      .year == 2032)
    #expect(t.contact1.date < t.contact2.date && t.contact2.date < t.greatest.date)
    #expect(t.greatest.date < t.contact3.date && t.contact3.date < t.contact4.date)
  }

  // MARK: Private

  /// Seconds after 00:00 UT of `date` for a catalogue time `hh:mm`, resolving the day around greatest transit.
  private func seconds(_ hhmm: String, greatest: Double) -> Double {
    let p = hhmm.split(separator: ":").map { Double($0)! }
    var s = p[0] * 3600 + p[1] * 60
    while s - greatest > 43_200 { s -= 86_400 }
    while greatest - s > 43_200 { s += 86_400 }
    return s
  }

}
