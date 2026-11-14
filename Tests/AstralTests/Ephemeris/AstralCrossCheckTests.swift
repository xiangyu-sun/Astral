import Astral
import Foundation
import Testing
import simd

/// Cross-checks the planetary ephemeris against Astral's own Meeus-based Moon and Sun code (independent code paths).
@Suite("Cross-check against Astral's moon functions", .tags(.ephemeris, .lunar, .integration))
struct AstralCrossCheckTests {

  // MARK: Internal

  static let dates: [Date] = [
    utcDate(1900, 1, 1, 12), utcDate(1969, 7, 20, 20), utcDate(2000, 1, 1, 12),
    utcDate(2025, 9, 7, 18, 12), utcDate(2026, 8, 12, 17, 46), utcDate(2026, 11, 14, 12),
    utcDate(2040, 3, 3, 3),
  ]

  /// Geocentric ecliptic longitude of the Moon. Astral's is referred to the equinox of date, the ephemeris's to
  /// J2000, so general precession is added back before comparing.
  @Test(arguments: MoonModel.allCases)
  func moonLongitudeAgrees(model: MoonModel) {
    var worst = 0.0
    for date in Self.dates {
      let jd = JulianDate(date)
      let s = SolarSystem(moonModel: model).snapshot(at: jd)
      let geo = s.states[.moon]!.position - s.states[.earth]!.position
      let ours = atan2(geo.y, geo.x) * 180 / .pi + 1.3969713 * jd.centuriesSinceJ2000
      let theirs = Astral.moon_true_longitude(jd2000: jd.days - 2_451_545.0) * 360
      let diff = abs(Self.wrapDeg(ours - theirs))
      worst = max(worst, diff)
      print("ASTRAL moon lon \(date) model \(model): ephemeris \(fmt(ours)) Astral \(fmt(theirs)) diff \(fmt(diff)) deg")
    }
    switch model {
    case .meanElements: #expect(worst < 3.0) // spec Level A tolerance
    case .periodicTerms: #expect(worst < 1.0) // Level B should be well inside 1 deg
    case .series: #expect(worst < 1e-6) // same series, same conventions: only round-off differs
    }
  }

  /// Moon age in days from Astral's `moonPhase(date:)` vs the ephemeris's elongation mapped onto the synodic month.
  @Test(arguments: MoonModel.allCases)
  func moonAgeAgrees(model: MoonModel) {
    let synodic = 29.53058867
    for date in Self.dates {
      let phase = MoonPhase(date: date, model: model)
      let ours = phase.elongation / (2 * .pi) * synodic
      let theirs = Astral.moonPhase(date: date.components())
      var diff = abs(ours - theirs)
      diff = min(diff, synodic - diff)
      print("ASTRAL moon age \(date) model \(model): ephemeris \(fmt(ours)) Astral \(fmt(theirs)) diff \(fmt(diff)) d")
      #expect(diff < ageTolerance(for: model), "\(model) at \(date)")
    }
  }

  /// Age tolerance in days (1 d of age = about 12.2 deg of elongation): 0.1 d (1.2 deg) for the default model, as
  /// for the original OrbitKit cross-check; 0.25 d (3 deg, the spec's Level A bound) for mean elements; 0.01 d for
  /// the series, which is Astral's own lunar series.
  private func ageTolerance(for model: MoonModel) -> Double {
    switch model {
    case .meanElements: 0.25
    case .periodicTerms: 0.1
    case .series: 0.01
    }
  }

  /// The default `MoonPhase(date:)` goes through the same snapshot route as `SolarSystem`.
  @Test func moonPhaseDateMatchesSnapshotRoute() throws {
    for date in Self.dates {
      let direct = MoonPhase(date: date)
      let viaSnapshot = try #require(SolarSystem().snapshot(at: JulianDate(date)).moonPhase)
      #expect(abs(direct.elongation - viaSnapshot.elongation) < 1e-12)
      #expect(abs(direct.illuminatedFraction - viaSnapshot.illuminatedFraction) < 1e-12)
    }
  }

  /// `MoonPhase` (a type) and `moonPhase(date:)` (a free function) coexist without ambiguity at call sites.
  @Test func typeAndFreeFunctionCoexist() {
    let date = utcDate(2026, 8, 12, 17, 46)
    let age: Double = Astral.moonPhase(date: date.components())
    let phase: MoonPhase = MoonPhase(date: date)
    #expect(age >= 0 && age < 29.6)
    #expect(phase.name == .new)
    // Both agree the Moon is within a day of new at this solar eclipse.
    #expect(min(age, 29.53058867 - age) < 1)
  }

  /// Astral's lunar age and the ephemeris agree on illumination too: a full moon is almost fully lit, a new moon not.
  @Test func illuminationAtSyzygy() {
    #expect(MoonPhase(date: utcDate(2025, 9, 7, 18, 12)).illuminatedFraction > 0.99)
    #expect(MoonPhase(date: utcDate(2026, 8, 12, 17, 46)).illuminatedFraction < 0.01)
  }

  // MARK: Private

  private static func wrapDeg(_ x: Double) -> Double {
    var d = x.truncatingRemainder(dividingBy: 360)
    if d > 180 { d -= 360 }
    if d < -180 { d += 360 }
    return d
  }
}
