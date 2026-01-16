import Foundation
import Testing
@testable import Astral

@Suite("Solar Term Calculation Tests", .tags(.solarTerm, .solar, .fast))
struct SolarTermTests {

  @Test("Vernal equinox solar term calculation", .tags(.conversion, .accuracy, .integration))
  func vernalEquinox() throws {
    var components = DateComponents()
    components.year = 2012
    components.month = 3
    components.day = 20
    components.hour = 16
    components.minute = 9
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    // At exact 0° longitude the formula gives 0.5; we allow a tolerance of ±0.5
    #expect(abs(term - 0.5) < 0.5)
  }

  @Test("Guyu solar term calculation (2025)", .tags(.conversion, .accuracy, .integration))
  func guyu2025() throws {
    var components = DateComponents()
    components.year = 2025
    components.month = 4
    components.day = 20
    components.hour = 15
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    #expect(abs(term - 2.5) < 0.5)
  }

  @Test("Guyu to Xiazhi - 15 days calculation", .tags(.conversion, .integration))
  func guyu15DaysToXiazhi() throws {
    var components = DateComponents()
    components.year = 2025
    components.month = 4
    components.day = 20
    components.hour = 15
    components.timeZone = TimeZone(secondsFromGMT: 0)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let date = try #require(calendar.date(from: components))
    let result = calendar.dateComponents(
      [.year, .month, .day, .hour],
      from: preciseNextSolarTermDate(from: date))

    var componentsXiazhi = DateComponents()
    componentsXiazhi.year = 2025
    componentsXiazhi.month = 5
    componentsXiazhi.day = 5
    componentsXiazhi.hour = 5
    componentsXiazhi.isLeapMonth = false

    #expect(result == componentsXiazhi)
  }

  @Test("Xiazhi solar term calculation (2025)", .tags(.conversion, .accuracy, .integration))
  func xiazhi2025() throws {
    var components = DateComponents()
    components.year = 2025
    components.month = 5
    components.day = 4
    components.hour = 15
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    #expect(abs(term - 3.5) < 0.5)
  }

  @Test("Summer solstice solar term calculation", .tags(.conversion, .accuracy, .integration))
  func summerSolstice() throws {
    var components = DateComponents()
    components.year = 2012
    components.month = 6
    components.day = 21
    components.hour = 11
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    // At 90° the formula gives (90+7.5)/15 = 97.5/15 = 6.5
    #expect(abs(term - 6.5) < 0.5)
  }

  @Test("Autumn equinox solar term calculation", .tags(.conversion, .accuracy, .integration))
  func autumnEquinox() throws {
    var components = DateComponents()
    components.year = 2012
    components.month = 9
    components.day = 22
    components.hour = 20
    components.minute = 0
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    // At 180° the formula gives (180+7.5)/15 = 187.5/15 = 12.5
    #expect(abs(term - 12.5) < 0.5)
  }

  @Test("Winter solstice solar term calculation", .tags(.conversion, .accuracy, .integration))
  func winterSolstice() throws {
    var components = DateComponents()
    components.year = 2012
    components.month = 12
    components.day = 21
    components.hour = 4
    components.minute = 20
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)

    // At 270° the formula gives (270+7.5)/15 = 277.5/15 = 18.5
    #expect(abs(term - 18.5) < 0.5)
  }

  @Test("Solar term increases monotonically with time", .tags(.validation, .unit))
  func monotonicity() {
    var components1 = DateComponents()
    components1.year = 2020
    components1.month = 3
    components1.day = 20
    components1.hour = 0
    components1.minute = 0
    components1.second = 0
    components1.timeZone = TimeZone(secondsFromGMT: 0)

    var components2 = components1
    components2.day = 21

    let date1 = Calendar(identifier: .gregorian).date(from: components1)!
    let date2 = Calendar(identifier: .gregorian).date(from: components2)!

    let term1 = currentSolarTerm(for: date1)
    let term2 = currentSolarTerm(for: date2)

    // Since the solar term value is cyclical with a period of 24,
    // if the later value is numerically lower, adjust it by adding 24
    let period = 24.0
    let adjustedTerm2 = (term2 < term1 ? term2 + period : term2)

    #expect(term1 < adjustedTerm2)
  }

  @Test("Solar term calculation is timezone independent", .tags(.time, .validation, .integration))
  func timeZoneIndependence() throws {
    // Create a date in GMT+8 that corresponds to an equivalent UTC date
    var componentsLocal = DateComponents()
    componentsLocal.year = 2012
    componentsLocal.month = 6
    componentsLocal.day = 21
    componentsLocal.hour = 19 // 19:00 in GMT+8 equals 11:00 UTC
    componentsLocal.minute = 12
    componentsLocal.second = 0
    componentsLocal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)

    let dateLocal = try #require(Calendar(identifier: .gregorian).date(from: componentsLocal))

    var componentsUTC = DateComponents()
    componentsUTC.year = 2012
    componentsUTC.month = 6
    componentsUTC.day = 21
    componentsUTC.hour = 11
    componentsUTC.minute = 12
    componentsUTC.second = 0
    componentsUTC.timeZone = TimeZone(secondsFromGMT: 0)

    let dateUTC = try #require(Calendar(identifier: .gregorian).date(from: componentsUTC))

    let termLocal = currentSolarTerm(for: dateLocal)
    let termUTC = currentSolarTerm(for: dateUTC)

    #expect(abs(termLocal - termUTC) < 0.0001)
  }

  @Test("Solar term value is within expected range", .tags(.validation, .unit))
  func resultRange() {
    let now = Date()
    let term = currentSolarTerm(for: now)

    // Because normalizedLong is in [0, 360) then (normalizedLong + 7.5)/15 is in [0.5, 24.5)
    #expect(term >= 0.5)
    #expect(term < 24.5)
  }

  @Test("Precise next solar term date aligns with boundary", .tags(.accuracy, .integration))
  func preciseNextSolarTermDateAlignsWithBoundary() {
    let baseline = Date(timeIntervalSince1970: 0)
    let boundaryDate = preciseNextSolarTermDate(from: baseline, iterations: 10)
    let term = currentSolarTerm(for: boundaryDate)
    let fractional = term.truncatingRemainder(dividingBy: 1.0)

    #expect(abs(fractional - 0.5) < 1e-4)
  }

  @Test(
    "Month of current solar term for known dates",
    .tags(.conversion, .integration),
    arguments: zip(
      ["2021-12-21", "2022-01-05", "2022-03-20", "2022-06-21", "2022-09-23", "2022-11-07"],
      [12, 1, 3, 6, 9, 11]))
  func monthOfCurrentSolarTermKnownDates(dateString: String, expectedMonth: Int) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(abbreviation: "UTC")

    let date = formatter.date(from: dateString)!
    let month = monthOfCurrentSolarTerm(for: date)

    #expect(month == expectedMonth)
  }

}
