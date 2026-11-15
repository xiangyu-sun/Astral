import Foundation
import simd
import Testing
import Astral

@Suite("Kepler solver", .tags(.ephemeris, .unit, .fast))
struct KeplerTests {
  /// Mean anomaly is wrapped to [-pi, pi] before solving (architecture 3.3), so
  /// "the full circle" is covered as [-pi, pi].
  static let eccentricities = [0.0, 0.0167, 0.2, 0.5, 0.9]

  @Test(arguments: eccentricities)
  func residualBelow1e10(e: Double) {
    let n = 3_600
    var worst = 0.0
    for k in 0...n {
      let M = -Double.pi + 2 * Double.pi * Double(k) / Double(n)
      let E = Kepler.eccentricAnomaly(meanAnomaly: M, eccentricity: e)
      worst = max(worst, abs(E - e * sin(E) - M))
    }
    #expect(worst < 1e-10, "e=\(e) worst residual \(worst)")
  }

  @Test func circularOrbitEqualsMeanAnomaly() {
    for k in 0...360 {
      let M = -Double.pi + 2 * Double.pi * Double(k) / 360
      #expect(Kepler.eccentricAnomaly(meanAnomaly: M, eccentricity: 0) == M)
    }
  }

  @Test func wrapPiRange() {
    for x in stride(from: -20.0, through: 20.0, by: 0.37) {
      let w = Kepler.wrapPi(x)
      #expect(w >= -Double.pi - 1e-12 && w <= Double.pi + 1e-12)
      #expect(abs(sin(w) - sin(x)) < 1e-12)
    }
  }

  @Test func positionAtPerihelionAndAphelion() {
    // Zero inclination/node/argument: perihelion on +x at a(1-e), aphelion on -x at a(1+e).
    let peri = Kepler.position(a: 2, e: 0.25, I: 0, argPeri: 0, node: 0, meanAnomaly: 0)
    #expect(abs(peri.x - 1.5) < 1e-12 && abs(peri.y) < 1e-12 && abs(peri.z) < 1e-12)
    let aph = Kepler.position(a: 2, e: 0.25, I: 0, argPeri: 0, node: 0, meanAnomaly: .pi)
    #expect(abs(aph.x + 2.5) < 1e-9 && abs(aph.y) < 1e-9)
  }

  @Test func inclinationLiftsOutOfEcliptic() {
    // 90 deg past the node on a circular orbit with i = 30 deg: z = sin(i).
    let p = Kepler.position(a: 1, e: 0, I: 30 * Units.degToRad, argPeri: 0, node: 0,
                meanAnomaly: .pi / 2)
    #expect(abs(p.z - 0.5) < 1e-12)
    #expect(abs(simd_length(p) - 1) < 1e-12)
  }
}
