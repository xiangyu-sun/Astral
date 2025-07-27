import Numerics

/// Calculates the atmospheric refraction correction (in degrees) for the Sun given its zenith angle.
/// Atmospheric refraction causes the apparent position of the Sun to be higher than its geometric position.
/// The correction is computed in three regimes based on the solar elevation (where elevation = 90° – zenith):
///
/// 1. **High Elevations (elevation > 5°):**
///    Uses the formula (in arcseconds):
///      R = 58.1 / tan(e) − 0.07 / tan(e)³ + 0.000086 / tan(e)⁵
///
/// 2. **Intermediate Elevations (−0.575° < elevation ≤ 5°):**
///    Uses a polynomial approximation (in arcseconds):
///      R = 1735 + e · (−518.2 + e · (103.4 + e · (−12.79 + 0.711 · e)))
///
/// 3. **Low or Negative Elevations (elevation ≤ −0.575°):**
///    Uses the formula (in arcseconds):
///      R = −20.774 / tan(e)
///
/// The computed refraction (in arcseconds) is then converted to degrees by dividing by 3600.
///
/// - Parameter zenith: The zenith angle of the Sun (in degrees). (Zenith is the angle from the vertical.)
/// - Returns: The atmospheric refraction correction (in degrees).
func refractionAtZenith(_ zenith: Double) -> Double {
  // Compute the solar elevation (in degrees); elevation is complementary to the zenith angle.
  let elevation = 90 - zenith

  // Calculate the tangent of the elevation angle.
  // Angle.deg2rad(elevation) is assumed to convert degrees to radians.
  let te = Double.tan(Angle.deg2rad(elevation))

  var refractionCorrection = 0.0

  // Use different formulas based on the value of the solar elevation.
  if elevation > 5 {
    // For elevations greater than 5° (i.e. when the Sun is well above the horizon)
    // use the standard refraction formula.
    refractionCorrection = 58.1 / te
      - 0.07 / (te * te * te)
      + 0.000086 / (te * te * te * te * te)
  } else if elevation > -0.575 {
    // For elevations between -0.575° and 5°, use a polynomial approximation.
    let step1 = -12.79 + elevation * 0.711
    let step2 = 103.4 + elevation * step1
    let step3 = -518.2 + elevation * step2
    refractionCorrection = 1735.0 + elevation * step3
  } else {
    // For very low or negative elevations (i.e. when the Sun is below the horizon)
    // use an alternative approximation.
    refractionCorrection = -20.774 / te
  }

  // Convert the refraction correction from arcseconds to degrees.
  refractionCorrection /= 3600.0

  return refractionCorrection
}
