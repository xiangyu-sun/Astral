import Astral
import Foundation
import Testing

@Suite("MoonPhase geometry", .tags(.ephemeris, .lunar))
struct MoonPhaseGeometryTests {
  @Test
  func fullAtLunarEclipse() throws {
    let phase = try #require(snapshot(Epoch.lunarFixture).moonPhase)
    #expect(phase.name == .full)
    #expect(phase.illuminatedFraction > 0.99)
  }

  @Test
  func newAtSolarEclipse() throws {
    let phase = try #require(snapshot(Epoch.solarFixture).moonPhase)
    #expect(phase.name == .new)
    #expect(phase.illuminatedFraction < 0.01)
  }

  @Test
  func cyclesThroughAllPhasesInOrder() throws {
    // Start at a new moon and step through one synodic month.
    var seen = [MoonPhase.Name]()
    var lastElongation = -1.0
    for step in 0..<59 {
      let phase = try #require(snapshot(Epoch.solarFixture + Double(step) * 0.5).moonPhase)
      if seen.last != phase.name { seen.append(phase.name) }
      if step > 0, step < 58 { #expect(phase.elongation > lastElongation || phase.elongation < 0.5) }
      lastElongation = phase.elongation
      #expect(phase.isWaxing == (phase.elongation < .pi))
    }
    #expect(Array(seen.prefix(8)) == MoonPhase.Name.allCases)
  }

  @Test
  func quarterIsHalfLit() throws {
    // Find first quarter after the 2026-08-12 new moon by scanning.
    var best = 1.0
    for step in 0..<400 {
      let phase = try #require(snapshot(Epoch.solarFixture + 5 + Double(step) * 0.01).moonPhase)
      if abs(phase.elongation - .pi / 2) < 0.002 { best = phase.illuminatedFraction
        break
      }
    }
    #expect(abs(best - 0.5) < 0.01)
  }
}
