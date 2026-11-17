//
//  KeplerConics.swift
//

import Foundation
import simd

/// Two-body motion on any conic section: ellipses, parabolas and hyperbolas.
///
/// ``Kepler/eccentricAnomaly(meanAnomaly:eccentricity:)`` only covers ellipses. The functions here add the
/// hyperbolic and parabolic cases, and a single universal-variable propagator that is uniform across `e < 1`,
/// `e = 1` and `e > 1` and therefore stays well conditioned for the near-parabolic orbits of long-period comets
/// (where the classical eccentric-anomaly Newton iteration converges poorly, and where Meeus, chapter 35, needs a
/// special method).
///
/// Units are AU and days, with the Sun's gravitational parameter fixed by the Gaussian gravitational constant,
/// ``Kepler/gaussianGravitationalConstant``.
extension Kepler {

  // MARK: Public

  /// The Gaussian gravitational constant `k`, in radians per day, for the AU, the day and the solar mass.
  ///
  /// `k² = 2.959122082855911e-4 AU³/day²` is the Sun's gravitational parameter, `GM☉`, in the units used by the
  /// JPL Small-Body Database and Horizons. A body with semi-major axis `a` (AU) has mean motion `k / a^1.5`
  /// rad/day.
  public static let gaussianGravitationalConstant = 0.01720209895

  /// Solves the hyperbolic Kepler equation `M = e·sinh H − H` for the hyperbolic anomaly `H` (radians).
  ///
  /// `e` must be greater than 1. `M` is the hyperbolic mean anomaly, `n·(t − T)` with `n = k / |a|^1.5`. Newton
  /// iteration from the starting values of Danby and of the cubic (Barker) limit, which is what makes it robust
  /// for `e` close to 1 and small `M`.
  public static func hyperbolicAnomaly(meanAnomaly M: Double, eccentricity e: Double) -> Double {
    if M == 0 { return 0 }
    let m = abs(M)
    // For e ≈ 1 and small M the equation is (e − 1)·H + H³/6 = M, so H ≤ ∛(6M); for large M, ln(2M/e + 1.8)
    // (Danby) is the better start. The smaller of the two starts the iteration.
    var H = min(log(2 * m / e + 1.8), cbrt(6 * m))
    for _ in 0..<200 {
      let f = e * sinh(H) - H - m
      let step = f / (e * cosh(H) - 1)
      H -= step
      if abs(step) <= 1e-15 * max(1, abs(H)) { break }
    }
    return M < 0 ? -H : H
  }

  /// Barker's equation for a parabolic orbit (Meeus, chapter 34): the true anomaly and heliocentric distance
  /// `daysSincePerihelion` days after perihelion (negative before it).
  ///
  /// - Parameters:
  ///   - perihelionDistance: `q`, AU.
  ///   - daysSincePerihelion: `t − T`, days.
  /// - Returns: The true anomaly in radians, in `(−π, π)`, and the radius in AU.
  public static func parabolicOrbit(
    perihelionDistance q: Double,
    daysSincePerihelion dt: Double)
    -> (trueAnomaly: Double, radius: Double)
  {
    // With s = tan(v/2):  s³ + 3s = W,  W = 3k(t − T) / (√2 q^1.5)  (0.03649116245 · (t − T) / q^1.5).
    let W = 3 * gaussianGravitationalConstant * abs(dt) / (2.0.squareRoot() * q * q.squareRoot())
    let Y = cbrt(W / 2 + (W * W / 4 + 1).squareRoot())
    var s = Y - 1 / Y
    // One Newton step removes the cancellation in Y − 1/Y for small W.
    s -= (s * s * s + 3 * s - W) / (3 * s * s + 3)
    let v = 2 * atan(s)
    let radius = q * (1 + s * s)
    return (dt < 0 ? -v : v, radius)
  }

  /// The Stumpff functions `C(z) = (1 − cos √z) / z` and `S(z) = (√z − sin √z) / z^1.5`, continued analytically to
  /// negative `z` (hyperbolic functions).
  public static func stumpff(_ z: Double) -> (c: Double, s: Double) {
    if abs(z) < 0.5 { return seriesStumpff(z) }
    if z > 0 {
      let root = z.squareRoot()
      return ((1 - cos(root)) / z, (root - sin(root)) / (root * z))
    }
    let root = (-z).squareRoot()
    return ((cosh(root) - 1) / -z, (sinh(root) - root) / (root * -z))
  }

  /// Solves the universal Kepler equation for a body at perihelion at `t = T`:
  /// `e·χ³·S(αχ²) + q·χ = k·(t − T)` with `α = (1 − e)/q`, for the universal anomaly `χ` (AU^½).
  ///
  /// - Parameters:
  ///   - perihelionDistance: `q`, AU, positive.
  ///   - eccentricity: `e`, any value `≥ 0`.
  ///   - scaledTime: `k·(t − T)`, in AU^1.5.
  public static func universalAnomaly(
    perihelionDistance q: Double,
    eccentricity e: Double,
    scaledTime: Double)
    -> Double
  {
    if scaledTime == 0 { return 0 }
    let s = abs(scaledTime)
    let alpha = (1 - e) / q
    // Every term of F is positive for χ > 0 and F(χ) = e·χ³·S + q·χ − s, so the root lies in (0, s/q].
    var lo = 0.0
    var hi = s / q
    // The parabolic solution (Barker) is an excellent start when e ≈ 1; clamp it into the bracket.
    let W = 3 * s / (q * (2 * q).squareRoot())
    let Y = cbrt(W / 2 + (W * W / 4 + 1).squareRoot())
    var x = min(hi, (2 * q).squareRoot() * (Y - 1 / Y))
    for _ in 0..<200 {
      let z = alpha * x * x
      let (C, S) = stumpff(z)
      let f = e * x * x * x * S + q * x - s
      if f > 0 { hi = x } else { lo = x }
      // F' is the heliocentric distance r(χ) > 0, so F is strictly increasing.
      let r = x * x * C + q * (1 - z * C)
      var next = x - f / r
      if !(next > lo && next < hi) { next = 0.5 * (lo + hi) }
      let converged = abs(next - x) <= 1e-15 * abs(next)
      x = next
      if converged { break }
    }
    return scaledTime < 0 ? -x : x
  }

  /// The position and velocity in the orbital plane (perifocal frame: x toward perihelion, y toward the motion at
  /// perihelion), `daysSincePerihelion` days after perihelion, for any conic.
  ///
  /// Uses the universal-variable f and g functions, so it is uniform in `e`. For an ellipse the time is first
  /// reduced modulo the period.
  ///
  /// - Parameters:
  ///   - perihelionDistance: `q`, AU, positive.
  ///   - eccentricity: `e ≥ 0`; `e < 1` ellipse, `e = 1` parabola, `e > 1` hyperbola.
  ///   - daysSincePerihelion: `t − T`, days.
  /// - Returns: Position in AU and velocity in AU/day.
  public static func perifocalState(
    perihelionDistance q: Double,
    eccentricity e: Double,
    daysSincePerihelion: Double)
    -> (position: SIMD2<Double>, velocity: SIMD2<Double>)
  {
    let k = gaussianGravitationalConstant
    var dt = daysSincePerihelion
    if e < 1 {
      let a = q / (1 - e)
      let n = k / (a * a.squareRoot())
      if abs(n * dt) > .pi {
        dt = wrapPi(n * dt) / n
      }
    }
    let alpha = (1 - e) / q
    let chi = universalAnomaly(perihelionDistance: q, eccentricity: e, scaledTime: k * dt)
    let z = alpha * chi * chi
    let (C, S) = stumpff(z)
    let r = chi * chi * C + q * (1 - z * C)
    let f = 1 - chi * chi * C / q
    let g = dt - chi * chi * chi * S / k
    let fDot = -k * chi * (1 - z * S) / (r * q)
    let gDot = 1 - chi * chi * C / r
    // State at perihelion: position (q, 0), velocity (0, vp) with vp = k·√((1 + e)/q).
    let vp = k * ((1 + e) / q).squareRoot()
    return (SIMD2(f * q, g * vp), SIMD2(fDot * q, gDot * vp))
  }

  // MARK: Private

  /// Series for the Stumpff functions, accurate for |z| < 0.5.
  private static func seriesStumpff(_ z: Double) -> (c: Double, s: Double) {
    // C = Σ (−z)^k / (2k + 2)!,  S = Σ (−z)^k / (2k + 3)!
    var c = 0.0
    var s = 0.0
    var power = 1.0 // (−z)^k
    var factorial = 2.0 // (2k + 2)!
    for k in 0..<14 {
      c += power / factorial
      s += power / (factorial * Double(2 * k + 3))
      power *= -z
      factorial *= Double(2 * k + 3) * Double(2 * k + 4)
    }
    return (c, s)
  }
}
