import Astral
import Foundation
import simd
import Testing

@Suite("SolarSystem Moon model and Sendable API", .tags(.ephemeris, .unit))
struct SolarSystemModelTests {

  @Test
  func defaultModelIsPeriodicTerms() {
    #expect(SolarSystem().moonModel == .periodicTerms)
    #expect(SolarSystem(bodies: Catalog.allWithPluto).moonModel == .periodicTerms)
    #expect(SolarSystem().moonPeriodicTerms)
  }

  @Test
  func booleanConvenienceInitMapsToModels() {
    #expect(SolarSystem(moonPeriodicTerms: true).moonModel == .periodicTerms)
    #expect(SolarSystem(moonPeriodicTerms: false).moonModel == .meanElements)
    #expect(SolarSystem(bodies: Catalog.all, moonPeriodicTerms: false).moonModel == .meanElements)

    var system = SolarSystem(moonModel: .series)
    #expect(!system.moonPeriodicTerms)
    system.moonPeriodicTerms = true
    #expect(system.moonModel == .periodicTerms)
    system.moonPeriodicTerms = false
    #expect(system.moonModel == .meanElements)
  }

  /// The Bool-flag and enum initialisers give identical snapshots.
  @Test(arguments: [false, true])
  func booleanAndEnumInitsAgree(terms: Bool) {
    let time = JulianDate(days: Epoch.jd2026)
    let a = SolarSystem(moonPeriodicTerms: terms).snapshot(at: time)
    let b = SolarSystem(moonModel: terms ? .periodicTerms : .meanElements).snapshot(at: time)
    #expect(a.states[.moon]?.position == b.states[.moon]?.position)
    #expect(a.states[.earth]?.position == b.states[.earth]?.position)
  }

  @Test(arguments: MoonModel.allCases)
  func moonIsEarthPlusGeocentricVectorForEveryModel(model: MoonModel) throws {
    let time = JulianDate(days: Epoch.jd2026)
    let s = SolarSystem(moonModel: model).snapshot(at: time)
    let earth = try #require(s.states[.earth]).position
    let moon = try #require(s.states[.moon]).position
    let emb = Kepler.position(elements: try #require(Catalog.earth.elements), T: time.centuriesSinceJ2000)
    let geo = moon - earth
    // Earth sits 1/82.30057 of the geocentric vector from the barycentre, whatever the Moon model.
    #expect(simd_length(earth - (emb - geo / 82.30057)) < 1e-12)
    let r = simd_length(geo) * Units.kmPerAU
    #expect(r > 355_000 && r < 407_000, "\(model) distance \(r) km")
  }

  @Test
  func seriesModelUsesTheSeriesPosition() throws {
    let time = JulianDate(days: Epoch.jd2000)
    let s = SolarSystem(moonModel: .series).snapshot(at: time)
    let geo = try #require(s.states[.moon]).position - (try #require(s.states[.earth]).position)
    let series = MoonEphemeris.geocentricPositionSeries(at: time)
    #expect(simd_length(geo - series) < 1e-12)
  }

  @Test
  func seriesModelDoesNotNeedMoonElements() {
    let moonWithoutElements = Body(
      id: .moon,
      parent: .earth,
      elements: nil,
      radiusKm: 1_737.4,
      axialTiltDeg: 0,
      rotationPeriodHours: 655.72
    )
    let bodies = [Catalog.sun, Catalog.earth, moonWithoutElements]
    #expect(SolarSystem(bodies: bodies, moonModel: .series).snapshot(at: .j2000).states[.moon] != nil)
    // The mean-element models cannot place a Moon without elements; it is skipped, as before.
    #expect(SolarSystem(bodies: bodies, moonModel: .periodicTerms).snapshot(at: .j2000).states[.moon] == nil)
  }

  @Test
  func syzygyWithSeriesModel() throws {
    let solar = snapshot(Epoch.solarFixture, model: .series)
    let lunar = snapshot(Epoch.lunarFixture, model: .series)
    let solarAngle = sunEarthMoonAngleDeg(
      earth: try #require(solar.states[.earth]?.position),
      moon: try #require(solar.states[.moon]?.position)
    )
    let lunarAngle = sunEarthMoonAngleDeg(
      earth: try #require(lunar.states[.earth]?.position),
      moon: try #require(lunar.states[.moon]?.position)
    )
    #expect(solarAngle < 3, "solar eclipse angle \(solarAngle)")
    #expect(lunarAngle > 177, "lunar eclipse angle \(lunarAngle)")
  }

  @Test
  func orbitPathUnaffectedByMoonModel() {
    let time = JulianDate(days: Epoch.jd2026)
    let a = SolarSystem(moonModel: .meanElements).orbitPath(of: .moon, at: time, samples: 32)
    let b = SolarSystem(moonModel: .series).orbitPath(of: .moon, at: time, samples: 32)
    #expect(a == b)
  }

  @Test
  func publicValueTypesAreSendable() {
    func requireSendable(_: (some Sendable).Type) { }
    requireSendable(JulianDate.self)
    requireSendable(OrbitalElements.self)
    requireSendable(Body.self)
    requireSendable(BodyID.self)
    requireSendable(BodyState.self)
    requireSendable(SystemSnapshot.self)
    requireSendable(SolarSystem.self)
    requireSendable(MoonModel.self)
    requireSendable(MoonPhase.self)
    requireSendable(MoonPhase.Name.self)
    requireSendable(Observer.self)
    requireSendable(LocationInfo.self)
    requireSendable(Elevation.self)
    requireSendable(Depression.self)
    requireSendable(SunDirection.self)
    requireSendable(SunError.self)
    requireSendable(MoonError.self)
  }

  @Test
  func existingValueTypesAreHashable() {
    #expect(Set([Observer.london, Observer.london, Observer.newDelhi]).count == 2)
    #expect(Set([Elevation.double(1), .double(1), .tuple(1, 2)]).count == 2)
    #expect(Set([Depression.civil, .nautical, .other(3), .other(3)]).count == 3)
    #expect(Set([SunDirection.rising, .setting]).count == 2)
    let locations = [
      LocationInfo(name: "A", region: "R", timezone: .utc, latitude: 1, longitude: 2),
      LocationInfo(name: "A", region: "R", timezone: .utc, latitude: 1, longitude: 2),
    ]
    #expect(Set(locations).count == 1)
  }

  @Test
  func catalogContents() {
    #expect(Catalog.all.map(\.id) == [.sun, .mercury, .venus, .earth, .moon, .mars, .jupiter, .saturn, .uranus, .neptune])
    #expect(Catalog.allWithPluto.last?.id == .pluto)
    #expect(Catalog.all.allSatisfy { $0.id != .pluto })
    #expect(Catalog.earth.elements?.a == 1.00000261)
    #expect(Catalog.moon.elements?.LRate == 481_267.88123421)
    #expect(Catalog.pluto.elements?.a == 39.48211675)
  }
}
