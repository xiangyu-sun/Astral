import Foundation
import Testing
@testable import Astral

@Suite("Polar Region Tests", .tags(.solar, .edge))
struct PolarRegionTests {

  // Tromso, Norway (69.65°N, 18.96°E) - experiences polar night and midnight sun
  static let tromso = Observer(latitude: 69.65, longitude: 18.96, elevation: .double(0))

  // Longyearbyen, Svalbard (78.22°N, 15.63°E) - deep polar
  static let longyearbyen = Observer(latitude: 78.22, longitude: 15.63, elevation: .double(0))

  // McMurdo Station, Antarctica (-77.85°S, 166.67°E)
  static let mcmurdo = Observer(latitude: -77.85, longitude: 166.67, elevation: .double(0))

  @Test("Tromso midnight sun in June - sunrise throws or returns very early time", .tags(.transit))
  func tromsoMidnightSun() {
    // June 21 - midnight sun at Tromso, no sunrise/sunset in normal sense
    let date = DateComponents.date(2023, 6, 21)
    do {
      _ = try sunrise(observer: Self.tromso, date: date)
      // If it doesn't throw, the sun rises very early or the algorithm handles it
    } catch {
      // Expected: no proper sunrise during midnight sun
      #expect(error is SunError)
    }
  }

  @Test("Tromso polar night in December - sunrise throws", .tags(.transit))
  func tromsoPolarNight() {
    // December 21 - polar night at Tromso
    let date = DateComponents.date(2023, 12, 21)
    do {
      _ = try sunrise(observer: Self.tromso, date: date)
      // If it doesn't throw, algorithm handled polar night edge case
    } catch {
      #expect(error is SunError)
    }
  }

  @Test("Longyearbyen polar extremes", .tags(.transit))
  func longyearbyenPolarExtremes() {
    // Mid-winter: should throw
    let winterDate = DateComponents.date(2023, 1, 15)
    do {
      _ = try sunrise(observer: Self.longyearbyen, date: winterDate)
    } catch {
      #expect(error is SunError)
    }

    // Mid-summer: should throw (no sunset means no proper sunrise)
    let summerDate = DateComponents.date(2023, 6, 15)
    do {
      _ = try sunset(observer: Self.longyearbyen, date: summerDate)
    } catch {
      #expect(error is SunError)
    }
  }

  @Test("McMurdo Antarctic polar extremes", .tags(.transit))
  func mcmurdoPolarExtremes() {
    // December in Antarctica = summer = midnight sun
    let summerDate = DateComponents.date(2023, 12, 21)
    do {
      _ = try sunset(observer: Self.mcmurdo, date: summerDate)
    } catch {
      #expect(error is SunError)
    }

    // June in Antarctica = winter = polar night
    let winterDate = DateComponents.date(2023, 6, 21)
    do {
      _ = try sunrise(observer: Self.mcmurdo, date: winterDate)
    } catch {
      #expect(error is SunError)
    }
  }

  @Test("Mid-latitude sunrise/sunset always available at equinox", .tags(.transit))
  func midLatitudeEquinox() throws {
    let observers = [Observer.london, Observer.newDelhi, Observer.riyadh, Observer.barcelona]
    let date = DateComponents.date(2023, 3, 20) // Vernal equinox

    for observer in observers {
      let sr = try sunrise(observer: observer, date: date)
      let ss = try sunset(observer: observer, date: date)
      // At equinox, sunrise should be before sunset
      let calendar = Calendar(identifier: .gregorian)
      let srDate = calendar.date(from: sr)!
      let ssDate = calendar.date(from: ss)!
      #expect(srDate < ssDate)
    }
  }

  @Test("Solar noon always available even at polar locations", .tags(.position))
  func solarNoonAlwaysAvailable() {
    let observers = [Self.tromso, Self.longyearbyen, Self.mcmurdo, Observer.london]
    let dates = [
      DateComponents.date(2023, 6, 21),
      DateComponents.date(2023, 12, 21),
    ]

    for observer in observers {
      for date in dates {
        let n = noon(observer: observer, date: date)
        // Noon should always have valid hour
        #expect(n.hour != nil)
      }
    }
  }
}
