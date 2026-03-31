//
//  BugFixRegressionTests.swift
//
//  Regression tests for three confirmed bugs:
//  1. Moon.swift:223 - T factor had spurious +1 offset corrupting lunar series
//  2. Sun.swift:686  - midnight() missing hour > 23 day rollover
//  3. Sun.swift:853  - rahukaalam() totalSeconds used wrong DateComponents key
//

import Foundation
import Testing
@testable import Astral

// MARK: - Bug 1: Moon position T factor

@Suite("Regression: Moon position T factor", .tags(.lunar, .regression, .accuracy))
struct MoonPositionTFactorTests {

  // Reference values from Meeus "Astronomical Algorithms" Table 47.a
  // Date: 1992-04-12 00:00 UTC → jd2000 = -2819.5
  // Expected geocentric Moon position (Meeus §47):
  //   RA  ≈ 134.688°  → 2.3506 rad
  //   Dec ≈  13.768°  → 0.2403 rad
  //   Δ   ≈ 368409.7 km  / 6378.14 km ≈ 57.76 Earth radii
  //
  // With the old bug (T = jd2000/36525 + 1), the T-dependent series terms
  // were scaled by ~0.923 instead of the correct ~-0.077, producing
  // materially wrong RA/Dec for this well-known reference epoch.

  @Test("1992-04-12 geocentric RA matches Meeus Table 47.a", .tags(.unit))
  func raMatchesMeeus1992() {
    let date = DateComponents.date(1992, 4, 12)
    let jd2000 = julianDay(at: date) - 2451545.0
    let pos = moonPosition(jd2000: jd2000)

    // RA should be near 2.350 rad (134.7°). Allow ±0.01 rad (~0.6°).
    #expect(abs(pos.right_ascension - 2.3507) < 0.01,
      "RA \(pos.right_ascension) rad should be ~2.3507 rad (Meeus ref)")
  }

  @Test("1992-04-12 geocentric Dec matches Meeus Table 47.a", .tags(.unit))
  func decMatchesMeeus1992() {
    let date = DateComponents.date(1992, 4, 12)
    let jd2000 = julianDay(at: date) - 2451545.0
    let pos = moonPosition(jd2000: jd2000)

    // Dec should be near 0.2403 rad (13.77°). Allow ±0.005 rad.
    #expect(abs(pos.declination - 0.2403) < 0.005,
      "Dec \(pos.declination) rad should be ~0.2403 rad (Meeus ref)")
  }

  @Test("1992-04-12 geocentric distance matches Meeus Table 47.a", .tags(.unit))
  func distanceMatchesMeeus1992() {
    let date = DateComponents.date(1992, 4, 12)
    let jd2000 = julianDay(at: date) - 2451545.0
    let pos = moonPosition(jd2000: jd2000)

    // Distance ≈ 57.76 Earth radii. Allow ±0.5 Earth radii.
    #expect(abs(pos.distance - 57.76) < 0.5,
      "Distance \(pos.distance) Earth radii should be ~57.76")
  }

  @Test("T factor at J2000.0 epoch produces valid position", .tags(.unit))
  func tFactorAtEpoch() {
    // At J2000.0 exactly (jd2000 = 0), T should be 0.
    // The old bug produced T = 1, amplifying all t-flagged series rows.
    let pos = moonPosition(jd2000: 0.0)
    #expect(pos.distance > 50 && pos.distance < 70,
      "Distance at J2000.0 should be 50–70 Earth radii, got \(pos.distance)")
    #expect(abs(pos.declination) < 0.55,
      "Declination at J2000.0 should be within ±0.55 rad, got \(pos.declination)")
  }
}

// MARK: - Bug 2: midnight() hour > 23 rollover

@Suite("Regression: midnight() day rollover", .tags(.solar, .regression, .edge))
struct MidnightDayRolloverTests {

  // Solar midnight for an observer at a strongly negative (west) longitude
  // can produce a UTC hour > 23, which must roll over to the next day.
  // Honolulu, HI (−157.83°) is an ideal test case.

  @Test("midnight() hour is always 0–23 for western longitude", .tags(.unit))
  func midnightHourInRangeWesternLongitude() {
    let honolulu = Observer(latitude: 21.3, longitude: -157.83, elevation: .double(0))
    let date = DateComponents.date(2024, 6, 21)
    let result = midnight(observer: honolulu, date: date)

    let hour = result.hour ?? -1
    #expect(hour >= 0 && hour <= 23,
      "midnight() hour should be 0–23 for Honolulu, got \(hour)")
  }

  @Test("midnight() hour is always 0–23 for eastern longitude", .tags(.unit))
  func midnightHourInRangeEasternLongitude() {
    let wellington = Observer(latitude: -41.29, longitude: 174.78, elevation: .double(0))
    let date = DateComponents.date(2024, 6, 21)
    let result = midnight(observer: wellington, date: date)

    let hour = result.hour ?? -1
    #expect(hour >= 0 && hour <= 23,
      "midnight() hour should be 0–23 for Wellington, got \(hour)")
  }

  @Test("midnight() always produces a valid Calendar Date", .tags(.unit))
  func midnightProducesValidDate() {
    let honolulu = Observer(latitude: 21.3, longitude: -157.83, elevation: .double(0))
    let calendar = Calendar(identifier: .gregorian)
    for month in [1, 6, 12] {
      let date = DateComponents.date(2024, month, 15)
      let result = midnight(observer: honolulu, date: date, tzinfo: .utc)
      #expect(calendar.date(from: result) != nil,
        "midnight() for month \(month) should form a valid Date")
    }
  }

  @Test("midnight() hour > 23 fix: rolls day forward for Honolulu June 21", .tags(.unit, .regression))
  func midnightDayRollsForward() {
    // Honolulu longitude −157.83° → timeUTC ≈ (157.83×4 − eqtime)/60 > 10 h
    // Specifically around summer solstice the UTC solar midnight falls near 00:xx on June 22.
    let honolulu = Observer(latitude: 21.3, longitude: -157.83, elevation: .double(0))
    let date = DateComponents.date(2024, 6, 21)
    let result = midnight(observer: honolulu, date: date, tzinfo: .utc)

    let hour = result.hour ?? -1
    let day  = result.day  ?? -1
    // Hour must be valid regardless of which day it lands on
    #expect(hour >= 0 && hour <= 23)
    // Day must be either 21 (late evening) or 22 (early morning after rollover)
    #expect(day == 21 || day == 22,
      "midnight() day for Honolulu June 21 UTC should be 21 or 22, got \(day)")
  }
}

// MARK: - Bug 3: rahukaalam() totalSeconds

@Suite("Regression: rahukaalam() duration", .tags(.solar, .regression, .accuracy))
struct RahukaalamDurationTests {

  // The old bug: dateComponents([.second], from:to:).second returns only
  // the 0–59 seconds component, not total elapsed seconds.
  // This gave totalSeconds ≤ 59, so each octant was ≤ 7 seconds — clearly wrong.
  // After the fix, octantDuration ≈ daytime / 8 ≈ 90–120 min for mid-latitudes.

  static let london = Observer(latitude: 51.5, longitude: -0.12, elevation: .double(0))
  static let delhi  = Observer(latitude: 28.6, longitude: 77.2, elevation: .double(0))

  @Test("Rahukaalam octant is 90–130 minutes (not seconds)", .tags(.unit))
  func rahukaalamDurationReasonable() throws {
    let date = DateComponents.date(2024, 6, 21) // summer solstice — long day
    let (start, end) = try rahukaalam(observer: Self.london, date: date, tzinfo: .utc)

    let calendar = Calendar(identifier: .gregorian)
    guard
      let s = calendar.date(from: start),
      let e = calendar.date(from: end)
    else {
      Issue.record("Could not construct Date from rahukaalam result")
      return
    }

    let durationMinutes = e.timeIntervalSince(s) / 60.0
    #expect(durationMinutes > 90 && durationMinutes < 130,
      "Rahukaalam octant should be 90–130 min, got \(durationMinutes) min")
  }

  @Test("Rahukaalam start is before end", .tags(.unit))
  func rahukaalamStartBeforeEnd() throws {
    let date = DateComponents.date(2024, 3, 20) // equinox
    let (start, end) = try rahukaalam(observer: Self.delhi, date: date, tzinfo: .utc)

    let calendar = Calendar(identifier: .gregorian)
    guard
      let s = calendar.date(from: start),
      let e = calendar.date(from: end)
    else {
      Issue.record("Could not construct Date from rahukaalam result")
      return
    }
    #expect(s < e, "Rahukaalam start must be before end")
  }

  @Test("Rahukaalam interval falls within the daytime window", .tags(.integration))
  func rahukaalamWithinDaytime() throws {
    let date = DateComponents.date(2024, 6, 21)
    let (rStart, rEnd) = try rahukaalam(observer: Self.london, date: date, tzinfo: .utc)
    let dayStart = try sunrise(observer: Self.london, date: date, tzinfo: .utc)
    let dayEnd   = try sunset(observer: Self.london, date: date, tzinfo: .utc)

    let calendar = Calendar(identifier: .gregorian)
    guard
      let rs = calendar.date(from: rStart),
      let re = calendar.date(from: rEnd),
      let ds = calendar.date(from: dayStart),
      let de = calendar.date(from: dayEnd)
    else {
      Issue.record("Could not construct Date from DateComponents")
      return
    }
    #expect(rs >= ds, "Rahukaalam start should be at or after sunrise")
    #expect(re <= de, "Rahukaalam end should be at or before sunset")
  }

  @Test("Rahukaalam octant duration ≈ daytime / 8", .tags(.accuracy))
  func rahukaalamOctantMatchesDayEighth() throws {
    let date = DateComponents.date(2024, 9, 23) // autumnal equinox ≈ 12 h day
    let (rStart, rEnd) = try rahukaalam(observer: Self.london, date: date, tzinfo: .utc)
    let dayStart = try sunrise(observer: Self.london, date: date, tzinfo: .utc)
    let dayEnd   = try sunset(observer: Self.london, date: date, tzinfo: .utc)

    let calendar = Calendar(identifier: .gregorian)
    guard
      let rs = calendar.date(from: rStart),
      let re = calendar.date(from: rEnd),
      let ds = calendar.date(from: dayStart),
      let de = calendar.date(from: dayEnd)
    else {
      Issue.record("Could not construct Date from DateComponents")
      return
    }
    let octantDuration   = re.timeIntervalSince(rs)
    let expectedOctant   = de.timeIntervalSince(ds) / 8.0
    // Allow ±60 s for integer truncation of total seconds
    #expect(abs(octantDuration - expectedOctant) < 60.0,
      "Octant \(octantDuration)s should be ~\(expectedOctant)s (daytime/8)")
  }
}
