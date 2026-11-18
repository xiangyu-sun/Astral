import Astral
import Foundation
import simd
import Testing

@Suite("Kepler conics: parabolic, hyperbolic, universal", .tags(.ephemeris, .unit, .fast))
struct KeplerConicsTests {
  static let k = Kepler.gaussianGravitationalConstant

  @Test
  func gaussianConstantIsTheSolarGravitationalParameter() {
    // GM_sun = k^2 = 2.959122082855911e-4 AU^3/day^2 (JPL SBDB/Horizons).
    #expect(abs(Self.k * Self.k - 2.959122082855911e-4) < 1e-18)
  }

  /// Meeus, Astronomical Algorithms, example 34.a: q = 1.487469 AU, perihelion 1998 Apr 14.4358, on 1998 Aug 5.0
  /// (t − T = 112.5642 d): ν = 66.78862°, r = 2.133911 AU. (Values as published in the example, which the
  /// github.com/soniakeys/meeus Go port reproduces; not independently re-derived from the book.)
  @Test
  func meeusExample34a() {
    let result = Kepler.parabolicOrbit(perihelionDistance: 1.487469, daysSincePerihelion: 112.5642)
    #expect(abs(result.trueAnomaly / Units.degToRad - 66.78862) < 2e-5)
    #expect(abs(result.radius - 2.133911) < 2e-6)
  }

  @Test
  func parabolicOrbitSatisfiesBarkersEquationAndIsOddInTime() {
    for q in [0.1, 0.9, 5.0] {
      for dt in [1e-6, 0.01, 1, 40, 500, 1e4, 1e6] {
        let after = Kepler.parabolicOrbit(perihelionDistance: q, daysSincePerihelion: dt)
        let before = Kepler.parabolicOrbit(perihelionDistance: q, daysSincePerihelion: -dt)
        #expect(after.trueAnomaly == -before.trueAnomaly && after.radius == before.radius)
        // Barker: s + s^3/3 = k (t - T) / sqrt(2 q^3), s = tan(v/2); and r = q (1 + s^2).
        let s = tan(after.trueAnomaly / 2)
        let lhs = s + s * s * s / 3
        let rhs = Self.k * dt / (2 * q * q * q).squareRoot()
        #expect(abs(lhs - rhs) <= 1e-12 * max(1, rhs), "q=\(q) dt=\(dt)")
        #expect(abs(after.radius - q * (1 + s * s)) <= 1e-12 * after.radius)
        #expect(abs(after.radius - 2 * q / (1 + cos(after.trueAnomaly))) <= 1e-10 * after.radius)
      }
    }
    #expect(Kepler.parabolicOrbit(perihelionDistance: 1, daysSincePerihelion: 0).trueAnomaly == 0)
  }

  @Test
  func universalPropagatorAgreesWithBarkerForE1() {
    for q in [0.3, 1.0, 4.0] {
      for dt in [-3000.0, -50, -0.5, 0, 0.5, 50, 3000] {
        let parabola = Kepler.parabolicOrbit(perihelionDistance: q, daysSincePerihelion: dt)
        let state = Kepler.perifocalState(perihelionDistance: q, eccentricity: 1, daysSincePerihelion: dt)
        let expected = SIMD2(parabola.radius * cos(parabola.trueAnomaly), parabola.radius * sin(parabola.trueAnomaly))
        #expect(simd_length(state.position - expected) < 1e-11 * parabola.radius, "q=\(q) dt=\(dt)")
      }
    }
  }

  @Test(arguments: [1.0000001, 1.001, 1.2, 3.0, 25.0])
  func hyperbolicAnomalyResidual(e: Double) {
    for M in [0.0, 1e-12, 1e-6, 1e-3, 0.1, 1, 10, 100, 1e4, -1e-6, -0.5, -37] {
      let H = Kepler.hyperbolicAnomaly(meanAnomaly: M, eccentricity: e)
      let residual = e * sinh(H) - H - M
      #expect(abs(residual) <= 1e-12 * max(1, abs(M)), "e=\(e) M=\(M) residual \(residual)")
      #expect(H.sign == M.sign || M == 0)
    }
  }

  /// A known solution: H = 1 for e = 2 gives M = 2 sinh 1 − 1.
  @Test
  func hyperbolicAnomalyKnownValue() {
    let M = 2 * sinh(1.0) - 1
    #expect(abs(Kepler.hyperbolicAnomaly(meanAnomaly: M, eccentricity: 2) - 1) < 1e-14)
  }

  /// The universal propagator reproduces the textbook hyperbolic solution
  /// x = |a|(e − cosh H), y = |a|·√(e² − 1)·sinh H.
  @Test(arguments: [1.0001, 1.2, 2.5, 10.0])
  func universalPropagatorAgreesWithHyperbolicSolution(e: Double) {
    let q = 0.7
    let a = q / (e - 1)
    let n = Self.k / (a * a.squareRoot())
    for dt in [-5000.0, -300, -1, -1e-3, 0, 1e-3, 1, 300, 5000] {
      let H = Kepler.hyperbolicAnomaly(meanAnomaly: n * dt, eccentricity: e)
      let expected = SIMD2(a * (e - cosh(H)), a * (e * e - 1).squareRoot() * sinh(H))
      let state = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt)
      #expect(simd_length(state.position - expected) < 1e-10 * max(1, simd_length(expected)), "e=\(e) dt=\(dt)")
    }
  }

  @Test(arguments: [0.0, 0.0167, 0.2, 0.5, 0.9, 0.99])
  func universalPropagatorAgreesWithClassicalKepler(e: Double) {
    let a = 2.3
    let q = a * (1 - e)
    let n = Self.k / (a * a.squareRoot())
    let period = 2 * Double.pi / n
    // Includes many orbits (the time is reduced modulo the period).
    for dt in stride(from: -2.5 * period, through: 3.2 * period, by: period / 37) {
      let M = Kepler.wrapPi(n * dt)
      let E = Kepler.eccentricAnomaly(meanAnomaly: M, eccentricity: e)
      let expected = SIMD2(a * (cos(E) - e), a * (1 - e * e).squareRoot() * sin(E))
      let state = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt)
      // Position is rebuilt from the reduced time, so allow for the rounding of n·dt over a few periods.
      #expect(simd_length(state.position - expected) < 1e-9, "e=\(e) dt=\(dt)")
    }
  }

  /// Near-parabolic ellipses (the long-period comets): compare with a reference built from bisection on
  /// Kepler's equation written without cancellation, `(1 − e)·E + e·(E − sin E) = M`.
  @Test(arguments: [0.9672747, 0.999, 0.99999, 0.9999999, 1 - 1e-10])
  func nearParabolicEllipse(e: Double) {
    let q = 0.6
    let a = q / (1 - e)
    let n = Self.k / (a * a.squareRoot())
    func eMinusSin(_ x: Double) -> Double {
      if abs(x) < 0.5 {
        var term = x * x * x / 6
        var sum = 0.0
        for k in 1..<14 {
          sum += term
          let denominator = Double((2 * k + 2) * (2 * k + 3))
          term *= -(x * x) / denominator
        }
        return sum
      }
      return x - sin(x)
    }
    func reference(M: Double) -> SIMD2<Double> {
      var lo = 0.0
      var hi = Double.pi
      for _ in 0..<200 {
        let mid = 0.5 * (lo + hi)
        if (1 - e) * mid + e * eMinusSin(mid) < M { lo = mid } else { hi = mid }
      }
      let E = 0.5 * (lo + hi)
      let x = a * (cos(E) - e)
      // a(cos E − e) = q − a(1 − cos E) avoids the cancellation as well.
      return SIMD2(q - a * 2 * sin(E / 2) * sin(E / 2), a * (1 - e * e).squareRoot() * sin(E))
        + SIMD2(x - x, 0)
    }
    for dt in [1e-3, 0.5, 20, 400, 5000, 40_000] {
      let M = n * dt
      guard M < .pi else { continue }
      let state = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt)
      let expected = reference(M: M)
      #expect(simd_length(state.position - expected) < 1e-10 * max(1, simd_length(expected)), "e=\(e) dt=\(dt)")
    }
  }

  @Test
  func positionIsContinuousThroughParabolicEccentricity() {
    let q = 0.4
    for dt in [-400.0, -20, 3, 90, 700] {
      let ref = Kepler.perifocalState(perihelionDistance: q, eccentricity: 1, daysSincePerihelion: dt)
      for delta in [1e-12, 1e-9, 1e-6] {
        for e in [1 - delta, 1 + delta] {
          let s = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt)
          // Position changes by O(delta); allow a generous multiple.
          #expect(simd_length(s.position - ref.position) < 1e3 * delta, "dt=\(dt) e=\(e)")
          #expect(simd_length(s.velocity - ref.velocity) < 1e3 * delta, "dt=\(dt) e=\(e) v")
        }
      }
    }
  }

  /// Vis-viva, constant angular momentum, and velocity = d(position)/dt.
  @Test(arguments: [0.0, 0.3, 0.97, 1.0, 1.0004, 1.8, 6.0])
  func invariants(e: Double) {
    let q = 0.8
    let mu = Self.k * Self.k
    let h = Self.k * (q * (1 + e)).squareRoot()
    for dt in [-900.0, -45, -0.2, 0.0, 1.5, 60, 1200] {
      let s = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt)
      let r = simd_length(s.position)
      let v2 = simd_length_squared(s.velocity)
      // Vis-viva: v² = μ(2/r − (1 − e)/q).
      #expect(abs(v2 - mu * (2 / r - (1 - e) / q)) < 1e-12 * max(v2, 1e-12), "e=\(e) dt=\(dt) energy")
      let angularMomentum = s.position.x * s.velocity.y - s.position.y * s.velocity.x
      #expect(abs(angularMomentum - h) < 1e-12 * h, "e=\(e) dt=\(dt) h")
      // Conic equation r = p / (1 + e cos ν) => r + e·x = p.
      #expect(abs(r + e * s.position.x - q * (1 + e)) < 1e-10 * max(1, r), "e=\(e) dt=\(dt) conic")

      let step = 1e-2
      let plus = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt + step)
      let minus = Kepler.perifocalState(perihelionDistance: q, eccentricity: e, daysSincePerihelion: dt - step)
      let numeric = (plus.position - minus.position) / (2 * step)
      #expect(simd_length(numeric - s.velocity) < 1e-6 * simd_length(s.velocity), "e=\(e) dt=\(dt) dx/dt")
    }
  }

  @Test
  func stumpffFunctionsMatchTheirDefinitionsAndAreContinuous() {
    for z in [-30.0, -4.0, -0.6, -0.5001, -0.4999, -1e-8, 0, 1e-8, 0.4999, 0.5001, 2, 9.8] {
      let (c, s) = Kepler.stumpff(z)
      if z > 1e-3 {
        #expect(abs(c - (1 - cos(z.squareRoot())) / z) < 1e-14)
        #expect(abs(s - (z.squareRoot() - sin(z.squareRoot())) / (z * z.squareRoot())) < 1e-14)
      } else if z < -1e-3 {
        let w = (-z).squareRoot()
        #expect(abs(c - (cosh(w) - 1) / -z) < 1e-12 * max(1, c))
        #expect(abs(s - (sinh(w) - w) / (w * -z)) < 1e-12 * max(1, s))
      } else {
        #expect(abs(c - 0.5) < 1e-6 && abs(s - 1.0 / 6) < 1e-6)
      }
    }
    // The series and the closed forms meet at |z| = 0.5.
    for sign in [-1.0, 1.0] {
      let below = Kepler.stumpff(sign * 0.4999999999)
      let above = Kepler.stumpff(sign * 0.5000000001)
      #expect(abs(below.c - above.c) < 1e-9 && abs(below.s - above.s) < 1e-9)
    }
  }
}
