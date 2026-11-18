//
//  Kepler.swift
//

import Foundation
import simd

/// Kepler's equation solver and orbital position evaluation.
///
/// This follows the method on JPL's "Approximate Positions of the Planets" page, without the final equatorial
/// conversion: results stay in the ecliptic frame.
public enum Kepler {

  /// Solves Kepler's equation `E − e·sin E = M` for the eccentric anomaly (radians).
  ///
  /// Newton iteration from `E = M + e·sin M`, stopping when the step is below 1e-12 rad (at most 12 iterations).
  public static func eccentricAnomaly(meanAnomaly M: Double, eccentricity e: Double) -> Double {
    var E = M + e * sin(M)
    for _ in 0..<12 {
      let step = (E - e * sin(E) - M) / (1 - e * cos(E))
      E -= step
      if abs(step) < 1e-12 { break }
    }
    return E
  }

  /// Position relative to the parent body, in the ecliptic frame (AU).
  ///
  /// - Parameters:
  ///   - elements: The orbital elements.
  ///   - T: Julian centuries since J2000.
  ///   - longitudeOffsetDeg: Added to L, peri and node (used to move of-date elements into the J2000 frame).
  public static func position(
    elements el: OrbitalElements,
    T: Double,
    longitudeOffsetDeg: Double = 0
  ) -> SIMD3<Double> {
    let d = Units.degToRad
    let a = el.a + el.aRate * T
    let e = el.e + el.eRate * T
    let I = (el.i + el.iRate * T) * d
    let L = (el.L + el.LRate * T + longitudeOffsetDeg) * d
    let peri = (el.peri + el.periRate * T + longitudeOffsetDeg) * d
    let node = (el.node + el.nodeRate * T + longitudeOffsetDeg) * d
    return position(
      a: a,
      e: e,
      I: I,
      argPeri: peri - node,
      node: node,
      meanAnomaly: wrapPi(L - peri)
    )
  }

  /// Position from resolved elements; all angles in radians.
  public static func position(
    a: Double,
    e: Double,
    I: Double,
    argPeri w: Double,
    node O: Double,
    meanAnomaly M: Double
  ) -> SIMD3<Double> {
    let E = eccentricAnomaly(meanAnomaly: M, eccentricity: e)
    let xp = a * (cos(E) - e)
    let yp = a * sqrt(1 - e * e) * sin(E)
    let cw = cos(w)
    let sw = sin(w)
    let cO = cos(O)
    let sO = sin(O)
    let cI = cos(I)
    let sI = sin(I)
    return SIMD3(
      (cw * cO - sw * sO * cI) * xp + (-sw * cO - cw * sO * cI) * yp,
      (cw * sO + sw * cO * cI) * xp + (-sw * sO + cw * cO * cI) * yp,
      (sw * sI) * xp + (cw * sI) * yp
    )
  }

  /// Wraps an angle to [−π, π].
  public static func wrapPi(_ x: Double) -> Double {
    x.remainder(dividingBy: 2 * .pi)
  }
}
