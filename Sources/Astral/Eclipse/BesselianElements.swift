//
//  BesselianElements.swift
//

import Foundation

// MARK: - SolarEclipseType

/// The global type of a solar eclipse.
public enum SolarEclipseType: String, Sendable, Hashable, CaseIterable {
  /// The Moon's umbral shadow never reaches the Earth's surface.
  case partial
  /// The Moon is too far away to cover the Sun anywhere: a ring of sunlight remains (the antumbra reaches Earth).
  case annular
  /// The Moon's umbra reaches the Earth's surface.
  case total
  /// Annular along part of the path and total along another part.
  case hybrid
}

// MARK: - BesselianElements

/// Polynomial Besselian elements of one solar eclipse.
///
/// The Moon's shadow is described on the *fundamental plane* through the Earth's centre, perpendicular to the shadow
/// axis, in units of the Earth's equatorial radius (Explanatory Supplement to the Astronomical Ephemeris; Meeus,
/// *Elements of Solar Eclipses*; NASA GSFC "Five Millennium Canon of Solar Eclipses", Espenak & Meeus).
/// With `t = hours since t0` (TDT) each element is `a = a0 + a1 t + a2 t² + a3 t³`:
///
/// - `x`, `y`: the shadow axis in the fundamental plane (x east, y north),
/// - `d`: declination of the shadow axis (degrees),
/// - `mu`: ephemeris hour angle of the shadow axis (degrees),
/// - `l1`, `l2`: radii of the penumbra and umbra on the fundamental plane (`l2 < 0` for the total umbra),
/// - `tanF1`, `tanF2`: tangents of the cone half-angles of the penumbra and umbra.
///
/// The built-in table ``catalog`` holds the solar eclipses of 2023 to 2035 as published by NASA GSFC. Elements can
/// also be created from any source, for example another Canon or your own predictions.
///
/// ```swift
/// let eclipse = BesselianElements.catalog.first { $0.label == "2024-04-08" }!
/// if let local = eclipse.localCircumstances(observer: dallas) {
///   print(local.type, local.maximum.date, local.magnitude)
/// }
/// ```
///
/// ### Time scales
/// The elements are functions of TDT (TT). Contact times are reported in UT: `UT = TT − ΔT`, with the ΔT stored in the
/// elements (NASA's prediction at publication time for the built-in table). UT1 and UTC differ by less than 0.9 s,
/// so the returned `Date`s are UTC to within a second. Use ``withDeltaT(_:)`` to supply the measured ΔT.
public struct BesselianElements: Sendable, Hashable {

  // MARK: Lifecycle

  /// Creates elements.
  ///
  /// - Parameters:
  ///   - label: A free-form name, e.g. `"2024-04-08"`.
  ///   - publishedType: The eclipse type as published by the source, if known (informational).
  ///   - t0: The reference epoch of the polynomials in TDT (TT).
  ///   - deltaT: ΔT = TT − UT in seconds.
  ///   - x: Coefficients of `x` (Earth radii, per hour^n), `y`: of `y`.
  ///   - d: Coefficients of the axis declination (degrees).
  ///   - mu: Coefficients of the ephemeris hour angle (degrees).
  ///   - l1: Coefficients of the penumbral radius, `l2` of the umbral radius.
  ///   - tanF1: Tangent of the penumbral cone angle, `tanF2` of the umbral cone angle.
  ///   - validHours: Hours around `t0` for which the polynomials were fitted (default ±3 h).
  public init(
    label: String = "",
    publishedType: SolarEclipseType? = nil,
    t0: JulianDate,
    deltaT: Double,
    x: [Double],
    y: [Double],
    d: [Double],
    mu: [Double],
    l1: [Double],
    l2: [Double],
    tanF1: Double,
    tanF2: Double,
    validHours: ClosedRange<Double> = -3...3
  ) {
    self.label = label
    self.publishedType = publishedType
    self.t0 = t0
    self.deltaT = deltaT
    self.x = x
    self.y = y
    self.d = d
    self.mu = mu
    self.l1 = l1
    self.l2 = l2
    self.tanF1 = tanF1
    self.tanF2 = tanF2
    self.validHours = validHours
  }

  /// Creates elements whose epoch is given as a calendar date (Gregorian) and a fractional hour of TDT.
  public init(
    label: String = "",
    publishedType: SolarEclipseType? = nil,
    t0Year: Int,
    t0Month: Int,
    t0Day: Int,
    t0Hours: Double,
    deltaT: Double,
    x: [Double],
    y: [Double],
    d: [Double],
    mu: [Double],
    l1: [Double],
    l2: [Double],
    tanF1: Double,
    tanF2: Double,
    validHours: ClosedRange<Double> = -3...3
  ) {
    let midnight = julianDay(at: DateComponents(year: t0Year, month: t0Month, day: t0Day))
    self.init(
      label: label,
      publishedType: publishedType,
      t0: JulianDate(days: midnight + t0Hours / 24),
      deltaT: deltaT,
      x: x,
      y: y,
      d: d,
      mu: mu,
      l1: l1,
      l2: l2,
      tanF1: tanF1,
      tanF2: tanF2,
      validHours: validHours
    )
  }

  // MARK: Public

  /// A free-form name, e.g. `"2024-04-08"`.
  public var label: String
  /// The type published by the source, if known.
  public var publishedType: SolarEclipseType?
  /// The reference epoch `t0` in TDT (TT).
  public var t0: JulianDate
  /// ΔT = TT − UT in seconds.
  public var deltaT: Double
  public var x: [Double]
  public var y: [Double]
  /// Declination of the shadow axis, degrees.
  public var d: [Double]
  /// Ephemeris hour angle of the shadow axis, degrees.
  public var mu: [Double]
  public var l1: [Double]
  public var l2: [Double]
  public var tanF1: Double
  public var tanF2: Double
  /// Hours around `t0` over which the polynomials were fitted. Evaluation outside is allowed but less accurate.
  public var validHours: ClosedRange<Double>

  /// A copy with a different ΔT (seconds), e.g. the measured value.
  public func withDeltaT(_ seconds: Double) -> BesselianElements {
    var copy = self
    copy.deltaT = seconds
    return copy
  }

  /// UT Julian date for `hours` after `t0` (TDT).
  public func universalTime(atHoursFromT0 hours: Double) -> JulianDate {
    JulianDate(days: t0.days + hours / 24 - deltaT / 86_400)
  }

  /// Hours after `t0` (TDT) for a UT instant.
  public func hoursFromT0(universalTime ut: JulianDate) -> Double {
    (ut.days - t0.days) * 24 + deltaT / 3600
  }

  // MARK: Internal

  static func poly(_ c: [Double], _ t: Double) -> Double {
    var r = 0.0
    for coefficient in c.reversed() { r = r * t + coefficient }
    return r
  }

  static func derivative(_ c: [Double], _ t: Double) -> Double {
    var r = 0.0
    for (n, coefficient) in c.enumerated().reversed() where n > 0 { r = r * t + Double(n) * coefficient }
    return r
  }

  /// The elements at `t` hours after `t0`, with their hourly derivatives. Angles in radians.
  func state(at t: Double) -> BesselianState {
    let rad = Double.pi / 180
    return BesselianState(
      x: Self.poly(x, t),
      y: Self.poly(y, t),
      d: Self.poly(d, t) * rad,
      mu: Self.poly(mu, t) * rad,
      l1: Self.poly(l1, t),
      l2: Self.poly(l2, t),
      dx: Self.derivative(x, t),
      dy: Self.derivative(y, t),
      dd: Self.derivative(d, t) * rad,
      dmu: Self.derivative(mu, t) * rad
    )
  }

}

// MARK: - BesselianState

/// Besselian elements evaluated at one instant (angles in radians, derivatives per hour).
struct BesselianState {
  var x: Double
  var y: Double
  var d: Double
  var mu: Double
  var l1: Double
  var l2: Double
  var dx: Double
  var dy: Double
  var dd: Double
  var dmu: Double
}
