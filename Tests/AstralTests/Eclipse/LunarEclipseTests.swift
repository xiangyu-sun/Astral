import Foundation
import Testing
import Astral

struct LunarFixture: Decodable {
  struct Entry: Decodable, Sendable {
    let date: String
    let type: String
    let gamma: Double
    let penumbralMagnitude: Double
    let umbralMagnitude: Double
    let greatestTD: String
    let greatestTDSeconds: Double
    let greatestSeconds: Double
    let deltaT: Double
    let P1Seconds: Double
    let U1Seconds: Double
    let U2Seconds: Double?
    let U3Seconds: Double?
    let U4Seconds: Double
    let P4Seconds: Double
  }

  let eclipses: [Entry]

  static func load() throws -> LunarFixture {
    try JSONDecoder().decode(LunarFixture.self, from: EclipseFixture.data("lunar_eclipses"))
  }
}

func lunarDates() -> [String] {
  (try? LunarFixture.load())?.eclipses.map(\.date) ?? []
}

@Suite("Lunar eclipses vs NASA GSFC", .tags(.accuracy, .integration))
struct LunarEclipseTests {
  @Test(arguments: lunarDates())
  func matchesNASA(date: String) throws {
    let fixture = try LunarFixture.load()
    let ref = try #require(fixture.eclipses.first { $0.date == date })
    let midnight = utcMidnight(date)
    // NASA's UT was derived with its predicted ΔT (75 s). Compare in TT so that only the geometry is tested.
    let nasaTT = { (seconds: Double) -> Double in midnight.timeIntervalSince1970 + seconds + ref.deltaT }
    let guess = midnight.addingTimeInterval(ref.greatestSeconds)
    let eclipse = try #require(LunarEclipse.eclipse(nearFullMoon: guess), "no eclipse found")

    func tt(_ c: LunarEclipseContact?) -> Double? {
      c.map { ($0.terrestrialTime.days - 2_440_587.5) * 86_400 }
    }
    var line = "LUNAR \(date) \(eclipse.type) (NASA \(ref.type)):"
    var errors: [(String, Double)] = []
    func add(_ name: String, _ c: LunarEclipseContact?, _ refSeconds: Double?) {
      guard let refSeconds else { return }
      guard let ours = tt(c) else { Issue.record("\(name) missing"); return }
      let dt = ours - nasaTT(refSeconds)
      errors.append((name, dt))
      line += String(format: " %@ %+.1fs", name, dt)
    }
    add("P1", eclipse.p1, ref.P1Seconds)
    add("U1", eclipse.u1, ref.U1Seconds)
    add("U2", eclipse.u2, ref.U2Seconds)
    add("greatest", eclipse.greatest, ref.greatestSeconds)
    add("U3", eclipse.u3, ref.U3Seconds)
    add("U4", eclipse.u4, ref.U4Seconds)
    add("P4", eclipse.p4, ref.P4Seconds)
    let dPen = eclipse.penumbralMagnitude - ref.penumbralMagnitude
    let dUmb = eclipse.umbralMagnitude - ref.umbralMagnitude
    let dGamma = eclipse.gamma - abs(ref.gamma)
    line += String(format: " dPenMag %+.4f dUmbMag %+.4f dGamma %+.4f", dPen, dUmb, dGamma)
    // UTC as reported to users vs NASA's UT (differs by the ΔT assumption, 75 s vs 69.184 s).
    let utcDiff = eclipse.greatest.date.timeIntervalSince(midnight) - ref.greatestSeconds
    line += String(format: " | greatest UTC - NASA UT %+.1fs", utcDiff)
    print(line)

    #expect(eclipse.type.rawValue == ref.type)
    for (name, dt) in errors { #expect(abs(dt) < 150, "\(name) \(dt)") }
    #expect(abs(dPen) < 0.02)
    #expect(abs(dUmb) < 0.02)
    #expect(eclipse.u2 != nil || ref.U2Seconds == nil)
  }

  @Test func findsEveryEclipseOf2025And2026() {
    let range = utcMidnight("2025-01-01")...utcMidnight("2027-01-01")
    let found = LunarEclipse.eclipses(in: range)
    // NASA: 2025 Mar 14 (T), Sep 7 (T); 2026 Mar 3 (T), Aug 28 (P).
    #expect(found.map(\.type) == [.total, .total, .total, .partial])
    #expect(found.count == 4)
  }

  @Test func nextEclipseAfterDate() throws {
    let e = try #require(LunarEclipse.next(after: utcMidnight("2025-04-01")))
    #expect(e.type == .total)
    #expect(abs(e.greatest.date.timeIntervalSince(utcMidnight("2025-09-07")) - (18 * 3600 + 11 * 60 + 43)) < 150)
    #expect(try #require(e.totalityDuration) > 4_000)
  }
}
