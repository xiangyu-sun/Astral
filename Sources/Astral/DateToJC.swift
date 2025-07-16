import Foundation

extension Date {
  public var toJC2000: Double {
    let utcTimeZone = TimeZone.utc
    let components = self.components(timezone: utcTimeZone)
    
    // Compute Julian Day and Julian Century.
    let jd = julianDay(at: components)
    return julianDayToCentury(julianDay: jd)
  }

}
