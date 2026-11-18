//
//  SolarSystem.swift
//

import Foundation
import simd

// MARK: - MoonModel

/// How the Moon's geocentric position is computed by ``SolarSystem``.
public enum MoonModel: Sendable, Hashable, CaseIterable {
  /// Mean elements only (Meeus chapter 47). Longitude error up to about 2°.
  case meanElements
  /// Mean elements plus the evection, variation and annual equation terms.
  case periodicTerms
  /// Astral's lunar series, see ``MoonEphemeris/geocentricPositionSeries(T:)``.
  case series
}

// MARK: - BodyState

/// A body's state at one instant.
public struct BodyState: Sendable {

  // MARK: Lifecycle

  public init(id: BodyID, position: SIMD3<Double>, orientation: simd_quatd) {
    self.id = id
    self.position = position
    self.orientation = orientation
  }

  // MARK: Public

  public let id: BodyID
  /// Heliocentric J2000 ecliptic position, AU.
  public let position: SIMD3<Double>
  /// Rotation from the body frame to the ecliptic frame.
  public let orientation: simd_quatd
}

// MARK: - SystemSnapshot

/// The state of every body of a ``SolarSystem`` at one instant.
public struct SystemSnapshot: Sendable {

  // MARK: Lifecycle

  public init(time: JulianDate, states: [BodyID: BodyState]) {
    self.time = time
    self.states = states
  }

  // MARK: Public

  public let time: JulianDate
  public let states: [BodyID: BodyState]

  /// The heliocentric J2000 ecliptic position of a body, AU.
  public func position(of id: BodyID) -> SIMD3<Double>? {
    states[id]?.position
  }
}

// MARK: - SolarSystem

/// Closed-form ephemeris: every body's state is a pure function of the Julian date.
///
/// Planet positions come from the JPL "Approximate Positions of the Planets" element tables (1800–2050); the
/// Moon uses the model selected by ``moonModel``.
///
/// ```swift
/// let system = SolarSystem()
/// let snapshot = system.snapshot(at: JulianDate(Date()))
/// let mars = snapshot.position(of: .mars)   // heliocentric J2000 ecliptic, AU
/// ```
public struct SolarSystem: Sendable {

  // MARK: Lifecycle

  /// Creates a system.
  ///
  /// - Parameters:
  ///   - bodies: The bodies to include. The default is ``Catalog/all``.
  ///   - moonModel: How the Moon's position is computed. The default is ``MoonModel/periodicTerms``.
  public init(bodies: [Body] = Catalog.all, moonModel: MoonModel = .periodicTerms) {
    self.bodies = bodies
    self.moonModel = moonModel
    byID = Dictionary(bodies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  /// Creates a system, choosing between the two mean-element Moon models with a flag.
  ///
  /// Source-compatible with the former `init(bodies:moonPeriodicTerms:)`. `true` is
  /// ``MoonModel/periodicTerms``, `false` is ``MoonModel/meanElements``.
  public init(bodies: [Body] = Catalog.all, moonPeriodicTerms: Bool) {
    self.init(bodies: bodies, moonModel: moonPeriodicTerms ? .periodicTerms : .meanElements)
  }

  // MARK: Public

  public let bodies: [Body]
  /// How the Moon's position is computed.
  public var moonModel: MoonModel

  /// Whether the Moon uses the three periodic longitude terms.
  ///
  /// `true` only for ``MoonModel/periodicTerms``. Setting it selects ``MoonModel/periodicTerms`` or
  /// ``MoonModel/meanElements``.
  public var moonPeriodicTerms: Bool {
    get { moonModel == .periodicTerms }
    set { moonModel = newValue ? .periodicTerms : .meanElements }
  }

  public func body(_ id: BodyID) -> Body? {
    byID[id]
  }

  /// The state of every body at `time`.
  public func snapshot(at time: JulianDate) -> SystemSnapshot {
    let T = time.centuriesSinceJ2000
    var positions = [BodyID: SIMD3<Double>]()

    // Heliocentric bodies first (Earth's row is the Earth–Moon barycentre).
    for body in bodies where body.id != .moon {
      if let elements = body.elements {
        positions[body.id] = Kepler.position(elements: elements, T: T)
      } else {
        positions[body.id] = .zero
      }
    }

    // Moon, and the barycentre correction for Earth.
    if
      let moon = byID[.moon], let emb = positions[.earth],
      let geo = Self.moonGeocentric(moon, T: T, model: moonModel)
    {
      let earth = emb - geo / Self.earthMoonBarycentreDivisor
      positions[.earth] = earth
      positions[.moon] = earth + geo
    }

    var states = [BodyID: BodyState]()
    for body in bodies {
      guard let position = positions[body.id] else { continue }
      let orientation: simd_quatd =
        switch body.id {
        case .earth:
          BodyOrientation.earth(at: time)

        case .moon:
          BodyOrientation.tidallyLocked(
            toParent: (positions[.earth] ?? .zero) - position
          )

        default:
          BodyOrientation.generic(body: body, at: time)
        }
      states[body.id] = BodyState(id: body.id, position: position, orientation: orientation)
    }
    return SystemSnapshot(time: time, states: states)
  }

  /// Closed orbit outline, parent-relative, using the elements frozen at `time`.
  ///
  /// Returns `samples` points (the caller closes the loop). Empty for the Sun.
  public func orbitPath(of id: BodyID, at time: JulianDate, samples: Int) -> [SIMD3<Double>] {
    guard let el = byID[id]?.elements, samples > 0 else { return [] }
    let T = time.centuriesSinceJ2000
    let d = Units.degToRad
    let offset = id == .moon ? MoonEphemeris.frameOffsetDeg(T: T) : 0
    let a = el.a + el.aRate * T
    let e = el.e + el.eRate * T
    let I = (el.i + el.iRate * T) * d
    let peri = (el.peri + el.periRate * T + offset) * d
    let node = (el.node + el.nodeRate * T + offset) * d
    return (0..<samples).map { k in
      let M = 2 * .pi * Double(k) / Double(samples) - .pi
      return Kepler.position(a: a, e: e, I: I, argPeri: peri - node, node: node, meanAnomaly: M)
    }
  }

  // MARK: Internal

  /// Earth/Moon mass ratio plus one: Earth sits `moonGeocentric / this` from the barycentre.
  static let earthMoonBarycentreDivisor = 82.30057

  /// Heliocentric J2000 ecliptic positions (AU) of Earth's centre and the Moon, from the Earth–Moon barycentre row
  /// of ``Catalog/earth`` and the chosen Moon model.
  static func earthAndMoonPositions(T: Double, model: MoonModel) -> (earth: SIMD3<Double>, moon: SIMD3<Double>) {
    // Catalog.earth and Catalog.moon always carry elements.
    let emb = Kepler.position(elements: Catalog.earth.elements!, T: T)
    let geo = moonGeocentric(Catalog.moon, T: T, model: model)!
    let earth = emb - geo / earthMoonBarycentreDivisor
    return (earth, earth + geo)
  }

  /// Geocentric Moon position for `model`; `nil` when the model needs elements the body lacks.
  static func moonGeocentric(_ moon: Body, T: Double, model: MoonModel) -> SIMD3<Double>? {
    switch model {
    case .series:
      return MoonEphemeris.geocentricPositionSeries(T: T)
    case .meanElements, .periodicTerms:
      guard let elements = moon.elements else { return nil }
      return MoonEphemeris.geocentricPosition(elements: elements, T: T, periodicTerms: model == .periodicTerms)
    }
  }

  // MARK: Private

  private let byID: [BodyID: Body]
}
