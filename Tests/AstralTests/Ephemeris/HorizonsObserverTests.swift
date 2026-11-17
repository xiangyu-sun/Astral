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

  /// KNOWN ISSUE (measured, library not changed): Observer.wellington (" 41° 17' 11.256'' S", "174° 46' 34.4496'' E")
  /// and Observer.barcelona are built from DMS strings whose seconds use the two-apostrophe marker `''`. The
  /// parser in DegressMinutesSeconds.swift only recognises `″` or `"` for seconds, so the seconds are dropped
  /// and, because the hemisphere letter then no longer follows the matched text, so is the sign: Observer.wellington
  /// has latitude +41.2833 (north) instead of -41.2865, i.e. it sits in the wrong hemisphere (~82.6 deg error), and
  /// Observer.barcelona is off by ~0.007 deg (~0.8 km). The fixture holds the coordinates the strings denote.
  @Test(arguments: ["wellington", "barcelona"])
  func predefinedDMSObserversMatchTheirDocumentedCoordinates(name: String) throws {
    let site = try #require(HorizonsObserverFixture.shared.observers[name])
    let observer = predefinedObserver(name)
    print("OBSFIX \(name) predefined Observer: latitude \(observer.latitude) (documented \(site.latitude)), longitude \(observer.longitude) (documented \(site.longitude))")
    withKnownIssue("DMS seconds marker '' not parsed: seconds and hemisphere letter are lost") {
      #expect(abs(site.latitude - observer.latitude) < 1e-4, "\(name) latitude fixture \(site.latitude) Astral \(observer.latitude)")
      #expect(abs(site.longitude - observer.longitude) < 1e-4, "\(name) longitude fixture \(site.longitude) Astral \(observer.longitude)")
    }
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

  /// KNOWN ISSUE (measured, not fudged) for Riyadh (620 m): with an elevated observer `time_of_transit` evaluates
  /// the refraction at the dipped altitude (zenith + dip) instead of at the horizon, using the below-horizon
  /// formula `-20.774 / tan(el)` (about 0.31 deg instead of the standard 0.57 deg). The apparent horizon is then
  /// ~0.27 deg too high and sunrise/sunset are off by ~75 s (the documented accuracy is ~1 minute). Sea-level
  /// observers and the 13 m Wellington site are within 25 s.
  @Test("Sunrise and sunset", arguments: observerNames)
  func sunriseSunset(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["sun"]?[name])
    var riseError = MaxError("sunrise \(name)")
    var setError = MaxError("sunset \(name)")
    for date in fixture.dates {
      let (start, dc) = midnight(date)
      let day = DateComponents(timeZone: dc.timeZone, year: dc.year, month: dc.month, day: dc.day)
      if let rise = data.events[date]?["rise"] {
        let seconds = secondsOfDay(try sunrise(observer: observer, date: day), since: start)
        riseError.add(abs(seconds - rise.refinedSecondsOfDay), "\(date) astral \(seconds)s horizons \(rise.refinedSecondsOfDay)s")
      }
      if let set = data.events[date]?["set"] {
        let seconds = secondsOfDay(try sunset(observer: observer, date: day), since: start)
        setError.add(abs(seconds - set.refinedSecondsOfDay), "\(date) astral \(seconds)s horizons \(set.refinedSecondsOfDay)s")
      }
    }
    #expect(riseError.count > 4 && setError.count > 4)
    riseError.report(unit: "s")
    setError.report(unit: "s")
    withKnownIssue("elevated observer: refraction evaluated at the dipped altitude", isIntermittent: false) {
      #expect(riseError.value <= Tol.sunEventSeconds, "\(name) sunrise \(riseError.worst)")
      #expect(setError.value <= Tol.sunEventSeconds, "\(name) sunset \(setError.worst)")
    } when: {
      name == "riyadh"
    }
  }

  @Test("Solar noon", arguments: observerNames)
  func solarNoon(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["sun"]?[name])
    var error = MaxError("solar noon \(name)")
    for date in fixture.dates {
      let (start, dc) = midnight(date)
      guard let transit = data.events[date]?["transit"] else { continue }
      let day = DateComponents(timeZone: dc.timeZone, year: dc.year, month: dc.month, day: dc.day)
      let seconds = secondsOfDay(noon(observer: observer, date: day), since: start)
      let e = abs(seconds - transit.refinedSecondsOfDay)
      error.add(e, "\(date) astral \(seconds)s horizons \(transit.refinedSecondsOfDay)s")
      #expect(e <= Tol.sunEventSeconds, "\(name) \(date) noon \(seconds)s vs \(transit.refinedSecondsOfDay)s")
    }
    #expect(error.count > 4)
    error.report(unit: "s")
  }
}

// MARK: - Moon

/// Azimuth and elevation (degrees) of the geocentric direction of a body seen from `observer`, derived from
/// its topocentric az/el and distance: geocentric = distance * u + observer position (spherical-Earth
/// approximation; the omitted geodetic/geocentric tilt changes the result by well under 0.005 deg).
private func geocentricDirection(topocentricAz az: Double, el: Double, deltaAU: Double, observer: Observer) -> (az: Double, el: Double) {
  let distance = deltaAU * 149_597_870.7 / 6378.137 // Earth equatorial radii
  let a = az * .pi / 180, e = el * .pi / 180
  let phi = observer.latitude * .pi / 180
  var rho = 0.9983271 + 0.0016764 * cos(2 * phi) - 0.0000035 * cos(4 * phi)
  if case .double(let h) = observer.elevation { rho += h / 6_378_137 }
  let east = distance * sin(a) * cos(e)
  let north = distance * cos(a) * cos(e)
  let up = distance * sin(e) + rho
  var gAz = atan2(east, north) * 180 / .pi
  if gAz < 0 { gAz += 360 }
  return (gAz, atan2(up, hypot(east, north)) * 180 / .pi)
}

@Suite("Moon vs JPL Horizons (observer)", .tags(.lunar, .ephemeris, .accuracy, .integration))
struct MoonHorizonsObserverTests {
  @Test("Moon geocentric right ascension and declination")
  func geocentricRADec() throws {
    let fixture = try HorizonsObserverFixture.load()
    var error = MaxError("moon geocentric RA/Dec separation")
    for sample in fixture.moonGeocentric {
      let position = moonPosition(jd2000: julianDay2000(at: components(utc: sample.utc)))
      let ra = position.right_ascension * 180 / .pi
      let dec = position.declination * 180 / .pi
      let dRa = wrap180(ra - sample.ra) * cos(sample.dec * .pi / 180)
      let dDec = dec - sample.dec
      let separation = hypot(dRa, dDec)
      error.add(separation, "\(sample.utc) astral (\(ra), \(dec)) horizons (\(sample.ra), \(sample.dec))")
      #expect(separation <= Tol.moonRADec, "\(sample.utc) RA/Dec off by \(separation) deg")
    }
    error.report(unit: "deg")
  }

  /// Astral's Moon azimuth/elevation are geocentric directions seen from the observer's horizon: no
  /// parallax (up to ~0.95 deg for the Moon) and no refraction. After removing the parallax from
  /// Horizons' topocentric direction the two agree to the accuracy of the lunar series.
  @Test("Moon az/el against the geocentric Horizons direction", arguments: observerNames)
  func geocentricAzEl(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["moon"]?[name])
    var elevationError = MaxError("moon elevation vs geocentric direction \(name)")
    var azimuthError = MaxError("moon azimuth vs geocentric direction \(name)")
    for sample in data.samples {
      let when = components(utc: sample.utc)
      let expected = geocentricDirection(topocentricAz: sample.az, el: sample.el, deltaAU: sample.delta, observer: observer)
      let el = Astral.elevation(observer: observer, at: when)
      let az = Astral.azimuth(observer: observer, at: when)
      let eEl = abs(el - expected.el)
      let eAz = abs(wrap180(az - expected.az)) * cos(expected.el * .pi / 180)
      elevationError.add(eEl, "\(sample.utc) astral \(el) expected \(expected.el)")
      azimuthError.add(eAz, "\(sample.utc) astral \(az) expected \(expected.az)")
      #expect(eEl <= Tol.moonGeocentricAzEl, "\(name) \(sample.utc) elevation \(el) vs \(expected.el)")
      #expect(eAz <= Tol.moonGeocentricAzEl, "\(name) \(sample.utc) azimuth \(az) vs \(expected.az)")
    }
    elevationError.report(unit: "deg")
    azimuthError.report(unit: "deg of arc")
  }

  /// KNOWN ISSUE (measured, not fudged): `elevation(observer:at:)` and `azimuth(observer:at:)` for the
  /// Moon use the geocentric RA/Dec without a topocentric (parallax) correction, so they differ from what an
  /// observer sees (Horizons topocentric) by up to about one degree in elevation, far beyond the 0.1 deg
  /// positional accuracy documented in CLAUDE.md. Tolerance is left at 0.1 deg; the measured errors are
  /// printed as OBSFIX lines. The geocentric-direction test above shows the rest of the pipeline is sound.
  @Test("Moon az/el against Horizons topocentric az/el", arguments: observerNames)
  func topocentricAzEl(name: String) throws {
    let fixture = try HorizonsObserverFixture.load()
    let observer = astralObserver(name)
    let data = try #require(fixture.bodies["moon"]?[name])
    var elevationError = MaxError("moon elevation vs topocentric \(name)")
    var azimuthError = MaxError("moon azimuth vs topocentric \(name)")
    for sample in data.samples {
      let when = components(utc: sample.utc)
      let el = Astral.elevation(observer: observer, at: when)
      let az = Astral.azimuth(observer: observer, at: when)
      elevationError.add(abs(el - sample.el), "\(sample.utc) astral \(el) horizons \(sample.el)")
      azimuthError.add(abs(wrap180(az - sample.az)) * cos(sample.el * .pi / 180), "\(sample.utc) astral \(az) horizons \(sample.az)")
    }
    elevationError.report(unit: "deg")
    azimuthError.report(unit: "deg of arc")
    withKnownIssue("Moon az/el has no parallax correction (up to ~1 deg)") {
      #expect(elevationError.value <= Tol.moonTopocentricAzEl, "max elevation error \(elevationError.value) deg")
      #expect(azimuthError.value <= Tol.moonTopocentricAzEl, "max azimuth error \(azimuthError.value) deg")
    }
  }

  /// KNOWN ISSUE (measured, not fudged) for Riyadh (620 m): moonrise/moonset take no account of the observer's
  /// elevation (the horizon dip of ~0.8 deg), so they are ~4.5 minutes off Horizons (which does apply the dip),
  /// beyond "a few minutes". Sea-level sites and the 13 m Wellington site are within ~66 s.
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
    withKnownIssue("moonrise/moonset ignore the observer's elevation (horizon dip)", isIntermittent: false) {
      #expect(riseError.value <= Tol.moonEventSeconds, "\(name) moonrise \(riseError.worst)")
      #expect(setError.value <= Tol.moonEventSeconds, "\(name) moonset \(setError.worst)")
    } when: {
      name == "riyadh"
    }
  }
}
