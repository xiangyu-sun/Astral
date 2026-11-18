//
//  BodyOrientation.swift
//

import Foundation
import simd

/// Body-frame → ecliptic-frame rotations.
///
/// The body frame has +z at the north pole and +x through the prime meridian at the equator.
public enum BodyOrientation {

  // MARK: Public

  /// Mean obliquity of the ecliptic at J2000, degrees.
  public static let earthObliquityDeg = 23.4393

  /// Earth Rotation Angle, radians, wrapped to [0, 2π).
  public static func earthRotationAngle(at time: JulianDate) -> Double {
    let turns = 0.7790572732640 + 1.00273781191135448 * (time.days - JulianDate.j2000.days)
    return 2 * .pi * (turns - turns.rounded(.down))
  }

  /// Earth's orientation: the pole tilted by the obliquity, spun by the Earth Rotation Angle.
  public static func earth(at time: JulianDate) -> simd_quatd {
    tilt(deg: earthObliquityDeg) * simd_quatd(angle: earthRotationAngle(at: time), axis: zAxis)
  }

  /// Tidally locked: +x points at the parent, +z as close to ecliptic north as possible.
  ///
  /// - Parameter offset: The vector from the body to its parent.
  public static func tidallyLocked(toParent offset: SIMD3<Double>) -> simd_quatd {
    let x = simd_normalize(offset)
    var z = zAxis - simd_dot(zAxis, x) * x
    z = simd_length(z) > 1e-9 ? simd_normalize(z) : SIMD3(0, 1, 0)
    let y = simd_cross(z, x)
    return simd_quatd(simd_double3x3(columns: (x, y, z)))
  }

  /// Generic body: tilt about the ecliptic x-axis, uniform spin, phase zero at J2000.
  ///
  /// The pole direction is not astronomically correct; this is for display only.
  public static func generic(body: Body, at time: JulianDate) -> simd_quatd {
    let period = body.rotationPeriodHours
    guard period != 0 else { return tilt(deg: body.axialTiltDeg) }
    let turns = (time.days - JulianDate.j2000.days) * 24 / period
    let spin = 2 * .pi * (turns - turns.rounded(.down))
    return tilt(deg: body.axialTiltDeg) * simd_quatd(angle: spin, axis: zAxis)
  }

  // MARK: Internal

  static let xAxis = SIMD3<Double>(1, 0, 0)
  static let zAxis = SIMD3<Double>(0, 0, 1)

  /// Tilts the pole from ecliptic north to `(0, sin ε, cos ε)`.
  static func tilt(deg: Double) -> simd_quatd {
    simd_quatd(angle: -deg * Units.degToRad, axis: xAxis)
  }
}
