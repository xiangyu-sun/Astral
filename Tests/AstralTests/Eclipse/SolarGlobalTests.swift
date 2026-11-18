// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import Testing

// MARK: - SolarGlobalFixture

struct SolarGlobalFixture: Decodable {
  struct Entry: Decodable, Sendable {
    let label: String
    let type: String
    let gamma: Double
    let magnitude: Double
    let deltaT: Double
    let greatestTDTJulianDate: Double
    let greatestUTSeconds: Double
    let latitude: Double?
    let longitude: Double?
    let sunAltitude: Double?
    let pathWidthKm: Double?
    let sunAzimuth: Double?
    let centralDurationSeconds: Double?
  }

  let eclipses: [Entry]

  static func load() throws -> SolarGlobalFixture {
    try JSONDecoder().decode(SolarGlobalFixture.self, from: EclipseFixture.data("solar_global"))
  }
}

func solarGlobalLabels() -> [String] {
  (try? SolarGlobalFixture.load())?.eclipses.map(\.label) ?? []
}

// MARK: - SolarGlobalTests

@Suite("Solar eclipses: Besselian elements and global circumstances", .tags(.solar, .accuracy))
struct SolarGlobalTests {
  @Test
  func catalogCoversTwentyThreeToThirtyFive() {
    let catalog = BesselianElements.catalog
    #expect(catalog.count == 28)
    #expect(catalog.map(\.label) == catalog.map(\.label).sorted())
    #expect(catalog.first?.label == "2023-04-20")
    #expect(catalog.last?.label == "2035-09-02")
    for e in catalog {
      #expect(e.x.count == 4 && e.y.count == 4 && e.d.count == 3 && e.mu.count == 2 && e.l1.count == 3 && e.l2.count == 3)
      #expect(e.deltaT > 60 && e.deltaT < 90)
    }
  }

  @Test(arguments: solarGlobalLabels())
  func globalCircumstancesMatchNASA(label: String) throws {
    let fixture = try SolarGlobalFixture.load()
    let ref = try #require(fixture.eclipses.first { $0.label == label })
    let e = try #require(BesselianElements.catalog.first { $0.label == label })
    let g = e.greatestEclipse

    #expect(e.eclipseType.rawValue == ref.type, "type of \(label)")
    #expect(e.publishedType?.rawValue == ref.type)

    var utSeconds = g.date.timeIntervalSince(utcMidnight(label))
    if abs(utSeconds - ref.greatestUTSeconds) > 43_200 { utSeconds -= utSeconds > 43_200 ? 86_400 : -86_400 }
    let dt = utSeconds - ref.greatestUTSeconds
    let dTT = (g.terrestrialTime.days - ref.greatestTDTJulianDate) * 86_400
    let dGamma = abs(g.gamma) - abs(ref.gamma)
    let dMag = g.magnitude - ref.magnitude
    var line = String(format: "GLOBAL %@ %@: dUT %.2fs dTT %.2fs dGamma %.5f dMag %.5f", label, ref.type, dt, dTT, dGamma, dMag)
    #expect(abs(dt) < 0.2)
    #expect(abs(dTT) < 0.1)
    #expect(abs(dGamma) < 6e-5)
    #expect(g.gamma.sign == ref.gamma.sign)
    if ref.type == "partial" {
      #expect(!g.isCentral)
      #expect(abs(dMag) < 2e-4)
    } else {
      #expect(g.isCentral)
      #expect(abs(dMag) < 1e-4)
    }
    if let lat = ref.latitude, let lon = ref.longitude, let alt = ref.sunAltitude, let dur = ref.centralDurationSeconds {
      let dLat = g.latitude - lat
      var dLon = g.longitude - lon
      dLon = (dLon + 540).truncatingRemainder(dividingBy: 360) - 180
      let dAlt = g.sunAltitude - alt
      let dDur = (g.centralDuration ?? .nan) - dur
      line += String(format: " dLat %.4f dLon %.4f dAlt %.3f dDur %.2fs", dLat, dLon, dAlt, dDur)
      #expect(abs(dLat) < 0.003, "latitude")
      #expect(abs(dLon) < 0.003, "longitude")
      #expect(abs(dAlt) < 0.1, "altitude")
      #expect(abs(dDur) < 0.6, "central duration")
    }
    print(line)
  }

  @Test
  func localFixtureElementsAgreeWithCatalog() throws {
    // The 8-digit elements of NASA's Google-map pages and the 6/7-digit elements of the Besselian pages describe the same fit.
    let fixture = try SolarFixture.load()
    for f in fixture.eclipses {
      let c = try #require(BesselianElements.catalog.first { $0.label == f.label })
      let a = f.besselian
      #expect(abs(c.t0.days - a.t0.days) * 86_400 < 1e-3)
      #expect(c.deltaT == a.deltaT)
      for t in stride(from: -3.0, through: 3.0, by: 1.0) {
        for (p, q) in [(c.x, a.x), (c.y, a.y), (c.d, a.d), (c.l1, a.l1), (c.l2, a.l2)] {
          let vp = p.enumerated().reduce(0) { $0 + $1.element * pow(t, Double($1.offset)) }
          let vq = q.enumerated().reduce(0) { $0 + $1.element * pow(t, Double($1.offset)) }
          #expect(abs(vp - vq) < 1e-5, "\(f.label) t=\(t)")
        }
      }
    }
  }

  @Test
  func catalogLocalCircumstancesAgreeWithFixtureElements() throws {
    // Same sites computed with the (rounded) catalog elements: shows what the built-in table costs in accuracy.
    let fixture = try SolarFixture.load()
    var worst = 0.0
    for f in fixture.eclipses {
      let c = try #require(BesselianElements.catalog.first { $0.label == f.label })
      for site in f.sites where site.type != "none" {
        let observer = Observer(latitude: site.lat, longitude: site.lon, elevation: .double(0))
        let local = try #require(c.localCircumstances(observer: observer), "\(f.label) \(site.name)")
        for (ours, ref) in [
          (local.c1, site.c1),
          (local.maximum, site.mid),
          (local.c4, site.c4),
          (local.c2, site.c2),
          (local.c3, site.c3),
        ] {
          guard let ref, let ours else { continue }
          let dt = abs(ours.date.timeIntervalSince(f.midnightUT) - ref.utSeconds)
          worst = max(worst, dt)
          #expect(dt < 0.5, "\(f.label) \(site.name)")
        }
        #expect(abs(local.magnitude - (site.magnitude ?? 0)) < 2e-5)
      }
    }
    print("CATALOG-vs-8-digit worst contact error \(worst) s")
  }

  @Test
  func universalTimeIsTerrestrialTimeMinusDeltaT() throws {
    let e = try #require(BesselianElements.catalog.first { $0.label == "2024-04-08" })
    let observer = Observer(latitude: 32.7767, longitude: -96.797, elevation: .double(0))
    for variant in [e, e.withDeltaT(e.deltaT + 10)] {
      let local = try #require(variant.localCircumstances(observer: observer))
      let tt = variant.t0.days + local.maximum.hoursFromT0 / 24
      #expect(abs((tt - local.maximum.julianDate.days) * 86_400 - variant.deltaT) < 1e-3)
    }
    // A larger ΔT turns the Earth less: the instant moves by a few seconds, not by the full 10 s.
    let a = try #require(e.localCircumstances(observer: observer))
    let b = try #require(e.withDeltaT(e.deltaT + 10).localCircumstances(observer: observer))
    #expect(abs(b.maximum.date.timeIntervalSince(a.maximum.date)) < 30)
  }

  @Test
  func elevationShiftsContactsSlightly() throws {
    let e = try #require(BesselianElements.catalog.first { $0.label == "2024-04-08" })
    let sea = try #require(e.localCircumstances(observer: Observer(latitude: 32.7767, longitude: -96.797, elevation: .double(0))))
    let high = try #require(e.localCircumstances(observer: Observer(
      latitude: 32.7767,
      longitude: -96.797,
      elevation: .double(3000)
    )))
    let d = abs(high.maximum.date.timeIntervalSince(sea.maximum.date))
    #expect(d > 0.01 && d < 5)
    #expect(abs(try #require(high.centralDuration) - sea.centralDuration!) < 5)
  }

  @Test
  func customElementsAndNoEclipse() throws {
    // User supplied elements: a copy of the 2024 eclipse under another label behaves identically.
    var e = try #require(BesselianElements.catalog.first { $0.label == "2024-04-08" })
    e.label = "my-eclipse"
    #expect(e.eclipseType == .total)
    // Sydney never sees the 2024 eclipse (Sun below the horizon / not touched).
    let sydney = Observer(latitude: -33.8688, longitude: 151.2093, elevation: .double(0))
    #expect(e.localCircumstances(observer: sydney) == nil)
  }

  @Test
  func catalogLookup() {
    let date = utcMidnight("2024-04-08").addingTimeInterval(18 * 3600)
    #expect(SolarEclipseCatalog.eclipse(near: date)?.label == "2024-04-08")
    #expect(SolarEclipseCatalog.next(after: date.addingTimeInterval(3600))?.label == "2024-10-02")
    #expect(SolarEclipseCatalog.eclipse(near: utcMidnight("2024-05-01")) == nil)
  }
}
