import Foundation

/// Calculates the Greenwich Mean Sidereal Time (GMST) in degrees for a given date.
///
/// GMST is computed using the formula (from [Zhao's page](https://lweb.cfa.harvard.edu/~jzhao/times.html)):
///
///     GMST = 280.46061837 + 360.98564736629 × JD2000 + 0.000387933 × T² + T³ / 38710000
///
/// where:
///   - JD2000 is the Julian Day offset from J2000.0 (i.e. JD − 2451545.0),
///   - T = JD2000 / 36525 (i.e. the number of Julian centuries since J2000.0).
///
/// The result is then normalized to the range [0, 360).
///
/// - Parameter dateComponents: The UTC date as `DateComponents`.
/// - Returns: The GMST in degrees.
func gmst(dateComponents: DateComponents) -> Degrees {
  // Compute the Julian Day offset from J2000.0.
  let jd2000 = julianDay2000(at: dateComponents)
  
  // Compute the number of Julian centuries since J2000.0.
  let T = jd2000 / 36525.0
  let T2 = T * T
  let T3 = T * T * T
  
  let value = 280.46061837
    + 360.98564736629 * jd2000
    + 0.000387933 * T2
    + T3 / 38710000.0
  
  // Normalize the value to the range [0, 360).
  var r = value.truncatingRemainder(dividingBy: 360.0)
  if r < 0 {
    r += 360
  }
  return r
}

/// Calculates the Local Mean Sidereal Time (LMST) in degrees for a given date and observer's longitude.
///
/// LMST is obtained by adjusting GMST by the observer’s longitude:
///
///     LMST = GMST + longitude
///
/// Note that the observer's longitude should be given in degrees (positive eastward).
///
/// - Parameters:
///   - dateComponents: The UTC date as `DateComponents`.
///   - longitude: The observer's longitude in degrees.
/// - Returns: The LMST in degrees, normalized to the range [0, 360).
func lmst(dateComponents: DateComponents, longitude: Degrees) -> Degrees {
  let gmstValue = gmst(dateComponents: dateComponents)
  let localMst = gmstValue + longitude
  // Normalize the result to [0, 360).
  let normalized = localMst.truncatingRemainder(dividingBy: 360.0)
  return normalized < 0 ? normalized + 360 : normalized
}
