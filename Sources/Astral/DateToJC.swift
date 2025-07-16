import Foundation

extension Date {
  /// Converts the date to the number of Julian centuries since J2000.0.
  ///
  /// The conversion first determines the Julian Day for the date in UTC and
  /// then transforms that value into Julian centuries.
  public var toJC2000: Double {
    let utcTimeZone = TimeZone.utc
    let components = self.components(timezone: utcTimeZone)

    // Compute Julian Day and Julian Century.
    let jd = julianDay(at: components)
    return julianDayToCentury(julianDay: jd)
  }

}
