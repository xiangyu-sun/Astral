import Foundation

/// Computes the Moon's age (in days) as a floating-point number for a given date.
/// Uses geocentric elongation method based on Meeus Chapter 48:
/// 1. Compute Sun's apparent ecliptic longitude
/// 2. Compute Moon's true ecliptic longitude
/// 3. Compute the actual elongation (Moon longitude - Sun longitude)
/// 4. Map elongation to moon age
///
/// - Parameter date: The date (in UTC) for which to compute the moon phase.
/// - Returns: The Moon's age (0 ... ~29.53), where 0 is a New Moon.
func _phase_asfloat(date: DateComponents) -> Double {
  let jd = julianDay(at: date)
  let jc = julianDayToCentury(julianDay: jd)
  let jd2000 = jd - 2451545.0

  // Sun's apparent ecliptic longitude (degrees)
  let sunLongDeg = sun_apparent_long(juliancentury: jc)

  // Moon's true ecliptic longitude (revolutions -> degrees)
  let moonLongDeg = moon_true_longitude(jd2000: jd2000) * 360.0

  // Actual elongation: Moon longitude - Sun longitude, normalized to [0, 360)
  var elongation = moonLongDeg - sunLongDeg
  elongation = elongation.truncatingRemainder(dividingBy: 360.0)
  if elongation < 0 { elongation += 360.0 }

  // Map elongation directly to moon age
  // elongation = 0 -> new moon (age = 0)
  // elongation = 90 -> first quarter (age ~ 7.38)
  // elongation = 180 -> full moon (age ~ 14.77)
  // elongation = 270 -> last quarter (age ~ 22.15)
  // elongation = 360 -> new moon (age ~ 29.53)
  let synodicMonth = 29.53058867
  let moonAge = synodicMonth * elongation / 360.0

  return moonAge
}

/// Calculates the phase of the Moon on the specified date.
/// The returned value is the Moon's age in days (0 ... ~29.53):
///
/// - 0 to ~7.38    New Moon to First Quarter
/// - ~7.38 to ~14.77   First Quarter to Full Moon
/// - ~14.77 to ~22.15  Full Moon to Last Quarter
/// - ~22.15 to ~29.53  Last Quarter to New Moon
///
/// - Parameter date: The date (in UTC) for which to calculate the phase.
///                   If not provided, today's date is used.
/// - Returns: The Moon's age in days.
public func moonPhase(date: DateComponents = Date().components()) -> Double {
  var moon = _phase_asfloat(date: date)
  let synodicMonth = 29.53058867
  moon = moon.truncatingRemainder(dividingBy: synodicMonth)
  if moon < 0 {
    moon += synodicMonth
  }
  return moon
}
