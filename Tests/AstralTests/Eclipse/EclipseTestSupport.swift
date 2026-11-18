import Astral
import Foundation
import Testing

// MARK: - EclipseFixture

enum EclipseFixture {
  static func data(_ name: String) throws -> Data {
    let url = try #require(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Eclipse/Fixtures")
        ?? Bundle.module.url(forResource: name, withExtension: "json"),
      "\(name).json missing from test bundle"
    )
    return try Data(contentsOf: url)
  }
}

/// Midnight UT of an ISO date `yyyy-MM-dd`.
func utcMidnight(_ iso: String) -> Date {
  let p = iso.split(separator: "-").map { Int($0)! }
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
}

// MARK: - SolarFixture

struct SolarFixture: Decodable {
  struct Elements: Decodable {
    let jd: Double
    let t0: Double
    let tmin: Double
    let tmax: Double
    let deltaT: Double
    let x: [Double]
    let y: [Double]
    let d: [Double]
    let mu: [Double]
    let l1: [Double]
    let l2: [Double]
    let tanF1: Double
    let tanF2: Double
  }

  struct Snapshot: Decodable {
    let utSeconds: Double
    let altitudeDeg: Double
    let azimuthDeg: Double
    let timeDisplay: String
  }

  struct Site: Decodable {
    let name: String
    let lat: Double
    let lon: Double
    let type: String
    let magnitude: Double?
    let obscuration: Double?
    let durationDisplay: String?
    let c1: Snapshot?
    let c2: Snapshot?
    let mid: Snapshot?
    let c3: Snapshot?
    let c4: Snapshot?
  }

  struct Eclipse: Decodable {
    let label: String
    let elements: Elements
    let sites: [Site]

    var midnightUT: Date {
      utcMidnight(label)
    }

    var besselian: BesselianElements {
      let p = label.split(separator: "-").map { Int($0)! }
      return BesselianElements(
        label: label,
        t0Year: p[0],
        t0Month: p[1],
        t0Day: p[2],
        t0Hours: elements.t0,
        deltaT: elements.deltaT,
        x: elements.x,
        y: elements.y,
        d: elements.d,
        mu: elements.mu,
        l1: elements.l1,
        l2: elements.l2,
        tanF1: elements.tanF1,
        tanF2: elements.tanF2,
        validHours: elements.tmin...elements.tmax
      )
    }
  }

  let eclipses: [Eclipse]

  static func load() throws -> SolarFixture {
    try JSONDecoder().decode(SolarFixture.self, from: EclipseFixture.data("solar_local"))
  }
}

// MARK: - SolarCase

struct SolarCase: Sendable, CustomTestStringConvertible, Hashable {
  let eclipse: String
  let site: String

  var testDescription: String {
    "\(eclipse) \(site)"
  }
}

func solarCases() -> [SolarCase] {
  guard let fixture = try? SolarFixture.load() else { return [] }
  return fixture.eclipses.flatMap { e in e.sites.map { SolarCase(eclipse: e.label, site: $0.name) } }
}
