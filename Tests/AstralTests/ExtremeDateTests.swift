import Foundation
import Testing
@testable import Astral

@Suite("Extreme Date Tests", .tags(.edge, .accuracy))
struct ExtremeDateTests {

  @Test("Julian Day calculation for year 1900", .tags(.conversion, .unit))
  func julianDay1900() {
    let dc = DateComponents.date(1900, 1, 1)
    let jd = julianDay(at: dc)
    // JD for 1900-01-01 12:00 UT is 2415021.0
    // At midnight: 2415020.5
    #expect(abs(jd - 2415020.5) < 1)
  }

  @Test("Julian Day calculation for year 2100", .tags(.conversion, .unit))
  func julianDay2100() {
    let dc = DateComponents.date(2100, 1, 1)
    let jd = julianDay(at: dc)
    // JD for 2100-01-01 ≈ 2488069.5
    #expect(abs(jd - 2488069.5) < 1)
  }

  @Test("Sun apparent longitude reasonable for 1900", .tags(.accuracy, .unit))
  func sunApparentLong1900() {
    let dc = DateComponents.date(1900, 6, 21)
    let jd = julianDay(at: dc)
    let jc = julianDayToCentury(julianDay: jd)
    let result = sun_apparent_long(juliancentury: jc)
    // Summer solstice: Sun near 90° ecliptic longitude
    let normalized = (result.truncatingRemainder(dividingBy: 360) + 360)
      .truncatingRemainder(dividingBy: 360)
    #expect(abs(normalized - 90.0) < 2.0)
  }

  @Test("Sun apparent longitude reasonable for 2100", .tags(.accuracy, .unit))
  func sunApparentLong2100() {
    let dc = DateComponents.date(2100, 3, 20)
    let jd = julianDay(at: dc)
    let jc = julianDayToCentury(julianDay: jd)
    let result = sun_apparent_long(juliancentury: jc)
    // Vernal equinox: Sun near 0° ecliptic longitude
    let normalized = (result.truncatingRemainder(dividingBy: 360) + 360)
      .truncatingRemainder(dividingBy: 360)
    #expect(normalized < 3.0 || normalized > 357.0)
  }

  @Test("Moon position reasonable for 1900", .tags(.accuracy, .unit))
  func moonPosition1900() {
    let dc = DateComponents.date(1900, 1, 1)
    let jd = julianDay(at: dc)
    let jd2000 = jd - 2451545.0
    let pos = moonPosition(jd2000: jd2000)
    // Moon distance should be reasonable (55-65 Earth radii)
    #expect(pos.distance > 50 && pos.distance < 70)
    // Declination within ±30°
    #expect(abs(pos.declination) < 0.6)
  }

  @Test("Moon position reasonable for 2100", .tags(.accuracy, .unit))
  func moonPosition2100() {
    let dc = DateComponents.date(2100, 1, 1)
    let jd = julianDay(at: dc)
    let jd2000 = jd - 2451545.0
    let pos = moonPosition(jd2000: jd2000)
    #expect(pos.distance > 50 && pos.distance < 70)
    #expect(abs(pos.declination) < 0.6)
  }

  @Test("Moon phase reasonable for historical dates", .tags(.accuracy, .unit))
  func moonPhaseHistorical() {
    // Moon phase should always be in [0, 29.53]
    let dates = [
      DateComponents.date(1900, 1, 1),
      DateComponents.date(1950, 6, 15),
      DateComponents.date(2000, 1, 1),
      DateComponents.date(2050, 12, 31),
    ]
    for date in dates {
      let phase = moonPhase(date: date)
      #expect(phase >= 0 && phase < 29.531)
    }
  }

  @Test("Solar term calculation reasonable for year 2050", .tags(.accuracy, .integration))
  func solarTerm2050() {
    var components = DateComponents()
    components.year = 2050
    components.month = 6
    components.day = 21
    components.hour = 12
    components.timeZone = TimeZone(secondsFromGMT: 0)
    let date = Calendar(identifier: .gregorian).date(from: components)!
    let term = currentSolarTerm(for: date)
    // Near summer solstice: term ~ 6.5
    #expect(abs(term - 6.5) < 1.0)
  }

  @Test("Sunrise at London for boundary dates", .tags(.transit, .integration))
  func sunriseBoundaryDates() throws {
    // Leap year Feb 29
    let leapDate = DateComponents.date(2024, 2, 29)
    let sr = try sunrise(observer: .london, date: leapDate)
    #expect(sr.hour != nil)
    #expect(sr.hour! >= 5 && sr.hour! <= 8) // Reasonable for late Feb London

    // Dec 31
    let newYearsEve = DateComponents.date(2023, 12, 31)
    let sr2 = try sunrise(observer: .london, date: newYearsEve)
    #expect(sr2.hour != nil)
    #expect(sr2.hour! >= 7 && sr2.hour! <= 9) // Winter in London
  }

  @Test("Nutation remains bounded for extreme centuries", .tags(.accuracy, .unit))
  func nutationBounded() {
    // Test that nutation values remain physically reasonable
    // even for dates far from J2000.0
    let centuries = [-10.0, -5.0, -1.0, 0.0, 1.0, 5.0, 10.0]
    for T in centuries {
      let nut = nutation(juliancentury: T)
      // Nutation in longitude: max ~±18" (historical range)
      #expect(abs(nut.longitude) < 25.0)
      // Nutation in obliquity: max ~±10"
      #expect(abs(nut.obliquity) < 15.0)
    }
  }
}
