import Foundation
import Testing
@testable import Astral

@Suite("JulianDate", .tags(.ephemeris, .time, .fast))
struct JulianDateTests {
  @Test func j2000MapsToJD2451545() {
    let date = utcDate(2000, 1, 1, 12, 0, 0)
    let jd = JulianDate(date)
    #expect(abs(jd.days - 2_451_545.0) < 1e-9)
    #expect(jd.centuriesSinceJ2000.magnitude < 1e-12)
  }

  @Test func roundTripsDateToJDToDate() {
    for date in [utcDate(2000, 1, 1, 12), utcDate(1900, 1, 1, 12), utcDate(2026, 11, 14, 12, 34, 56)] {
      let back = JulianDate(date).date
      #expect(abs(back.timeIntervalSince(date)) < 1e-3)
    }
  }

  @Test func roundTripsJDToDateToJD() {
    for days in [2_415_021.0, 2_451_545.0, 2_461_359.0, 2_460_925.2583] {
      #expect(abs(JulianDate(JulianDate(days: days).date).days - days) < 1e-8)
    }
  }

  @Test func centuriesSinceJ2000() {
    #expect(abs(JulianDate(days: 2_451_545.0 + 36_525).centuriesSinceJ2000 - 1) < 1e-12)
    #expect(abs(JulianDate(days: 2_451_545.0 - 36_525 / 2).centuriesSinceJ2000 + 0.5) < 1e-12)
  }

  @Test func comparableAndSupportedRange() {
    #expect(JulianDate(days: 1) < JulianDate(days: 2))
    #expect(JulianDate(days: Epoch.jd2000).isInSupportedRange)
    #expect(!JulianDate(JulianDate.j2000.date.addingTimeInterval(-300 * 365.25 * 86_400)).isInSupportedRange)
  }

  @Test func isHashable() {
    let set: Set<JulianDate> = [JulianDate(days: 1), JulianDate(days: 1), JulianDate(days: 2)]
    #expect(set.count == 2)
  }

  // MARK: Bridges to Astral's existing Julian day code

  /// `JulianDate(Date)` (Unix epoch arithmetic) and Astral's `julianDay(at:)` (Meeus calendar algorithm) are two
  /// independent routes to the same number.
  @Test(arguments: [
    DateComponents.datetime(2000, 1, 1, 12, 0, 0),
    DateComponents.datetime(1900, 1, 1, 12, 0, 0),
    DateComponents.datetime(2026, 11, 14, 12, 34, 56),
    DateComponents.datetime(1969, 7, 20, 20, 17, 40),
    DateComponents.datetime(2040, 3, 3, 3, 0, 0),
    DateComponents.date(1987, 6, 19),
    DateComponents.date(2023, 1, 21),
  ])
  func agreesWithAstralJulianDay(components: DateComponents) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let date = try #require(calendar.date(from: components))

    let fromDate = JulianDate(date).days
    let fromAstral = julianDay(at: components)
    #expect(abs(fromDate - fromAstral) < 1e-8, "Date route \(fromDate) vs julianDay(at:) \(fromAstral)")

    let fromComponents = try #require(JulianDate(components))
    #expect(fromComponents.days == fromAstral)
    #expect(abs(fromComponents.days - fromDate) < 1e-8)
    #expect(abs(fromComponents.centuriesSinceJ2000 - julianDayToCentury(julianDay: fromAstral)) < 1e-15)
  }

  @Test func componentsInitRequiresYearMonthDay() {
    #expect(JulianDate(DateComponents(year: 2000, month: 1)) == nil)
    #expect(JulianDate(DateComponents(hour: 12)) == nil)
    #expect(JulianDate(DateComponents(year: 2000, month: 1, day: 1, hour: 12))?.days == 2_451_545.0)
  }

  @Test func agreesWithDateToJC() {
    let date = utcDate(2026, 11, 14, 12)
    #expect(abs(JulianDate(date).centuriesSinceJ2000 - date.toJC2000) < 1e-12)
  }
}
