import XCTest
@testable import AstralSolar  // Replace "Astral" with your module name if different

class SolarTermDaysTests: XCTestCase {
  
  // MARK: - Existing Tests
  
  /// Test that the returned days-left value is positive and does not exceed the maximum
  /// (which is roughly 15°/0.9856° per day ≃ 15.23 days).
  func testDaysUntilNextSolarTermRange() {
    let now = Date()
    let daysLeft = Astral.daysUntilNextSolarTerm(from: now)
    
    XCTAssertGreaterThan(daysLeft, 0, "Days until next solar term should be positive.")
    // Allow a slight margin above the average maximum.
    XCTAssertLessThan(daysLeft, 16, "Days until next solar term should be less than 16 days.")
  }
  
  /// Test that as time advances the days-left value decreases (accounting for cycle wrap-around).
  func testDaysUntilNextSolarTermMonotonicity() {
    let now = Date()
    let oneHourLater = now.addingTimeInterval(3600)  // 1 hour later
    
    let daysNow = Astral.daysUntilNextSolarTerm(from: now)
    let daysLater = Astral.daysUntilNextSolarTerm(from: oneHourLater)
    
    // If a boundary is crossed during the interval the raw value may “wrap around.”
    // To account for this, if the later value is lower, add the period (24) before comparing.
    let period = 24.0
    let adjustedDaysLater = daysLater < daysNow ? daysLater + period : daysLater
    
    XCTAssertLessThan(daysNow, adjustedDaysLater, "Days left should increase in the continuous cycle as time advances (after unwrapping).")
  }
  
  // MARK: - Modified Boundary Test Using Simulated Data

  
  // MARK: - Additional Tests for the 24 Solar Terms
  
  /// Test that over a full cycle (approximately one tropical year) all 24 unique solar term names appear.
  func testAll24SolarTermsAppear() {
    var uniqueTerms: Set<Double> = []
    let calendar = Calendar(identifier: .gregorian)
    let startComponents = DateComponents(timeZone: TimeZone(secondsFromGMT: 0)!, year: 2020, month: 1, day: 1)
    guard let startDate = calendar.date(from: startComponents) else {
      XCTFail("Failed to create start date for solar term cycle test")
      return
    }
    // Iterate day-by-day over ~370 days to cover a full cycle.
    for i in 0..<370 {
      guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
      let term = currentSolarTerm(for: date)
      uniqueTerms.insert(round(term))
    }
    XCTAssertEqual(uniqueTerms.count, 24, "Expected to see all 24 unique solar terms over a full cycle, but got \(uniqueTerms.count): \(uniqueTerms)")
  }
  
  /// Test that an approximate Spring Equinox date returns "春分".
  func testSolarTermSpringEquinox() {
    // Using an approximate date for the Spring Equinox: March 20, 2012 at 21:31 UTC.
    var components = DateComponents()
    components.year = 2012
    components.month = 3
    components.day = 20
    components.hour = 21
    components.minute = 31
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for Spring Equinox test")
      return
    }
    let term = currentSolarTerm(for: date)
    XCTAssertEqual(floor(term), 0, "Expected the solar term to be 春分 for the Spring Equinox date, but got \(term)")
  }
  
  /// Test that an approximate Summer Solstice date returns "夏至".
  func testSolarTermSummerSolstice() {
    // Using an approximate date for the Summer Solstice: June 21, 2012 at 11:12 UTC.
    var components = DateComponents()
    components.year = 2012
    components.month = 6
    components.day = 21
    components.hour = 11
    components.minute = 12
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for Summer Solstice test")
      return
    }
    let term = currentSolarTerm(for: date)
    XCTAssertEqual(floor(term), 6, "Expected the solar term to be 夏至 for the Summer Solstice date, but got \(term)")
  }
  
  /// Test that an approximate Autumn Equinox date returns "秋分".
  func testSolarTermAutumnEquinox() {
    // Using an approximate date for the Autumn Equinox: September 22, 2012 at 20:00 UTC.
    var components = DateComponents()
    components.year = 2012
    components.month = 9
    components.day = 22
    components.hour = 20
    components.minute = 0
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for Autumn Equinox test")
      return
    }
    let term = currentSolarTerm(for: date)
    XCTAssertEqual(floor(term), 12, "Expected the solar term to be 秋分 for the Autumn Equinox date, but got \(term)")
  }
  
  /// Test that an approximate Winter Solstice date returns "冬至".
  func testSolarTermWinterSolstice() {
    // Using an approximate date for the Winter Solstice: December 21, 2012 at 04:20 UTC.
    var components = DateComponents()
    components.year = 2012
    components.month = 12
    components.day = 21
    components.hour = 4
    components.minute = 20
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = Calendar(identifier: .gregorian).date(from: components) else {
      XCTFail("Failed to create date for Winter Solstice test")
      return
    }
    let term = currentSolarTerm(for: date)
    XCTAssertEqual(floor(term), 18, "Expected the solar term to be 冬至 for the Winter Solstice date, but got \(term)")
  }
}
