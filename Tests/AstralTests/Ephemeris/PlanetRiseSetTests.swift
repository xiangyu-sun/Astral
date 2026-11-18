// swiftlint:disable no_direct_standard_out_logs
import Foundation
import Testing
@testable import Astral

// MARK: - RTSFixture

// Planet rise / transit / set and az/el against JPL Horizons (Fixtures/horizons_rts.json, regenerate with
// Fixtures/make_rts_fixture.py). Tests run offline.
//
// Reference definitions (see the fixture's "definition" key):
//  - `events`: crossings of JPL's refracted elevation = 0 (level horizon, no dip) and of local apparent hour
//    angle = 0, interpolated from a 1 minute table (about 1 s resolution). Astral is run on the same site with
//    the elevation forced to 0, so only the geometry and the refraction model are tested.
//  - `jplFlags`: JPL's own R_T_S_ONLY flags, 1 minute step, which include the dip of the site altitude. Astral,
//    run on the real Observer (elevation included), must fall within JPL's documented "twice the step" of them.
//  - `samples`: airless and refracted apparent azimuth/elevation every 4 hours.
//
// Tolerances are per body: the fixture tests of the underlying elements allow up to 600" (Saturn) of heliocentric
// longitude error, which is about 0.17° or 40 s of rise time; see `bodyTolerances`.

struct RTSFixture: Decodable {
  struct Site: Decodable {
    let lat: Double
    let lon: Double
    let elevation_m: Double
  }

  struct Events: Decodable {
    let rise: [Double]
    let transit: [Double]
    let set: [Double]
  }

  struct Sample: Decodable {
    let t: Double
    let airlessAz: Double
    let airlessEl: Double
    let refractedAz: Double
    let refractedEl: Double
  }

  struct Case: Decodable, CustomTestStringConvertible {
    let body: String
    let observer: String
    let date: String
    let events: Events
    let jplFlags: Events
    let samples: [Sample]

    var testDescription: String {
      "\(body) \(observer) \(date)"
    }

    var bodyID: BodyID {
      BodyID(rawValue: body)!
    }

    var midnight: Date {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withFullDate]
      formatter.timeZone = .utc
      return formatter.date(from: date)!
    }

    var dateComponents: DateComponents {
      let parts = date.split(separator: "-").map { Int($0)! }
      return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }
  }

  let observers: [String: Site]
  let cases: [Case]

  static func load() throws -> RTSFixture {
    let url = try #require(
      Bundle.module.url(forResource: "horizons_rts", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "horizons_rts", withExtension: "json"),
      "horizons_rts.json missing from test bundle"
    )
    return try JSONDecoder().decode(RTSFixture.self, from: Data(contentsOf: url))
  }

  func observer(_ key: String, levelHorizon: Bool) -> Observer {
    let site = observers[key]!
    return Observer(
      latitude: site.lat,
      longitude: site.lon,
      elevation: .double(levelHorizon ? 0 : site.elevation_m)
    )
  }
}

// MARK: - BodyTolerance

struct BodyTolerance: Sendable {
  /// Rise / set / transit versus the level-horizon reference, seconds.
  let eventSeconds: Double
  /// Angular separation of az/el (airless and refracted), degrees.
  let positionDegrees: Double
}

/// Measured with `swift test --filter PlanetRiseSet` (max errors are printed), rounded up with a small margin.
///
/// Mercury, Venus, Mars: 0.006° and 4 s at most. Uranus, Neptune and (unverified) Pluto: about 0.01-0.02° and
/// under 10 s. Jupiter (0.098°, 32 s) and Saturn (0.158°, 57 s) are limited by the published JPL element tables
/// themselves (nominal heliocentric longitude errors of 400" and 600", see HorizonsFixtureTests): the Catalog
/// constants are not adjusted, so the tolerance is honest rather than the 0.05° target. All bodies meet the
/// 2 minute target for rise, transit and set.
let bodyTolerances: [BodyID: BodyTolerance] = [
  .mercury: .init(eventSeconds: 10, positionDegrees: 0.01),
  .venus: .init(eventSeconds: 10, positionDegrees: 0.01),
  .mars: .init(eventSeconds: 10, positionDegrees: 0.01),
  .jupiter: .init(eventSeconds: 40, positionDegrees: 0.11),
  .saturn: .init(eventSeconds: 65, positionDegrees: 0.18),
  .uranus: .init(eventSeconds: 15, positionDegrees: 0.025),
  .neptune: .init(eventSeconds: 12, positionDegrees: 0.02),
  .pluto: .init(eventSeconds: 15, positionDegrees: 0.02),
]

// MARK: - Helpers

private func seconds(_ components: DateComponents, since midnight: Date) -> Double {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = components.timeZone ?? .utc
  return calendar.date(from: components)!.timeIntervalSince(midnight)
}

private func unitVector(az: Double, el: Double) -> SIMD3<Double> {
  let a = az * .pi / 180
  let e = el * .pi / 180
  return SIMD3(cos(e) * sin(a), cos(e) * cos(a), sin(e))
}

/// Angle between two (az, el) directions, degrees.
private func separation(az1: Double, el1: Double, az2: Double, el2: Double) -> Double {
  let a = unitVector(az: az1, el: el1)
  let b = unitVector(az: az2, el: el2)
  let cross = SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
  let crossLength = (cross.x * cross.x + cross.y * cross.y + cross.z * cross.z).squareRoot()
  return atan2(crossLength, a.x * b.x + a.y * b.y + a.z * b.z) * 180 / .pi
}

// MARK: - PlanetRiseSetFixtureTests

@Suite("Planet rise/transit/set vs JPL Horizons", .tags(.ephemeris, .accuracy, .transit, .integration))
struct PlanetRiseSetFixtureTests {

  @Test("Fixture observers are the predefined Observers")
  func fixtureObserversMatch() throws {
    let fixture = try RTSFixture.load()
    let predefined: [String: Observer] = ["london": .london, "riyadh": .riyadh]
    for (key, observer) in predefined {
      let site = try #require(fixture.observers[key])
      #expect(abs(site.lat - observer.latitude) < 1e-9, "\(key) latitude")
      #expect(abs(site.lon - observer.longitude) < 1e-9, "\(key) longitude")
      let elevation: Double =
        switch observer.elevation {
        case .double(let metres): metres
        case .tuple(let metres, _): metres
        }
      #expect(abs(site.elevation_m - elevation) < 1e-9, "\(key) elevation")
    }

    // Wellington: the fixture has the intended coordinates (41°17'11.256" S, 174°46'34.4496" E, 13 m).
    let wellington = try #require(fixture.observers["wellington"])
    #expect(abs(wellington.lat - -(41 + 17.0 / 60 + 11.256 / 3600)) < 1e-9)
    #expect(abs(wellington.lon - (174 + 46.0 / 60 + 34.4496 / 3600)) < 1e-9)
    #expect(wellington.elevation_m == 13)
    #expect(abs(Observer.wellington.latitude - wellington.lat) < 1e-4)
    #expect(abs(Observer.wellington.longitude - wellington.lon) < 1e-4)
  }

  @Test(
    "Rise, transit and set match the Horizons level-horizon events",
    arguments: BodyID.allCases.filter { bodyTolerances[$0] != nil }
  )
  func eventsMatchHorizons(body: BodyID) throws {
    let fixture = try RTSFixture.load()
    let tolerance = try #require(bodyTolerances[body])
    var worstSeconds = 0.0
    for c in fixture.cases where c.bodyID == body {
      let observer = fixture.observer(c.observer, levelHorizon: true)
      let midnight = c.midnight
      let expectations: [(String, [Double], (BodyID, Observer, DateComponents, TimeZone) throws -> DateComponents)] = [
        ("rise", c.events.rise, { try planetRise($0, observer: $1, date: $2, tzinfo: $3) }),
        ("transit", c.events.transit, { try planetTransit($0, observer: $1, date: $2, tzinfo: $3) }),
        ("set", c.events.set, { try planetSet($0, observer: $1, date: $2, tzinfo: $3) }),
      ]
      for (name, reference, function) in expectations {
        if let first = reference.min() {
          let result = try function(body, observer, c.dateComponents, .utc)
          let error = abs(seconds(result, since: midnight) - first)
          worstSeconds = max(worstSeconds, error)
          #expect(error <= tolerance.eventSeconds, "\(c.testDescription) \(name): \(error) s")
        } else {
          #expect(throws: PlanetError.self, "\(c.testDescription) has no \(name) in the reference") {
            try function(body, observer, c.dateComponents, .utc)
          }
        }
      }
    }
    print("PLANET-RTS \(body.rawValue) max event error (level horizon) \(worstSeconds) s")
  }

  @Test(
    "With the site's elevation Astral is within 2 minutes of JPL's own flags",
    arguments: BodyID.allCases.filter { bodyTolerances[$0] != nil }
  )
  func eventsMatchJPLFlags(body: BodyID) throws {
    let fixture = try RTSFixture.load()
    var worstSeconds = 0.0
    for c in fixture.cases where c.bodyID == body {
      let observer = fixture.observer(c.observer, levelHorizon: false)
      let midnight = c.midnight
      let pairs: [(String, [Double], DateComponents?)] = [
        ("rise", c.jplFlags.rise, try? planetRise(body, observer: observer, date: c.dateComponents)),
        ("transit", c.jplFlags.transit, try? planetTransit(body, observer: observer, date: c.dateComponents)),
        ("set", c.jplFlags.set, try? planetSet(body, observer: observer, date: c.dateComponents)),
      ]
      for (name, flags, result) in pairs {
        guard let flag = flags.first else {
          #expect(result == nil, "\(c.testDescription) \(name) not flagged by JPL")
          continue
        }
        let value = try #require(result, "\(c.testDescription) \(name) missing")
        // JPL flags the first 1 minute step at or after the event: the event lies in (flag - 60, flag].
        let error = abs(seconds(value, since: midnight) - (flag - 30))
        worstSeconds = max(worstSeconds, error)
        #expect(error <= 120, "\(c.testDescription) \(name): \(error) s from the flag interval centre")
      }
    }
    print("PLANET-RTS \(body.rawValue) max error vs JPL flags (with dip) \(worstSeconds) s")
  }

  @Test("Azimuth and elevation match Horizons", arguments: BodyID.allCases.filter { bodyTolerances[$0] != nil })
  func positionMatchesHorizons(body: BodyID) throws {
    let fixture = try RTSFixture.load()
    let tolerance = try #require(bodyTolerances[body])
    var worstAirless = 0.0
    var worstRefracted = 0.0
    for c in fixture.cases where c.bodyID == body {
      let observer = fixture.observer(c.observer, levelHorizon: false)
      for sample in c.samples {
        let when = c.midnight.addingTimeInterval(sample.t)
        let geometricEl = try planetElevation(body, observer: observer, dateandtime: when, with_refraction: false)
        let az = try planetAzimuth(body, observer: observer, dateandtime: when)
        let airless = separation(az1: az, el1: geometricEl, az2: sample.airlessAz, el2: sample.airlessEl)
        worstAirless = max(worstAirless, airless)
        #expect(airless <= tolerance.positionDegrees, "\(c.testDescription) t=\(sample.t) airless: \(airless)°")

        // The refraction model is only compared well above the horizon, where JPL's and Astral's agree.
        if sample.refractedEl > 5 {
          let refractedEl = try planetElevation(body, observer: observer, dateandtime: when)
          let refracted = separation(az1: az, el1: refractedEl, az2: sample.refractedAz, el2: sample.refractedEl)
          worstRefracted = max(worstRefracted, refracted)
          #expect(refracted <= tolerance.positionDegrees, "\(c.testDescription) t=\(sample.t) refracted: \(refracted)°")
        }
      }
    }
    print("PLANET-RTS \(body.rawValue) max position error airless \(worstAirless)°, refracted (>5°) \(worstRefracted)°")
  }
}

// MARK: - PlanetRiseSetBehaviourTests

@Suite("Planet rise/set behaviour", .tags(.ephemeris, .transit, .unit))
struct PlanetRiseSetBehaviourTests {

  @Test("Sun, Earth and Moon are rejected")
  func unsupportedBodies() {
    for body in [BodyID.sun, .earth, .moon] {
      #expect(throws: PlanetError.unsupportedBody(body)) {
        try planetRise(body, observer: .london, date: DateComponents(year: 2026, month: 11, day: 17))
      }
      #expect(throws: PlanetError.unsupportedBody(body)) {
        try planetElevation(body, observer: .london, dateandtime: DateComponents(year: 2026, month: 11, day: 17))
      }
    }
  }

  @Test("Near the pole a planet either never rises or never sets")
  func polarCases() throws {
    let pole = Observer(latitude: 89, longitude: 0, elevation: .double(0))
    let date = DateComponents(year: 2026, month: 11, day: 17)
    for body in [BodyID.venus, .mars, .jupiter, .saturn, .uranus, .neptune] {
      let dec = try planetPosition(body, dateandtime: date).declination
      guard abs(dec) > 3 else { continue }
      let expected: PlanetError = dec > 0 ? .alwaysAboveHorizon(body) : .alwaysBelowHorizon(body)
      #expect(throws: expected) { try planetRise(body, observer: pole, date: date) }
      #expect(throws: expected) { try planetSet(body, observer: pole, date: date) }
    }
  }

  @Test("Result is in the requested time zone and on the requested local date")
  func localTimeZone() throws {
    let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
    let observer = Observer(latitude: 35.68, longitude: 139.69, elevation: .double(0))
    let date = DateComponents(year: 2026, month: 11, day: 17)
    for body in [BodyID.venus, .mars, .jupiter, .saturn] {
      let rise = try planetRise(body, observer: observer, date: date, tzinfo: tokyo)
      #expect(rise.timeZone == tokyo)
      #expect(rise.year == 2026 && rise.month == 11 && rise.day == 17)
      let transit = try planetTransit(body, observer: observer, date: date, tzinfo: tokyo)
      let set = try planetSet(body, observer: observer, date: date, tzinfo: tokyo)
      #expect(transit.day == 17 && set.day == 17)
    }
  }

  @Test("Elevation at the computed rise is the standard altitude")
  func elevationAtRise() throws {
    let date = DateComponents(year: 2026, month: 11, day: 17)
    for body in [BodyID.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune] {
      guard let rise = try? planetRise(body, observer: .london, date: date) else { continue }
      let geometric = try planetElevation(body, observer: .london, dateandtime: rise, with_refraction: false)
      #expect(abs(geometric - planetStandardAltitude) < 0.01, "\(body) \(geometric)")
    }
  }

  @Test("Higher observers see the rise earlier")
  func elevationLowersHorizon() throws {
    let date = DateComponents(year: 2026, month: 11, day: 17)
    let low = Observer(latitude: 40, longitude: 10, elevation: .double(0))
    let high = Observer(latitude: 40, longitude: 10, elevation: .double(2000))
    let lowRise = try planetRise(.jupiter, observer: low, date: date)
    let highRise = try planetRise(.jupiter, observer: high, date: date)
    #expect(seconds(highRise, since: .distantPast) < seconds(lowRise, since: .distantPast))
  }

  @Test("Date and DateComponents flavours agree")
  func dateFlavours() throws {
    let date = Date(timeIntervalSince1970: 1_763_380_800) // 2025-11-17 12:00 UTC
    let components = date.components()
    let a = try planetRise(.mars, observer: .london, date: date)
    let b = try planetRise(.mars, observer: .london, date: components)
    #expect(a == b)
    let e1 = try planetElevation(.mars, observer: .london, dateandtime: date)
    let e2 = try planetElevation(.mars, observer: .london, dateandtime: components)
    #expect(abs(e1 - e2) < 1e-9)
    #expect(abs(try planetZenith(.mars, observer: .london, dateandtime: date) - (90 - e1)) < 1e-9)
  }
}
