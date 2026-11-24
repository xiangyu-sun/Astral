import Astral
import Foundation
import simd
import Testing

/// `Catalog.dwarfPlanets` against the verbatim SBDB responses and the JPL Horizons vectors of the small-body fixture.
@Suite("Dwarf planet catalog rows", .tags(.ephemeris, .accuracy))
struct DwarfPlanetCatalogTests {

  static let rows: [(key: String, body: Body)] = [
    ("ceres", Catalog.ceres),
    ("eris", Catalog.eris),
    ("haumea", Catalog.haumea),
    ("makemake", Catalog.makemake),
  ]

  @Test
  func listMatchesTheBodyIDs() {
    #expect(Catalog.dwarfPlanets.map(\.id) == BodyID.dwarfPlanets)
    #expect(Catalog.all.allSatisfy { !BodyID.dwarfPlanets.contains($0.id) })
    #expect(Catalog.allWithPluto.allSatisfy { !BodyID.dwarfPlanets.contains($0.id) })
    for body in Catalog.dwarfPlanets {
      #expect(body.parent == .sun)
      #expect(body.elements == nil)
      #expect(body.smallBody != nil)
      #expect(body.radiusKm > 0 && body.rotationPeriodHours != 0)
    }
  }

  /// The literals in `Catalog` are exactly the elements decoded from the SBDB response.
  @Test(arguments: rows.map(\.key))
  func elementsAreTheSBDBElements(key: String) throws {
    let body = try #require(Self.rows.first { $0.key == key }?.body)
    let catalog = try #require(body.smallBody)
    let sbdb = try SmallBodyFixture.load().entry(key).body()
    #expect(catalog == sbdb)
  }

  /// `SolarSystem` places each dwarf planet where Horizons does at the element epoch, and within the small-body
  /// tolerance a year away.
  @Test(arguments: rows.map(\.key))
  func snapshotMatchesHorizons(key: String) throws {
    let body = try #require(Self.rows.first { $0.key == key }?.body)
    let entry = try SmallBodyFixture.load().entry(key)
    let system = SolarSystem(bodies: Catalog.all + Catalog.dwarfPlanets)
    for row in entry.rows {
      let position = try #require(system.snapshot(at: JulianDate(days: row.jd)).position(of: body.id))
      let offset = abs(row.jd - (body.smallBody?.epoch.days ?? 0))
      let limit = offset < 1 ? 1e-7 : 1.4e-3
      #expect(simd_length(position - row.position) < limit, "\(key) at JD \(row.jd)")
    }
  }

  /// The orbit outline is sampled like the planets' (uniform in mean anomaly from -pi) and lies on the orbit.
  @Test(arguments: rows.map(\.key))
  func orbitPathLiesOnTheOrbit(key: String) throws {
    let body = try #require(Self.rows.first { $0.key == key }?.body)
    let smallBody = try #require(body.smallBody)
    let system = SolarSystem(bodies: [Catalog.sun, body])
    let path = system.orbitPath(of: body.id, at: JulianDate(days: 2_461_200.5), samples: 64)
    #expect(path.count == 64)
    let q = smallBody.perihelionDistance
    let Q = try #require(smallBody.aphelionDistance)
    for point in path {
      let r = simd_length(point)
      #expect(r > q * (1 - 1e-9) && r < Q * (1 + 1e-9), "\(key): r = \(r)")
    }
    // k = samples / 2 is mean anomaly 0, the perihelion.
    #expect(abs(simd_length(path[32]) - q) < 1e-9 * q)
  }

  @Test
  func dwarfPlanetsHaveNoRiseSetOrMagnitudeModel() {
    for id in BodyID.dwarfPlanets {
      #expect(PhysicalConstants.pole(of: id) == nil)
      #expect(!SPKFile.naifIDs(for: id).isEmpty)
    }
  }
}
