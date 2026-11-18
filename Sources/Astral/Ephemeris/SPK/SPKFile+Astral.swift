//
//  SPKFile+Astral.swift
//

import Foundation
import simd

// MARK: - NAIF identifiers

extension SPKFile {

  /// NAIF solar-system barycentre.
  public static let solarSystemBarycenterID = 0
  /// NAIF code of the ecliptic and equinox of J2000 frame (`ECLIPJ2000`).
  public static let eclipticJ2000FrameCode = 17

  /// The NAIF IDs that can stand for `body`, best first.
  ///
  /// The body centre comes first. Planets whose centre is not in the planetary kernels (Mars to Pluto in
  /// `de440s.bsp`, which carries only system barycentres) fall back to the system barycentre, the same convention
  /// as Astral's ``Catalog``, whose Mars to Pluto rows are system barycentres too.
  public static func naifIDs(for body: BodyID) -> [Int] {
    switch body {
    case .sun: [10]
    case .mercury: [199, 1]
    case .venus: [299, 2]
    case .earth: [399]
    case .moon: [301]
    case .mars: [499, 4]
    case .jupiter: [599, 5]
    case .saturn: [699, 6]
    case .uranus: [799, 7]
    case .neptune: [899, 8]
    case .pluto: [999, 9]
    }
  }

  /// The first of ``naifIDs(for:)`` that this kernel has a segment for, or `nil`.
  public func naifID(for body: BodyID) -> Int? {
    Self.naifIDs(for: body).first { id in segments.contains { $0.target == id } }
  }
}

// MARK: - Astral conventions

extension SPKFile {

  // MARK: Public

  /// State of `body` relative to `center` in the frame of the ecliptic and equinox of J2000, kilometres and
  /// kilometres per second.
  ///
  /// This is the frame ``SolarSystem`` uses. The J2000 (ICRF) axes of the kernel are rotated about the x axis by
  /// the J2000 mean obliquity, 84381.448″, as NAIF's `ECLIPJ2000` and JPL Horizons do.
  ///
  /// - Parameter time: Treated as TDB, taken as TDB like `state(target:center:at:)`.
  /// - Throws: ``SPKError/bodyNotInKernel(_:)`` if the kernel has no segment for either body.
  public func eclipticState(of body: BodyID, relativeTo center: BodyID = .sun, at time: JulianDate) throws -> SPKState {
    guard let target = naifID(for: body) else { throw SPKError.bodyNotInKernel(body) }
    guard let origin = naifID(for: center) else { throw SPKError.bodyNotInKernel(center) }
    let state = try state(target: target, center: origin, at: time)
    switch state.frame {
    case 1:
      return SPKState(
        position: Self.rotateToEcliptic(state.position),
        velocity: Self.rotateToEcliptic(state.velocity),
        frame: Self.eclipticJ2000FrameCode
      )

    case Self.eclipticJ2000FrameCode:
      return state

    default:
      throw SPKError.unsupportedFrame(state.frame)
    }
  }

  /// Heliocentric J2000 ecliptic position of `body`, AU: what ``SolarSystem`` returns in
  /// ``SystemSnapshot/position(of:)``, but from the kernel.
  ///
  /// "Heliocentric" means relative to the centre of the Sun (NAIF 10), not the solar-system barycentre.
  /// Mercury, Venus, Earth, the Moon and the Sun are body centres; Mars to Pluto are system barycentres in
  /// `de440s.bsp` (see ``naifIDs(for:)``).
  ///
  /// - Parameter time: A Julian date, **treated as TDB**. ``SolarSystem`` also takes its date as TT without a ΔT
  ///   correction, so the two stay comparable.
  public func heliocentricEclipticPosition(of body: BodyID, at time: JulianDate) throws -> SIMD3<Double> {
    try eclipticState(of: body, relativeTo: .sun, at: time).position / Units.kmPerAU
  }

  // MARK: Private

  /// Rotation of J2000 equatorial axes to ecliptic axes about x by the obliquity of J2000.
  private static func rotateToEcliptic(_ v: SIMD3<Double>) -> SIMD3<Double> {
    let epsilon = 84_381.448 / 3_600 * Units.degToRad
    let c = cos(epsilon)
    let s = sin(epsilon)
    return SIMD3(v.x, c * v.y + s * v.z, -s * v.y + c * v.z)
  }
}

// MARK: - SolarSystem integration

extension SolarSystem {

  /// The state of every body at `time`, with positions taken from an SPK kernel instead of the closed-form model.
  ///
  /// Positions are heliocentric, J2000 ecliptic, AU, exactly as in ``snapshot(at:)``; orientations come from the
  /// same ``BodyOrientation`` code. `time` is treated as TDB for the kernel. Bodies the kernel has no segment for
  /// are left out of the snapshot.
  ///
  /// - Throws: ``SPKError/noCoverage(target:et:)`` if `time` is outside the kernel's span for a body.
  public func snapshot(at time: JulianDate, kernel: SPKFile) throws -> SystemSnapshot {
    var positions = [BodyID: SIMD3<Double>]()
    for body in bodies where kernel.naifID(for: body.id) != nil {
      positions[body.id] = try kernel.heliocentricEclipticPosition(of: body.id, at: time)
    }

    var states = [BodyID: BodyState]()
    for body in bodies {
      guard let position = positions[body.id] else { continue }
      let orientation: simd_quatd =
        switch body.id {
        case .earth:
          BodyOrientation.earth(at: time)
        case .moon:
          BodyOrientation.tidallyLocked(toParent: (positions[.earth] ?? .zero) - position)
        default:
          BodyOrientation.generic(body: body, at: time)
        }
      states[body.id] = BodyState(id: body.id, position: position, orientation: orientation)
    }
    return SystemSnapshot(time: time, states: states)
  }
}
