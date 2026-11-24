import Astral
import Foundation
import simd
import Testing

/// JPL SBDB elements and Horizons heliocentric states (ecliptic J2000, AU, AU/day, TDB), see
/// Fixtures/SmallBody/make_smallbody_fixture.py.
struct SmallBodyFixture {
  struct Row: Decodable {
    let jd: Double
    let date: String
    let x: Double
    let y: Double
    let z: Double
    let vx: Double
    let vy: Double
    let vz: Double

    var position: SIMD3<Double> {
      SIMD3(x, y, z)
    }

    var velocity: SIMD3<Double> {
      SIMD3(vx, vy, vz)
    }
  }

  struct Entry {
    let key: String
    let name: String
    /// The verbatim SBDB API response.
    let sbdbJSON: Data
    let rows: [Row]

    /// The body decoded from the SBDB response with the library's decoder.
    func body() throws -> SmallBody {
      try SmallBody(sbdbJSON: sbdbJSON)
    }

    /// The Horizons row at the element epoch.
    func epochRow(_ body: SmallBody) throws -> Row {
      try #require(rows.first { $0.jd == body.epoch.days }, "\(key): no Horizons row at the element epoch")
    }
  }

  static let keys = ["ceres", "vesta", "eros", "apophis", "halley", "encke", "neowise", "oumuamua", "eris", "haumea",
    "makemake"]

  let entries: [Entry]

  static func load() throws -> SmallBodyFixture {
    let url = try #require(
      Bundle.module.url(forResource: "smallbodies", withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: "smallbodies", withExtension: "json"),
      "smallbodies.json missing from test bundle"
    )
    let data = try Data(contentsOf: url)
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let bodies = try #require(root["bodies"] as? [[String: Any]])
    let entries = try bodies.map { dict -> Entry in
      let sbdb = try #require(dict["sbdb"])
      let rows = try #require(dict["rows"])
      return Entry(
        key: try #require(dict["key"] as? String),
        name: try #require(dict["name"] as? String),
        sbdbJSON: try JSONSerialization.data(withJSONObject: sbdb),
        rows: try JSONDecoder().decode([Row].self, from: JSONSerialization.data(withJSONObject: rows))
      )
    }
    return SmallBodyFixture(entries: entries)
  }

  func entry(_ key: String) throws -> Entry {
    try #require(entries.first { $0.key == key }, "no fixture entry \(key)")
  }
}
