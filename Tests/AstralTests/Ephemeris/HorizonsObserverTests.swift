import Foundation
import Testing
@testable import Astral

// Observer-based Sun and Moon functions against NASA/JPL Horizons (topocentric OBSERVER ephemerides).
//
// Fixture: Fixtures/horizons_observer.json, built offline from the committed raw API responses in
// Fixtures/raw_observer by Fixtures/make_observer_fixture.py. Observers are Astral's five predefined
// locations (Observer.london, .newDelhi, .riyadh, .wellington, .barcelona) with their exact coordinates
// (the tests assert that the fixture and Observer.swift agree). Eight UTC dates 2024-2026 (equinoxes and
// solstices), six sample instants per day, plus every rise / transit / set Horizons reports on those days.
//
// What is being compared (all times and instants are UTC):
//  - Sun az/el: Horizons AIRLESS apparent az/el vs `elevation(..., with_refraction: false)` / `azimuth`.
//    Horizons REFRACTED az/el (its Earth refraction model) vs Astral's default refracted elevation, for
//    samples clearly above the horizon only (the two refraction models differ near 0 deg).
//  - Sunrise / sunset / noon: Horizons rise / set / meridian transit, refined from its 1-minute RTS flags
//    to sub-minute precision (see make_observer_fixture.py). Horizons' rise/set threshold is the centre at
//    -(34' + semi-diameter + horizon dip), i.e. the upper limb on a refracted horizon, as in Astral.
//  - Moon: moonPosition RA/Dec vs Horizons geocentric apparent RA/Dec; az/el vs Horizons topocentric
//    (see the known issue below); moonrise / moonset vs refined Horizons rise / set.
//
// Documented accuracy used for the tolerances (CLAUDE.md "Numerical Precision"): solar event times ~1 minute,
// positions 0.01 to 0.1 deg, lunar rise/set a few minutes.

// MARK: - Tolerances

private enum Tol {
  /// Sun airless elevation, degrees.
  static let sunElevation = 0.02
  /// Sun azimuth, degrees of arc on the sky (azimuth difference times cos(elevation)).
  static let sunAzimuth = 0.03
  /// Sun refracted elevation, degrees, for samples with airless elevation above 0.
  static let sunRefractedElevation = 0.03
  /// Sun apparent RA/Dec, degrees.
  static let sunRADec = 0.01
  /// Sunrise, sunset and noon, seconds ("solar calculations generally accurate to ~1 minute").
  static let sunEventSeconds = 60.0
  /// Moon geocentric RA/Dec, degrees (lunar series).
  static let moonRADec = 0.03
  /// Moon az/el against the parallax-corrected (geocentric) Horizons direction, degrees.
  static let moonGeocentricAzEl = 0.03
  /// Moon az/el against Horizons' topocentric direction, degrees (positional accuracy 0.1 deg).
  static let moonTopocentricAzEl = 0.1
  /// Moonrise / moonset, seconds ("a few minutes").
  static let moonEventSeconds = 120.0
}

// MARK: - Fixture

struct HorizonsObserverFixture: Decodable, Sendable {
  struct Site: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double
  }

  struct Sample: Decodable, Sendable {
    let utc: String
    let ra: Double
    let dec: Double
    let az: Double
    let el: Double
    let diameterArcsec: Double
    let delta: Double
    let refractedAz: Double
    let refractedEl: Double
  }

  struct Event: Decodable, Sendable {
    let flagUTC: String
    let refinedSecondsOfDay: Double
    let thresholdDeg: Double?
    let maxElevationDeg: Double?
  }

  struct BodyData: Decodable, Sendable {
    let samples: [Sample]
    let events: [String: [String: Event]]
  }

  struct Geocentric: Decodable, Sendable {
    let utc: String
    let ra: Double
    let dec: Double
    let delta: Double
  }

  let dates: [String]
  let observers: [String: Site]
  let bodies: [String: [String: BodyData]]
  let moonGeocentric: [Geocentric]

  static let shared: HorizonsObserverFixture = try! load()

  static func load() throws -> HorizonsObserverFixture {
    let url = try #require(
      Bundle.module.url(forResource: "horizons_observer", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "horizons_observer", withExtension: "json"),
      "horizons_observer.json missing from test bundle")
    return try JSONDecoder().decode(HorizonsObserverFixture.self, from: Data(contentsOf: url))
  }
}

private let observerNames = ["london", "newDelhi", "riyadh", "wellington", "barcelona"]

/// The Observer used for the comparisons: the fixture's decimal coordinates (the same ones that were sent to
/// Horizons). Observer.wellington and Observer.barcelona are not used because their DMS strings are
/// mis-parsed by Astral (see `predefinedDMSObserversMatchTheirDocumentedCoordinates`).
private func astralObserver(_ name: String) -> Observer {
  let site = HorizonsObserverFixture.shared.observers[name]!
  return Observer(latitude: site.latitude, longitude: site.longitude, elevation: .double(site.elevationMeters))
}

/// Astral's own predefined static for the same place.
private func predefinedObserver(_ name: String) -> Observer {
  switch name {
  case "london": .london
  case "newDelhi": .newDelhi
  case "riyadh": .riyadh
  case "wellington": .wellington
  case "barcelona": .barcelona
  default: fatalError("unknown observer \(name)")
  }
}

private var utcCalendar: Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0)!
  return calendar
}

/// "2025-03-20T04:00:00Z" -> UTC DateComponents.
private func components(utc string: String) -> DateComponents {
  let d = string.dropLast().split(whereSeparator: { "-T:".contains($0) }).map { Int($0)! }
  return DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: d[0], month: d[1], day: d[2], hour: d[3], minute: d[4], second: d[5])
}

/// "2025-03-20" -> (UTC midnight Date, midnight-with-hour-and-minute DateComponents as moonrise() needs them).
private func midnight(_ date: String) -> (Date, DateComponents) {
  let d = date.split(separator: "-").map { Int($0)! }
  let dc = DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: d[0], month: d[1], day: d[2], hour: 0, minute: 0, second: 0)
  return (utcCalendar.date(from: dc)!, dc)
}

private func secondsOfDay(_ result: DateComponents, since midnight: Date) -> Double {
  var c = result
  c.timeZone = TimeZone(secondsFromGMT: 0)
  return utcCalendar.date(from: c)!.timeIntervalSince(midnight)
}

private func wrap180(_ x: Double) -> Double {
  var d = x.truncatingRemainder(dividingBy: 360)
  if d > 180 { d -= 360 }
  if d < -180 { d += 360 }
  return d
}

/// Running maximum with a label, printed at the end so the measured accuracy is visible in the test log.
private struct MaxError {
  let label: String
  var value = 0.0
  var worst = ""
  var count = 0
  init(_ label: String) { self.label = label }
  mutating func add(_ error: Double, _ context: @autoclosure () -> String) {
    count += 1
    if error > value {
      value = error
      worst = context()
    }
  }

  func report(unit: String) {
    print("OBSFIX \(label): max error \(String(format: "%.4f", value)) \(unit) over \(count) cases (worst: \(worst))")
  }
}

// MARK: - Fixture consistency

@Suite("Horizons observer fixture", .tags(.ephemeris, .accuracy, .integration))
struct HorizonsObserverFixtureTests {
  @Test func fixtureContainsAllObservers() throws {
    let fixture = try HorizonsObserverFixture.load()
    #expect(Set(fixture.observers.keys) == Set(observerNames))
  }

  /// Observer.london, .newDelhi and .riyadh are plain decimals and match the coordinates sent to Horizons.
  @Test(arguments: ["london", "newDelhi", "riyadh"])
  func predefinedObserversMatchFixture(name: String) throws {
    let site = try #require(HorizonsObserverFixture.shared.observers[name])
    let observer = predefinedObserver(name)
    #expect(abs(site.latitude - observer.latitude) < 1e-9, "\(name) latitude fixture \(site.latitude) Astral \(observer.latitude)")
    #expect(abs(site.longitude - observer.longitude) < 1e-9, "\(name) longitude fixture \(site.longitude) Astral \(observer.longitude)")
    guard case .double(let elevation) = observer.elevation else {
      Issue.record("\(name): expected a plain elevation")
      return
    }
    #expect(site.elevationMeters == elevation, "\(name) elevation")
  }

  /// The predefined DMS observers (seconds written with the `''` marker) parse to the coordinates they denote.
  @Test(arguments: ["wellington", "barcelona"])
  func predefinedDMSObserversMatchTheirDocumentedCoordinates(name: String) throws {
    let site = try #require(HorizonsObserverFixture.shared.observers[name])
    let observer = predefinedObserver(name)
    print("OBSFIX \(name) predefined Observer: latitude \(observer.latitude) (documented \(site.latitude)), longitude \(observer.longitude) (documented \(site.longitude))")
        #expect(abs(site.latitude - observer.latitude) < 1e-4, "\(name) latitude fixture \(site.latitude) Astral \(observer.latitude)")
    #expect(abs(site.longitude - observer.longitude) < 1e-4, "\(name) longitude fixture \(site.longitude) Astral \(observer.longitude)")
  }

  @Test func refinedEventsLieInsideTheFlaggedMinute() throws {
    let fixture = try HorizonsObserverFixture.load()
    var checked = 0
    for (_, byObserver) in fixture.bodies {
      for (_, data) in byObserver {
        for (date, events) in data.events {
          let (midnightDate, _) = midnight(date)
          for (name, event) in events {
            let flagged = secondsOfDay(components(utc: event.flagUTC), since: midnightDate)
            // Horizons flags the first step after the event; transits are interpolated between neighbours.
            if name == "transit" {
              #expect(abs(event.refinedSecondsOfDay - flagged) <= 60, "\(date) \(name)")
            } else {
              #expect(event.refinedSecondsOfDay > flagged - 60 && event.refinedSecondsOfDay <= flagged, "\(date) \(name)")
            }
            checked += 1
          }
        }
      }
    }
    #expect(checked > 150)
  }
}

// MARK: - Sun

@Suite("Sun vs JPL Horizons (observer)", .tags(.solar, .ephemeris, .accuracy, .integration))
struct SunHorizonsObserverTests {
  @Test("Sun airless elevation and azimuth", arguments: observerNames)
  func airlessPosition(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["sun"]?[name])
    var elevationError = MaxError("sun elevation (no refraction) \(name)")
    var azimuthError = MaxError("sun azimuth \(name)")
    for sample in data.samples {
      let when = components(utc: sample.utc)
      let el = Astral.elevation(observer: observer, dateandtime: when, with_refraction: false)
      let eEl = abs(el - sample.el)
      elevationError.add(eEl, "\(sample.utc) astral \(el) horizons \(sample.el)")
      #expect(eEl <= Tol.sunElevation, "\(name) \(sample.utc) elevation \(el) vs \(sample.el)")

      let az = Astral.azimuth(observer: observer, dateandtime: when)
      let eAz = abs(wrap180(az - sample.az)) * cos(sample.el * .pi / 180)
      azimuthError.add(eAz, "\(sample.utc) astral \(az) horizons \(sample.az)")
      #expect(eAz <= Tol.sunAzimuth, "\(name) \(sample.utc) azimuth \(az) vs \(sample.az)")
    }
    elevationError.report(unit: "deg")
    azimuthError.report(unit: "deg of arc")
  }

  @Test("Sun refracted elevation above the horizon", arguments: observerNames)
  func refractedElevation(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["sun"]?[name])
    var error = MaxError("sun elevation (refracted, el>0) \(name)")
    for sample in data.samples where sample.el > 0 {
      let el = Astral.elevation(observer: observer, dateandtime: components(utc: sample.utc))
      let e = abs(el - sample.refractedEl)
      error.add(e, "\(sample.utc) astral \(el) horizons \(sample.refractedEl)")
      #expect(e <= Tol.sunRefractedElevation, "\(name) \(sample.utc) refracted elevation \(el) vs \(sample.refractedEl)")
    }
    #expect(error.count > 10)
    error.report(unit: "deg")
  }

  @Test("Sun apparent right ascension and declination", arguments: observerNames)
  func rightAscensionDeclination(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let data = try #require(fixture.bodies["sun"]?[name])
    var raError = MaxError("sun RA \(name)")
    var decError = MaxError("sun Dec \(name)")
    for sample in data.samples {
      let jc = julianDayToCentury(julianDay: julianDay(at: components(utc: sample.utc)))
      let ra = sun_rt_ascension(juliancentury: jc)
      let dec = sun_declination(juliancentury: jc)
      let eRa = abs(wrap180(ra - sample.ra)) * cos(sample.dec * .pi / 180)
      let eDec = abs(dec - sample.dec)
      raError.add(eRa, "\(sample.utc) astral \(ra) horizons \(sample.ra)")
      decError.add(eDec, "\(sample.utc) astral \(dec) horizons \(sample.dec)")
      #expect(eRa <= Tol.sunRADec, "\(name) \(sample.utc) RA \(ra) vs \(sample.ra)")
      #expect(eDec <= Tol.sunRADec, "\(name) \(sample.utc) Dec \(dec) vs \(sample.dec)")
    }
    raError.report(unit: "deg of arc")
    decError.report(unit: "deg")
  }

  /// Moonrise/moonset include the horizon dip for elevated observers (Riyadh, 620 m).
  @Test("Moonrise and moonset", arguments: observerNames)
  func moonriseMoonset(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["moon"]?[name])
    var riseError = MaxError("moonrise \(name)")
    var setError = MaxError("moonset \(name)")
    for date in fixture.dates {
      let (start, dc) = midnight(date)
      let day = DateComponents(timeZone: dc.timeZone, year: dc.year, month: dc.month, day: dc.day)
      if let rise = data.events[date]?["rise"] {
        if let time = try? moonrise(observer: observer, dateComponents: day) {
          let seconds = secondsOfDay(time, since: start)
          riseError.add(abs(seconds - rise.refinedSecondsOfDay), "\(date) astral \(seconds)s horizons \(rise.refinedSecondsOfDay)s")
        } else {
          Issue.record("\(name) \(date): Horizons has a moonrise at \(rise.flagUTC) but Astral returned none")
        }
      }
      if let set = data.events[date]?["set"] {
        if let time = try? moonset(observer: observer, dateComponents: day) {
          let seconds = secondsOfDay(time, since: start)
          setError.add(abs(seconds - set.refinedSecondsOfDay), "\(date) astral \(seconds)s horizons \(set.refinedSecondsOfDay)s")
        } else {
          Issue.record("\(name) \(date): Horizons has a moonset at \(set.flagUTC) but Astral returned none")
        }
      }
    }
    #expect(riseError.count > 4 && setError.count > 4)
    riseError.report(unit: "s")
    setError.report(unit: "s")
        #expect(riseError.value <= Tol.moonEventSeconds, "\(name) moonrise \(riseError.worst)")
    #expect(setError.value <= Tol.moonEventSeconds, "\(name) moonset \(setError.worst)")
  }
}
