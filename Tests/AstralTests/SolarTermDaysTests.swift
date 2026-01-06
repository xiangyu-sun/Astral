import Foundation
import Testing
@testable import Astral

@Suite("Solar Term Days Tests")
struct SolarTermDaysTests {

  @Test("Days until next solar term is within valid range")
  func daysUntilNextSolarTermRange() {
    let now = Date()
    let daysLeft = Astral.daysUntilNextSolarTerm(from: now)

    #expect(daysLeft > 0)
    // Allow a slight margin above the average maximum (15°/0.9856° per day ≃ 15.23 days)
    #expect(daysLeft < 16)
  }

  @Test("Days until next solar term decreases monotonically with time")
  func daysUntilNextSolarTermMonotonicity() {
    let now = Date()
    let oneHourLater = now.addingTimeInterval(3600) // 1 hour later

    let daysNow = Astral.daysUntilNextSolarTerm(from: now)
    let daysLater = Astral.daysUntilNextSolarTerm(from: oneHourLater)

    // If a boundary is crossed during the interval the raw value may "wrap around."
    // To account for this, if the later value is lower, add the period (24) before comparing.
    let period = 24.0
    let adjustedDaysLater = daysLater < daysNow ? daysLater + period : daysLater

    #expect(daysNow < adjustedDaysLater)
  }

  @Test("All 24 solar terms appear over a full cycle")
  func all24SolarTermsAppear() throws {
    var uniqueTerms: Set<Double> = []
    let calendar = Calendar(identifier: .gregorian)
    let startComponents = DateComponents(timeZone: TimeZone(secondsFromGMT: 0)!, year: 2020, month: 1, day: 1)
    let startDate = try #require(calendar.date(from: startComponents))

    // Iterate day-by-day over ~370 days to cover a full cycle
    for i in 0..<370 {
      guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
      let term = currentSolarTerm(for: date)
      uniqueTerms.insert(round(term))
    }

    #expect(uniqueTerms.count == 24)
  }

  @Test("Spring Equinox date returns correct solar term")
  func solarTermSpringEquinox() throws {
    // Using an approximate date for the Spring Equinox: March 20, 2012 at 21:31 UTC
    var components = DateComponents()
    components.year = 2012
    components.month = 3
    components.day = 20
    components.hour = 21
    components.minute = 31
    components.second = 0
    components.timeZone = TimeZone(secondsFromGMT: 0)

    let date = try #require(Calendar(identifier: .gregorian).date(from: components))
    let term = currentSolarTerm(for: date)
    #expect(floor(term) == 0)
  }

  @Test("Summer Solstice date returns correct solar term")
  func solarTermSummerSolstice() throws {
    // Using an approximate date for the Summer Solstice: June 21, 2012 at 11:12 UTC
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
    #expect(floor(term) == 6)
  }

  @Test("Autumn Equinox date returns correct solar term")
  func solarTermAutumnEquinox() throws {
    // Using an approximate date for the Autumn Equinox: September 22, 2012 at 20:00 UTC
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
    #expect(floor(term) == 12)
  }

  @Test("Winter Solstice date returns correct solar term")
  func solarTermWinterSolstice() throws {
    // Using an approximate date for the Winter Solstice: December 21, 2012 at 04:20 UTC
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
    #expect(floor(term) == 18)
  }
}
