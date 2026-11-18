//
//  MoonPhaseGeometry.swift
//
//  The `MoonPhase` type lives here (the file name differs from the top-level `MoonPhase.swift`, which holds the
//  free function `moonPhase(date:)` returning the Moon's age in days).
//

import Foundation
import simd

// MARK: - MoonPhase

/// The Moon's illumination as seen from Earth, derived from Sun–Earth–Moon geometry.
///
/// This is a type; the module's free function `moonPhase(date:)` (which returns the Moon's age in days) is
/// unaffected and `Astral.moonPhase(date:)` still resolves.
///
/// ```swift
/// let phase = MoonPhase(date: Date())
/// print(phase.name, phase.illuminatedFraction)
/// ```
public struct MoonPhase: Sendable, Equatable {

  // MARK: Lifecycle

  /// Creates the phase from heliocentric positions (any consistent frame and unit).
  public init(sun: SIMD3<Double>, earth: SIMD3<Double>, moon: SIMD3<Double>) {
    let toMoon = moon - earth
    let toSun = sun - earth
    var d = atan2(toMoon.y, toMoon.x) - atan2(toSun.y, toSun.x)
    d = d.truncatingRemainder(dividingBy: 2 * .pi)
    if d < 0 { d += 2 * .pi }
    elongation = d

    // Phase angle at the Moon between the Sun and Earth; lit fraction = (1 + cos i) / 2.
    let cosPhase = simd_dot(simd_normalize(sun - moon), simd_normalize(earth - moon))
    illuminatedFraction = (1 + cosPhase) / 2
  }

  /// Creates the phase at a Julian date from the planetary ephemeris.
  ///
  /// - Parameters:
  ///   - time: The instant (UTC is treated as TT).
  ///   - model: The Moon model used for the geometry. The default is `MoonModel.periodicTerms`.
  public init(at time: JulianDate, model: MoonModel = .periodicTerms) {
    let T = time.centuriesSinceJ2000
    let (earth, moon) = SolarSystem.earthAndMoonPositions(T: T, model: model)
    self.init(sun: .zero, earth: earth, moon: moon)
  }

  /// Creates the phase at a date from the planetary ephemeris.
  ///
  /// - Parameters:
  ///   - date: The instant.
  ///   - model: The Moon model used for the geometry. The default is `MoonModel.periodicTerms`.
  public init(date: Date, model: MoonModel = .periodicTerms) {
    self.init(at: JulianDate(date), model: model)
  }

  // MARK: Public

  /// The eight conventional phase names.
  public enum Name: String, Sendable, CaseIterable {
    case new = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case full = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"
  }

  /// Moon's ecliptic longitude minus the Sun's, as seen from Earth, radians in [0, 2π).
  /// 0 = new, π/2 = first quarter, π = full, 3π/2 = last quarter.
  public let elongation: Double
  /// Fraction of the Moon's disc that is sunlit as seen from Earth, 0...1.
  public let illuminatedFraction: Double

  /// Whether the Moon is waxing (elongation below π).
  public var isWaxing: Bool {
    elongation < .pi
  }

  /// The conventional phase name.
  public var name: Name {
    let deg = elongation * 180 / .pi
    switch deg {
    case ..<10, 350...: return .new
    case ..<80: return .waxingCrescent
    case ..<100: return .firstQuarter
    case ..<170: return .waxingGibbous
    case ..<190: return .full
    case ..<260: return .waningGibbous
    case ..<280: return .lastQuarter
    default: return .waningCrescent
    }
  }
}

extension SystemSnapshot {
  /// The Moon's phase, or `nil` when the snapshot has no Earth or Moon.
  public var moonPhase: MoonPhase? {
    guard let earth = position(of: .earth), let moon = position(of: .moon) else { return nil }
    return MoonPhase(sun: position(of: .sun) ?? .zero, earth: earth, moon: moon)
  }
}
