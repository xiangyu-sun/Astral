// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import Testing

@Suite("Solar eclipses: local circumstances vs NASA calculator", .tags(.solar, .accuracy, .integration))
struct SolarLocalCircumstancesTests {
  @Test(arguments: solarCases())
  func matchesNASA(testCase: SolarCase) throws {
    let fixture = try SolarFixture.load()
    let eclipse = try #require(fixture.eclipses.first { $0.label == testCase.eclipse })
    let site = try #require(eclipse.sites.first { $0.name == testCase.site })
    let observer = Observer(latitude: site.lat, longitude: site.lon, elevation: .double(0))
    let result = eclipse.besselian.localCircumstances(observer: observer)
    guard site.type != "none" else {
      #expect(result == nil)
      return
    }
    let local = try #require(result)
    func seconds(_ d: Date) -> Double {
      d.timeIntervalSince(eclipse.midnightUT)
    }
    var line = "SOLAR \(testCase.testDescription): type \(local.type) (NASA \(site.type))"
    func check(_ name: String, _ c: SolarEclipseContact?, _ ref: SolarFixture.Snapshot?) {
      guard let ref else { return }
      guard let c else { line += " \(name) MISSING"
        Issue.record("\(name) missing")
        return
      }
      let dt = seconds(c.date) - ref.utSeconds
      let dalt = c.sunAltitude - ref.altitudeDeg
      var daz = c.sunAzimuth - ref.azimuthDeg
      daz = (daz + 540).truncatingRemainder(dividingBy: 360) - 180
      line += String(format: " %@ dt %.3fs dalt %.4f daz %.4f;", name, dt, dalt, daz)
      #expect(abs(dt) < 0.01, "\(name) time")
      #expect(abs(dalt) < 0.001, "\(name) altitude")
      #expect(abs(daz) < 0.001, "\(name) azimuth")
    }
    #expect(local.type.rawValue == site.type)
    check("C1", local.c1, site.c1)
    check("C2", local.c2, site.c2)
    check("max", local.maximum, site.mid)
    check("C3", local.c3, site.c3)
    check("C4", local.c4, site.c4)
    if let mag = site.magnitude {
      line += String(format: " dMag %.6f", local.magnitude - mag)
      #expect(abs(local.magnitude - mag) < 1e-6)
    }
    if let obs = site.obscuration {
      line += String(format: " dObsc %.5f", local.obscuration - obs)
      #expect(abs(local.obscuration - obs) < 1e-4)
    }
    print(line)
  }

  /// Secondary, independent cross-check: published local times (timeanddate.com, to the minute) converted to UT.
  @Test
  func agreesWithPublishedLocalTimes() throws {
    let catalog = BesselianElements.catalog
    func minutes(_: SolarEclipseLocalCircumstances, _ c: SolarEclipseContact, _ midnight: Date) -> Double {
      c.date.timeIntervalSince(midnight) / 60
    }
    // Dallas 2024-04-08, CDT = UT-5: partial 12:23-15:02, maximum 13:42, magnitude 1.015, totality 3m52s.
    let dallas = try #require(catalog.first { $0.label == "2024-04-08" }?
      .localCircumstances(observer: Observer(latitude: 32.7767, longitude: -96.797, elevation: .double(0))))
    let d0 = utcMidnight("2024-04-08")
    #expect(abs(minutes(dallas, dallas.c1, d0) - (12 * 60 + 23 + 300)) < 1)
    #expect(abs(minutes(dallas, dallas.maximum, d0) - (13 * 60 + 42 + 300)) < 1)
    #expect(abs(minutes(dallas, dallas.c4, d0) - (15 * 60 + 2 + 300)) < 1)
    #expect(abs(dallas.magnitude - 1.015) < 0.0006)
    #expect(abs(try #require(dallas.centralDuration) - 232) < 3) // NASA 3m50.3s, timeanddate 3m52s
    // Barcelona 2026-08-12, CEST = UT+2: partial begins 19:35, maximum 20:29, magnitude 0.997 (just short of totality).
    let barcelona = try #require(catalog.first { $0.label == "2026-08-12" }?.localCircumstances(observer: .barcelona))
    let b0 = utcMidnight("2026-08-12")
    #expect(barcelona.type == .partial)
    #expect(abs(minutes(barcelona, barcelona.c1, b0) - (19 * 60 + 35 - 120)) < 1)
    #expect(abs(minutes(barcelona, barcelona.maximum, b0) - (20 * 60 + 29 - 120)) < 1)
    // C4 happens with the Sun below the horizon (altitude -5°); timeanddate stops at sunset (20:54 CEST), so not compared.
    #expect(!barcelona.c4.isSunAboveHorizon)
    #expect(abs(barcelona.magnitude - 0.997) < 0.0006)
    #expect(barcelona.maximum.sunAltitude > 0 && barcelona.maximum.sunAltitude < 6)
  }
}
