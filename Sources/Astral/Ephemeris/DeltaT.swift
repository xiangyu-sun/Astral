//
//  DeltaT.swift
//

import Foundation

// MARK: - DeltaT

/// ΔT = TT − UT1 in seconds, from the Espenak & Meeus polynomial expressions.
///
/// The expressions are the ones published by NASA GSFC (Fred Espenak), adapted from "Five Millennium Canon of Solar
/// Eclipses" and based on Morrison & Stephenson (2004), see
/// <https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html>. They cover the years -1999 to +3000:
/// before -500 and after 2150 the long-term parabola `-20 + 32 u²` (`u = (year - 1820) / 100`) is used.
///
/// Notes:
/// - The Canon's small correction `c = -0.000012932 (y - 1955)²` for the ELP-2000/82 lunar acceleration is **not**
///   applied, which is the usual modern convention.
/// - After about 2005 the values are extrapolations. ΔT is not predictable, so treat results beyond the last
///   observed epoch as estimates, with uncertainty growing to seconds within a decade or two.
/// - The polynomials reproduce the historical tables to within a few seconds before 1600 (up to about 4 s between
///   -500 and +500), and to well under a second in the 20th century.
///
/// ```swift
/// let dt = DeltaT.seconds(decimalYear: 2000.0)   // ≈ 63.8 s
/// let dtNow = DeltaT.seconds(at: JulianDate(Date()))
/// ```
public enum DeltaT {

  // MARK: Public

  /// ΔT (TT − UT) in seconds for a decimal year `y = year + (month - 0.5) / 12`.
  public static func seconds(decimalYear y: Double) -> Double {
    if y < -500 {
      return longTermParabola(y)
    } else if y < 500 {
      let u = y / 100
      return 10583.6 - 1014.41 * u + 33.78311 * u * u - 5.952053 * pow(u, 3)
        - 0.1798452 * pow(u, 4) + 0.022174192 * pow(u, 5) + 0.0090316521 * pow(u, 6)
    } else if y < 1600 {
      let u = (y - 1000) / 100
      return 1574.2 - 556.01 * u + 71.23472 * u * u + 0.319781 * pow(u, 3)
        - 0.8503463 * pow(u, 4) - 0.005050998 * pow(u, 5) + 0.0083572073 * pow(u, 6)
    } else if y < 1700 {
      let t = y - 1600
      return 120 - 0.9808 * t - 0.01532 * t * t + pow(t, 3) / 7129
    } else if y < 1800 {
      let t = y - 1700
      return 8.83 + 0.1603 * t - 0.0059285 * t * t + 0.00013336 * pow(t, 3) - pow(t, 4) / 1_174_000
    } else if y < 1860 {
      let t = y - 1800
      return 13.72 - 0.332447 * t + 0.0068612 * t * t + 0.0041116 * pow(t, 3) - 0.00037436 * pow(t, 4)
        + 0.0000121272 * pow(t, 5) - 0.0000001699 * pow(t, 6) + 0.000000000875 * pow(t, 7)
    } else if y < 1900 {
      let t = y - 1860
      return 7.62 + 0.5737 * t - 0.251754 * t * t + 0.01680668 * pow(t, 3)
        - 0.0004473624 * pow(t, 4) + pow(t, 5) / 233_174
    } else if y < 1920 {
      let t = y - 1900
      return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * pow(t, 3) - 0.000197 * pow(t, 4)
    } else if y < 1941 {
      let t = y - 1920
      return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * pow(t, 3)
    } else if y < 1961 {
      let t = y - 1950
      return 29.07 + 0.407 * t - t * t / 233 + pow(t, 3) / 2547
    } else if y < 1986 {
      let t = y - 1975
      return 45.45 + 1.067 * t - t * t / 260 - pow(t, 3) / 718
    } else if y < 2005 {
      let t = y - 2000
      return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * pow(t, 3) + 0.000651814 * pow(t, 4)
        + 0.00002373599 * pow(t, 5)
    } else if y < 2050 {
      let t = y - 2000
      return 62.92 + 0.32217 * t + 0.005589 * t * t
    } else if y <= 2150 {
      let u = (y - 1820) / 100
      return -20 + 32 * u * u - 0.5628 * (2150 - y)
    } else {
      return longTermParabola(y)
    }
  }

  /// ΔT (TT − UT) in seconds at a Julian date (the date is read as UT, the difference to UTC is negligible here).
  ///
  /// The decimal year is computed continuously on the proleptic Gregorian calendar,
  /// `year + (dayOfYear - 1 + dayFraction) / daysInYear`, rather than at mid-month as in the NASA definition.
  public static func seconds(at jd: JulianDate) -> Double {
    seconds(decimalYear: decimalYear(of: jd))
  }

  /// The decimal year `year + (dayOfYear - 1 + dayFraction) / daysInYear` of a Julian date (proleptic Gregorian).
  public static func decimalYear(of jd: JulianDate) -> Double {
    // Days since 1970-01-01 00:00 and the fraction of that day.
    let sinceUnixEpoch = jd.days - unixEpochJD
    let z = sinceUnixEpoch.rounded(.down)
    let fraction = sinceUnixEpoch - z
    let (year, month, day) = civilFromDays(Int(z))
    let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    let cumulative = isLeap ? cumulativeDaysLeap : cumulativeDaysCommon
    let dayOfYear = Double(cumulative[month - 1] + day - 1) + fraction
    return Double(year) + dayOfYear / (isLeap ? 366 : 365)
  }

  // MARK: Private

  private static let unixEpochJD = 2_440_587.5
  private static let cumulativeDaysCommon = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
  private static let cumulativeDaysLeap = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

  private static func longTermParabola(_ y: Double) -> Double {
    let u = (y - 1820) / 100
    return -20 + 32 * u * u
  }

  /// Proleptic Gregorian date from days since 1970-01-01 (H. Hinnant's `civil_from_days`).
  private static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
    let z = days + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let day = doy - (153 * mp + 2) / 5 + 1
    let month = mp < 10 ? mp + 3 : mp - 9
    let year = yoe + era * 400 + (month <= 2 ? 1 : 0)
    return (year, month, day)
  }
}

// MARK: - LeapSeconds

/// TAI − UTC, the accumulated leap seconds since 1972, and the resulting TT − UTC.
///
/// The table is transcribed from NAIF's `naif0012.tls` leapseconds kernel (`DELTET/DELTA_AT`), last entry
/// 2017-01-01 (TAI − UTC = 37 s). `TT = TAI + 32.184 s`.
///
/// Policy:
/// - From 1972-01-01 on, `TT − UTC = (TAI − UTC) + 32.184 s`. For dates after the last known leap second the last
///   value is held, so `TT − UTC = 69.184 s`; a future leap second is not predicted.
/// - Before 1972-01-01 UTC did not have whole leap seconds; `TT − UTC` is taken from ``DeltaT`` (UT ≈ UTC), which is
///   accurate to a fraction of a second there.
public enum LeapSeconds {

  // MARK: Public

  /// TT − TAI in seconds (exact, by definition).
  public static let ttMinusTAI = 32.184

  /// The TAI − UTC value after the last known leap second (2017-01-01), in seconds.
  public static var latestTAIMinusUTC: Double { Double(table[table.count - 1].taiMinusUTC) }

  /// The Julian date (UTC) of the first leap-second-era epoch, 1972-01-01 00:00.
  public static var firstEpoch: JulianDate { JulianDate(days: table[0].jd) }

  /// TAI − UTC in seconds at a UTC Julian date, or `nil` before 1972-01-01.
  public static func taiMinusUTC(at utc: JulianDate) -> Double? {
    guard utc.days >= table[0].jd else {
      return nil
    }
    // Last entry whose effective date is <= utc.
    var result = table[0].taiMinusUTC
    for entry in table {
      if utc.days >= entry.jd { result = entry.taiMinusUTC } else { break }
    }
    return Double(result)
  }

  /// TT − UTC in seconds at a UTC Julian date.
  ///
  /// Uses leap seconds from 1972-01-01 on (holding the last value, 69.184 s, afterwards) and ``DeltaT`` before.
  public static func ttMinusUTC(at utc: JulianDate) -> Double {
    if let tai = taiMinusUTC(at: utc) {
      return tai + ttMinusTAI
    }
    return DeltaT.seconds(at: utc)
  }

  // MARK: Internal

  /// A leap-second table entry: from `jd` (UTC, 0h) on, TAI − UTC is `taiMinusUTC` seconds.
  struct Entry: Sendable, Hashable {
    let year: Int
    let month: Int
    let jd: Double
    let taiMinusUTC: Int
  }

  /// `DELTET/DELTA_AT` from naif0012.tls. Immutable.
  static let table: [Entry] = [
    .init(year: 1972, month: 1, jd: 2_441_317.5, taiMinusUTC: 10),
    .init(year: 1972, month: 7, jd: 2_441_499.5, taiMinusUTC: 11),
    .init(year: 1973, month: 1, jd: 2_441_683.5, taiMinusUTC: 12),
    .init(year: 1974, month: 1, jd: 2_442_048.5, taiMinusUTC: 13),
    .init(year: 1975, month: 1, jd: 2_442_413.5, taiMinusUTC: 14),
    .init(year: 1976, month: 1, jd: 2_442_778.5, taiMinusUTC: 15),
    .init(year: 1977, month: 1, jd: 2_443_144.5, taiMinusUTC: 16),
    .init(year: 1978, month: 1, jd: 2_443_509.5, taiMinusUTC: 17),
    .init(year: 1979, month: 1, jd: 2_443_874.5, taiMinusUTC: 18),
    .init(year: 1980, month: 1, jd: 2_444_239.5, taiMinusUTC: 19),
    .init(year: 1981, month: 7, jd: 2_444_786.5, taiMinusUTC: 20),
    .init(year: 1982, month: 7, jd: 2_445_151.5, taiMinusUTC: 21),
    .init(year: 1983, month: 7, jd: 2_445_516.5, taiMinusUTC: 22),
    .init(year: 1985, month: 7, jd: 2_446_247.5, taiMinusUTC: 23),
    .init(year: 1988, month: 1, jd: 2_447_161.5, taiMinusUTC: 24),
    .init(year: 1990, month: 1, jd: 2_447_892.5, taiMinusUTC: 25),
    .init(year: 1991, month: 1, jd: 2_448_257.5, taiMinusUTC: 26),
    .init(year: 1992, month: 7, jd: 2_448_804.5, taiMinusUTC: 27),
    .init(year: 1993, month: 7, jd: 2_449_169.5, taiMinusUTC: 28),
    .init(year: 1994, month: 7, jd: 2_449_534.5, taiMinusUTC: 29),
    .init(year: 1996, month: 1, jd: 2_450_083.5, taiMinusUTC: 30),
    .init(year: 1997, month: 7, jd: 2_450_630.5, taiMinusUTC: 31),
    .init(year: 1999, month: 1, jd: 2_451_179.5, taiMinusUTC: 32),
    .init(year: 2006, month: 1, jd: 2_453_736.5, taiMinusUTC: 33),
    .init(year: 2009, month: 1, jd: 2_454_832.5, taiMinusUTC: 34),
    .init(year: 2012, month: 7, jd: 2_456_109.5, taiMinusUTC: 35),
    .init(year: 2015, month: 7, jd: 2_457_204.5, taiMinusUTC: 36),
    .init(year: 2017, month: 1, jd: 2_457_754.5, taiMinusUTC: 37),
  ]
}

// MARK: - JulianDate + TT

extension JulianDate {

  /// Creates a TT Julian date from a UTC one, adding `TT − UTC` (see ``LeapSeconds``).
  ///
  /// This is opt-in: Astral's ephemeris API treats the Julian date it is given as TT without converting, so pass
  /// `JulianDate(terrestrialTimeFromUTC: utc)` to get the rigorous result.
  public init(terrestrialTimeFromUTC utc: JulianDate) {
    self.init(days: utc.days + LeapSeconds.ttMinusUTC(at: utc) / 86_400)
  }

  /// Creates a UTC Julian date from a TT one (the inverse of ``init(terrestrialTimeFromUTC:)``).
  public init(utcFromTerrestrialTime tt: JulianDate) {
    // TT − UTC is piecewise constant (or slowly varying before 1972), so a couple of fixed-point steps converge.
    var utc = tt
    for _ in 0..<3 {
      utc = JulianDate(days: tt.days - LeapSeconds.ttMinusUTC(at: utc) / 86_400)
    }
    self = utc
  }

  /// This UTC Julian date expressed as TT.
  public var terrestrialTime: JulianDate {
    JulianDate(terrestrialTimeFromUTC: self)
  }

  /// This TT Julian date expressed as UTC.
  public var utcFromTerrestrialTime: JulianDate {
    JulianDate(utcFromTerrestrialTime: self)
  }

  /// TT − UTC in seconds at this UTC Julian date.
  public var ttMinusUTCSeconds: Double {
    LeapSeconds.ttMinusUTC(at: self)
  }
}
