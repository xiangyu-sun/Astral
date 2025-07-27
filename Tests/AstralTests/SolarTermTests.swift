import XCTest
@testable import Astral // Replace with your module name if different

class SolarTermTests: XCTestCase {

  // MARK: Internal

  /// Test that for a date near the vernal equinox the computed solar term is close to 0.5.
  func testVernalEquinox() {
    // Example: March 20, 2012 at 16:09 UTC is near the vernal equinox.
    var components = DateComponents()
    components.year = 2012
    components.month = 3
    components.day = 20
    components.hour = 16
    components.minute = 9
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for vernal equinox test")
      return
    }

    let term = currentSolarTerm(for: date)
    // At exact 0° longitude the formula gives 0.5; we allow a tolerance of ±0.5.
    XCTAssertEqual(term, 0.5, accuracy: 0.5, "Solar term near vernal equinox should be approximately 0.5")
  }

  func test2025Guyu() {
    var components = DateComponents()
    components.year = 2025
    components.month = 4
    components.day = 20
    components.hour = 15
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for summer solstice test")
      return
    }

    let term = currentSolarTerm(for: date)

    XCTAssertEqual(term, 2.5, accuracy: 0.5, "Solar term near summer solstice should be approximately 2.5")
  }

  func test2025Guyu15DaysToXiaZhi() {
    var components = DateComponents()
    components.year = 2025
    components.month = 4
    components.day = 20
    components.hour = 15

    components.timeZone = TimeZone(secondsFromGMT: 0)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let result = calendar.dateComponents(
      [.year, .month, .day, .hour],
      from: preciseNextSolarTermDate(from: calendar.date(from: components)!))

    var componentsXiazhi = DateComponents()
    componentsXiazhi.year = 2025
    componentsXiazhi.month = 5
    componentsXiazhi.day = 5
    componentsXiazhi.hour = 5
    componentsXiazhi.isLeapMonth = false

    XCTAssertEqual(result, componentsXiazhi)
  }

  func test2025XiaZhi() {
    var components = DateComponents()
    components.year = 2025
    components.month = 5
    components.day = 4
    components.hour = 15
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for summer solstice test")
      return
    }

    let term = currentSolarTerm(for: date)

    XCTAssertEqual(term, 3.5, accuracy: 0.5, "Solar term near summer solstice should be approximately 2.5")
  }

  /// Test that for a date near the summer solstice the computed solar term is close to 6.5.
  func testSummerSolstice() {
    // Example: June 21, 2012 at 11:12 UTC is near the summer solstice.
    var components = DateComponents()
    components.year = 2012
    components.month = 6
    components.day = 21
    components.hour = 11
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for summer solstice test")
      return
    }

    let term = currentSolarTerm(for: date)
    // At 90° the formula gives (90+7.5)/15 = 97.5/15 = 6.5.
    XCTAssertEqual(term, 6.5, accuracy: 0.5, "Solar term near summer solstice should be approximately 6.5")
  }

  /// Test that for a date near the autumn equinox the computed solar term is close to 12.5.
  func testAutumnEquinox() {
    // Example: September 22, 2012 at 20:00 UTC is near the autumn equinox.
    var components = DateComponents()
    components.year = 2012
    components.month = 9
    components.day = 22
    components.hour = 20
    components.minute = 0
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for autumn equinox test")
      return
    }

    let term = currentSolarTerm(for: date)
    // At 180° the formula gives (180+7.5)/15 = 187.5/15 = 12.5.
    XCTAssertEqual(term, 12.5, accuracy: 0.5, "Solar term near autumn equinox should be approximately 12.5")
  }

  /// Test that for a date near the winter solstice the computed solar term is close to 18.5.
  func testWinterSolstice() {
    // Example: December 21, 2012 at 4:20 UTC is near the winter solstice.
    var components = DateComponents()
    components.year = 2012
    components.month = 12
    components.day = 21
    components.hour = 4
    components.minute = 20
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for winter solstice test")
      return
    }

    let term = currentSolarTerm(for: date)
    // At 270° the formula gives (270+7.5)/15 = 277.5/15 = 18.5.
    XCTAssertEqual(term, 18.5, accuracy: 0.5, "Solar term near winter solstice should be approximately 18.5")
  }

  /// Test that the solar term value increases with time, accounting for the cycle wrap-around.
  func testMonotonicity() {
    // Compare two consecutive days.
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
    // if the later value is numerically lower, adjust it by adding 24.
    let period = 24.0
    let adjustedTerm2 = (term2 < term1 ? term2 + period : term2)

    XCTAssertLessThan(term1, adjustedTerm2, "Solar term value should increase as time advances (accounting for wrap-around)")
  }

  /// Test that the calculation is independent of the local time zone.
  func testTimeZoneIndependence() {
    // Create a date in GMT+8 that corresponds to an equivalent UTC date.
    var componentsLocal = DateComponents()
    componentsLocal.year = 2012
    componentsLocal.month = 6
    componentsLocal.day = 21
    componentsLocal.hour = 19 // 19:00 in GMT+8 equals 11:00 UTC
    componentsLocal.minute = 12
    componentsLocal.second = 0
    componentsLocal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)

    guard let dateLocal = Calendar(identifier: .gregorian).date(from: componentsLocal) else {
      XCTFail("Failed to create local date")
      return
    }

    var componentsUTC = DateComponents()
    componentsUTC.year = 2012
    componentsUTC.month = 6
    componentsUTC.day = 21
    componentsUTC.hour = 11
    componentsUTC.minute = 12
    componentsUTC.second = 0
    componentsUTC.timeZone = TimeZone(secondsFromGMT: 0)

    guard let dateUTC = Calendar(identifier: .gregorian).date(from: componentsUTC) else {
      XCTFail("Failed to create UTC date")
      return
    }

    let termLocal = currentSolarTerm(for: dateLocal)
    let termUTC = currentSolarTerm(for: dateUTC)
    XCTAssertEqual(termLocal, termUTC, accuracy: 0.0001, "Solar term calculation should be independent of the local time zone")
  }

  /// Test that the returned solar term value is within the expected range.
  func testResultRange() {
    let now = Date()
    let term = currentSolarTerm(for: now)
    // Because normalizedLong is in [0, 360) then (normalizedLong + 7.5)/15 is in [0.5, 24.5).
    XCTAssertGreaterThanOrEqual(term, 0.5, "Solar term value should be at least 0.5")
    XCTAssertLessThan(term, 24.5, "Solar term value should be less than 24.5")
  }

  /// The preciseNextSolarTermDate should land exactly on a 15° boundary.
  /// Thus (normalizedLong + 7.5)/15 is an integer → fractional part == 0.
  func testPreciseNextSolarTermDateAlignsWithBoundary() {
    // Use some arbitrary “now”
    let baseline = Date(timeIntervalSince1970: 0)
    let boundaryDate = preciseNextSolarTermDate(from: baseline, iterations: 10)
    let term = currentSolarTerm(for: boundaryDate)
    let fractional = term.truncatingRemainder(dividingBy: 1.0)

    XCTAssertEqual(
      fractional,
      0.5,
      accuracy: 1e-4,
      "Expected exact boundary within 1e-4; got fractional part \(fractional)")
  }

  func testMonthOfCurrentSolarTerm_knownDates() {
    let testCases: [(date: String, expectedMonth: Int)] = [
      ("2021-12-21", 12), // Winter Solstice → December
      ("2022-01-05", 1), // Minor Cold  → January
      ("2022-03-20", 3), // Spring Equinox → March
      ("2022-06-21", 6), // Summer Solstice → June
      ("2022-09-23", 9), // Autumn Equinox → September
      ("2022-11-07", 11), // Minor Snow → November
    ]

    for (dateString, expected) in testCases {
      let date = formatter.date(from: dateString)!
      let month = monthOfCurrentSolarTerm(for: date)
      XCTAssertEqual(month, expected, "Expected month \(expected) for solar term on \(dateString), got \(month)")
    }
  }

  // MARK: Private

  private var formatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(abbreviation: "UTC")
    return df
  }()

}
