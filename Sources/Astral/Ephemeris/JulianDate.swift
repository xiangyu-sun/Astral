//
//  JulianDate.swift
//

import Foundation

/// A point in time expressed as a Julian date (days).
///
/// The ephemeris API treats UTC as TT: no ΔT correction is applied (about 69 s at present, which moves the Moon by
/// roughly 0.01°).
///
/// ```swift
/// let jd = JulianDate(Date())
/// let T = jd.centuriesSinceJ2000
/// ```
public struct JulianDate: Sendable, Hashable, Comparable {

  // MARK: Lifecycle

  /// Creates a Julian date from a number of Julian days, e.g. `2451545.0` is J2000.
  public init(days: Double) {
    self.days = days
  }

  /// Creates a Julian date from a `Date`.
  public init(_ date: Date) {
    days = Self.unixEpoch + date.timeIntervalSince1970 / 86_400
  }

  /// Creates a Julian date from calendar components, using Astral's existing Julian day algorithm.
  ///
  /// The year, month and day are required; hour, minute and second are optional. The components are interpreted as
  /// UTC (any `timeZone` set on them is ignored), matching the rest of Astral.
  ///
  /// - Returns: `nil` if the year, month or day is missing.
  public init?(_ components: DateComponents) {
    guard components.year != nil, components.month != nil, components.day != nil else {
      return nil
    }
    days = julianDay(at: components)
  }

  // MARK: Public

  /// J2000.0: 2000-01-01 12:00 TT.
  public static let j2000 = JulianDate(days: 2_451_545.0)

  /// Julian days, e.g. `2451545.0` is J2000.
  public var days: Double

  /// The equivalent `Date`.
  public var date: Date {
    Date(timeIntervalSince1970: (days - Self.unixEpoch) * 86_400)
  }

  /// Julian centuries since J2000.0, `(days - 2451545.0) / 36525`.
  public var centuriesSinceJ2000: Double {
    (days - Self.j2000.days) / 36_525
  }

  /// Whether the element tables are within their fitted range.
  ///
  /// The planetary element tables are fitted for 1800–2050; outside that range accuracy degrades.
  public var isInSupportedRange: Bool {
    // 1800-01-01 00:00 ... 2051-01-01 00:00
    days >= 2_378_496.5 && days < 2_470_172.5
  }

  public static func < (lhs: JulianDate, rhs: JulianDate) -> Bool {
    lhs.days < rhs.days
  }

  // MARK: Private

  private static let unixEpoch = 2_440_587.5
}
