import Foundation
import Testing
@testable import Astral

/// ΔT polynomials, leap seconds and the UTC→TT chain. Offline: reference values are transcribed from
/// https://eclipse.gsfc.nasa.gov/SEhelp/deltat2004.html (Tables 1 and 2) and naif0012.tls.
@Suite("DeltaT and TT", .tags(.ephemeris, .time, .fast))
struct DeltaTTests {

  // MARK: ΔT

  /// Values given directly by the polynomial constants (t = 0 in each range).
  @Test func polynomialAnchorValues() {
    #expect(abs(DeltaT.seconds(decimalYear: 1900) - -2.79) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 1920) - 21.20) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 1950) - 29.07) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 1975) - 45.45) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 2000) - 63.86) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 1600) - 120) < 1e-9)
    #expect(abs(DeltaT.seconds(decimalYear: 1700) - 8.83) < 1e-9)
  }

  /// NASA Table 1 (historical) and Table 2 (direct observations), with the stated fit quality as tolerance.
  @Test(arguments: [
    (-500.0, 17190.0, 20.0), (-400, 15530, 30), (-300, 14080, 30), (0, 10580, 10), (100, 9600, 10),
    (500, 5710, 10), (1000, 1570, 10), (1500, 200, 5), (1600, 120, 1), (1700, 9, 1), (1750, 13, 1),
    (1800, 14, 1), (1850, 7, 1), (1900, -3, 1), (1950, 29, 1),
    (1955, 31.1, 1), (1960, 33.2, 1), (1965, 35.7, 1), (1970, 40.2, 1), (1975, 45.5, 1), (1980, 50.5, 1),
    (1985, 54.3, 1), (1990, 56.9, 1), (1995, 60.8, 1), (2000, 63.8, 1), (2005, 64.7, 1),
  ] as [(Double, Double, Double)])
  func matchesNASATables(year: Double, expected: Double, tolerance: Double) {
    let dt = DeltaT.seconds(decimalYear: year)
    #expect(abs(dt - expected) <= tolerance, "ΔT(\(year)) = \(dt), table \(expected)")
  }

  /// NASA's own extrapolation estimates: +67 s in 2010, +93 s in 2050, +203 s in 2100, +442 s in 2200.
  @Test func extrapolationEstimates() {
    #expect(abs(DeltaT.seconds(decimalYear: 2010) - 67) < 1)
    #expect(abs(DeltaT.seconds(decimalYear: 2050) - 93) < 1)
    #expect(abs(DeltaT.seconds(decimalYear: 2100) - 203) < 1)
    #expect(abs(DeltaT.seconds(decimalYear: 2200) - 442) < 1)
  }

  /// The pieces are designed to meet; a jump larger than a fraction of a second would indicate a transcription error.
  @Test func continuityAtRangeBoundaries() {
    let boundaries: [Double] = [
      -500, 500, 1600, 1700, 1800, 1860, 1900, 1920, 1941, 1961, 1986, 2005, 2050, 2150,
    ]
    let eps = 1e-9
    for y in boundaries {
      let below = DeltaT.seconds(decimalYear: y - eps)
      let above = DeltaT.seconds(decimalYear: y + eps)
      // Tolerances reflect the published fits: the table-based pieces meet to a few tenths of a second, or a few
      // seconds around the 6th-degree fits.
      let tolerance = (y == 500) ? 5.0 : 1.0
      #expect(abs(above - below) <= tolerance, "jump at \(y): \(below) -> \(above)")
    }
    // Exact by construction (NASA changed 17190 to 17203.7 at -500, and added the -0.5628 (2150 - y) term).
    #expect(abs(DeltaT.seconds(decimalYear: -500) - 17203.7) < 0.05)
    #expect(abs(DeltaT.seconds(decimalYear: 2050 - 1e-9) - DeltaT.seconds(decimalYear: 2050)) < 0.01)
    #expect(abs(DeltaT.seconds(decimalYear: 2150 - 1e-9) - DeltaT.seconds(decimalYear: 2150 + 1e-9)) < 1e-4)
  }

  @Test func longTermParabola() {
    let u = (3000.0 - 1820) / 100
    #expect(abs(DeltaT.seconds(decimalYear: 3000) - (-20 + 32 * u * u)) < 1e-9)
    let v = (-1999.0 - 1820) / 100
    #expect(abs(DeltaT.seconds(decimalYear: -1999) - (-20 + 32 * v * v)) < 1e-9)
  }

  @Test func decimalYearOfJulianDate() {
    #expect(abs(DeltaT.decimalYear(of: JulianDate(days: 2_451_544.5)) - 2000.0) < 1e-12)
    // 2000 is a leap year: 2000-07-01 is day 182 of 366 (0-based), noon adds half a day.
    #expect(abs(DeltaT.decimalYear(of: JulianDate(days: 2_451_726.5)) - (2000 + 182.0 / 366)) < 1e-12)
    #expect(abs(DeltaT.decimalYear(of: JulianDate.j2000) - (2000 + 0.5 / 366)) < 1e-12)
    // 1900-01-01 00:00 (JD 2415020.5), a non-leap century year.
    #expect(abs(DeltaT.decimalYear(of: JulianDate(days: 2_415_020.5)) - 1900.0) < 1e-12)
    // 1899-12-31 12:00 is just before it.
    #expect(DeltaT.decimalYear(of: JulianDate(days: 2_415_020.0)) < 1900.0)
  }

  @Test func secondsAtJulianDate() {
    #expect(abs(DeltaT.seconds(at: JulianDate(days: 2_451_544.5)) - 63.86) < 1e-9)
    #expect(abs(DeltaT.seconds(at: JulianDate(days: 2_415_020.5)) - -2.79) < 1e-9)
    // 1950-01-01 00:00
    #expect(abs(DeltaT.seconds(at: JulianDate(days: 2_433_282.5)) - 29.07) < 1e-9)
  }

  // MARK: Leap seconds

  @Test func tableMatchesCalendarDates() throws {
    #expect(LeapSeconds.table.count == 28)
    for entry in LeapSeconds.table {
      let jd = try #require(JulianDate(DateComponents(year: entry.year, month: entry.month, day: 1)))
      #expect(abs(jd.days - entry.jd) < 1e-9, "\(entry.year)-\(entry.month)")
    }
    // Strictly increasing dates, TAI - UTC increases by exactly one each time.
    for (a, b) in zip(LeapSeconds.table, LeapSeconds.table.dropFirst()) {
      #expect(b.jd > a.jd)
      #expect(b.taiMinusUTC == a.taiMinusUTC + 1)
    }
    #expect(LeapSeconds.table.first?.taiMinusUTC == 10)
    #expect(LeapSeconds.latestTAIMinusUTC == 37)
  }

  @Test func ttMinusUTCAcross2017LeapSecond() throws {
    let boundary = try #require(JulianDate(DateComponents(year: 2017, month: 1, day: 1)))
    let before = JulianDate(days: boundary.days - 1e-6)
    let after = JulianDate(days: boundary.days + 1e-6)
    #expect(abs(LeapSeconds.ttMinusUTC(at: before) - 68.184) < 1e-12)
    #expect(abs(LeapSeconds.ttMinusUTC(at: boundary) - 69.184) < 1e-12)
    #expect(abs(LeapSeconds.ttMinusUTC(at: after) - 69.184) < 1e-12)
  }

  @Test func ttMinusUTCAtKnownEpochs() {
    // J2000.0 is 2000-01-01 12:00 TT; TAI - UTC was 32 s then.
    #expect(abs(JulianDate.j2000.ttMinusUTCSeconds - 64.184) < 1e-12)
    // 1972-01-01: 10 + 32.184
    #expect(abs(LeapSeconds.ttMinusUTC(at: LeapSeconds.firstEpoch) - 42.184) < 1e-12)
    // Last value is held for the future.
    #expect(abs(LeapSeconds.ttMinusUTC(at: JulianDate(days: 2_500_000)) - 69.184) < 1e-12)
    // 2026-11-17
    #expect(abs(JulianDate(days: 2_461_357.5).ttMinusUTCSeconds - 69.184) < 1e-12)
  }

  @Test func beforeLeapSecondEraUsesDeltaT() {
    let jd = JulianDate(days: 2_433_282.5)  // 1950-01-01
    #expect(LeapSeconds.taiMinusUTC(at: jd) == nil)
    #expect(abs(LeapSeconds.ttMinusUTC(at: jd) - DeltaT.seconds(at: jd)) < 1e-12)
    // Roughly continuous with the first leap-second value (42.184 s at 1972-01-01).
    let justBefore = JulianDate(days: LeapSeconds.firstEpoch.days - 1e-6)
    #expect(abs(LeapSeconds.ttMinusUTC(at: justBefore) - 42.184) < 0.5)
  }

  // MARK: JulianDate conversion

  @Test func terrestrialTimeFromUTC() {
    let utc = JulianDate(utcDate(2025, 9, 7, 18, 12))
    let tt = utc.terrestrialTime
    #expect(abs((tt.days - utc.days) * 86_400 - 69.184) < 1e-4)
    #expect(JulianDate(terrestrialTimeFromUTC: utc) == tt)
    // 1999-12-31 23:59:59 is in the 32 s era; 2000-01-01 12:00 UTC is 64.184 s before J2000 TT.
    let j2000UTC = JulianDate(utcDate(2000, 1, 1, 12))
    #expect(abs(j2000UTC.terrestrialTime.days - JulianDate.j2000.days - 64.184 / 86_400) < 1e-9)
  }

  @Test func terrestrialTimeRoundTrips() {
    for days in [2_433_282.5, 2_441_317.5, 2_448_000.1, 2_457_754.5, 2_457_754.5 - 1.0 / 86_400 * 40, 2_461_000.0] {
      let utc = JulianDate(days: days)
      let back = utc.terrestrialTime.utcFromTerrestrialTime
      #expect(abs(back.days - utc.days) * 86_400 < 1e-3, "\(days)")
    }
  }

  @Test func defaultBehaviourIsUnchanged() {
    // Existing APIs still read a Julian date as-is; nothing converts implicitly.
    let utc = JulianDate(utcDate(2026, 8, 12, 17, 46))
    #expect(utc.days == JulianDate(utcDate(2026, 8, 12, 17, 46)).days)
    #expect(utc.terrestrialTime > utc)
  }

  @Test func publicTypesAreSendable() {
    func requireSendable<T: Sendable>(_: T.Type) {}
    requireSendable(JulianDate.self)
    requireSendable(LeapSeconds.Entry.self)
  }
}
