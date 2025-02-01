import Foundation

/// Computes the Moon’s age (in days) as a floating–point number for a given date.
/// This function uses a simplified version of the Meeus algorithm.
///
/// - Parameter date: The date (in UTC) for which to compute the moon phase.
/// - Returns: The Moon’s age (0 … ~29.53), where 0 is a New Moon.
func _phase_asfloat(date: DateComponents) -> Double {
  // Compute the Julian Day for the specified date.
  let jd = julianDay(at: date)
  
  // Compute the number of Julian centuries since J2000.0.
  // (No extra dt correction is applied here.)
  let t = (jd - 2451545.0) / 36525.0
  let t2 = t * t
  let t3 = t2 * t
  
  // Mean elongation of the Moon, D (in degrees)
  var d = 297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868.0
  d = d.truncatingRemainder(dividingBy: 360.0)
  if d < 0 { d += 360 }
  
  // Sun's mean anomaly, M (in degrees)
  var m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0
  m = m.truncatingRemainder(dividingBy: 360.0)
  if m < 0 { m += 360 }
  
  // Moon's mean anomaly, M' (in degrees)
  var m1 = 134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699.0
  m1 = m1.truncatingRemainder(dividingBy: 360.0)
  if m1 < 0 { m1 += 360 }
  
  // Convert angles to radians for the trigonometric functions.
  let dRad  = radians(d)
  let mRad  = radians(m)
  let m1Rad = radians(m1)
  
  // Compute the phase angle using an approximate formula.
  // (This expression is similar to that found in Meeus' "Astronomical Algorithms".)
  var phaseAngle = 180 - d - 6.289 * sin(m1Rad) + 2.1 * sin(mRad)
                   - 1.274 * sin(2 * dRad - m1Rad)
                   - 0.658 * sin(2 * dRad)
                   - 0.214 * sin(2 * m1Rad)
                   - 0.11  * sin(dRad)
  
  phaseAngle = phaseAngle.truncatingRemainder(dividingBy: 360)
  if phaseAngle < 0 { phaseAngle += 360 }
  
  // Map the phase angle to the Moon's age in days.
  // (The synodic month is taken as 29.53058867 days.)
  let synodicMonth = 29.53058867
  let moonAge = synodicMonth * (phaseAngle / 360.0)
  return moonAge
}


/// Calculates the phase of the Moon on the specified date.
/// The returned value is the Moon’s age in days (0 … ~29.53):
///
/// - 0 to ~7.38    New Moon to First Quarter
/// - ~7.38 to ~14.77   First Quarter to Full Moon
/// - ~14.77 to ~22.15  Full Moon to Last Quarter
/// - ~22.15 to ~29.53  Last Quarter to New Moon
///
/// - Parameter date: The date (in UTC) for which to calculate the phase.
///                   If not provided, today's date is used.
/// - Returns: The Moon's age in days.
func moonPhase(date: DateComponents = Date.now.components()) -> Double {
  var moon = _phase_asfloat(date: date)
  let synodicMonth = 29.53058867
  moon = moon.truncatingRemainder(dividingBy: synodicMonth)
  if moon < 0 {
    moon += synodicMonth
  }
  return moon
}
