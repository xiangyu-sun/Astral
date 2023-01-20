import Numerics


/// Calculate the degrees of refraction of the sun due to the sun's elevation.
/// - Parameter zenith: <#zenith description#>
/// - Returns: <#description#>
func refractionAtZenith(_ zenith: Double) -> Double {
  let elevation = 90 - zenith
  guard zenith <= 85 else {
    return 0
  }
  
  var refractionCorrection: Double = 0
  
  let te = Double.tan(Angle.deg2rad(elevation))
  
  if elevation > 5 {
    refractionCorrection = (
                58.1 / te - 0.07 / (te * te * te) + 0.000086 / (te * te * te * te * te)
            )
  } else if elevation > -0.575 {
    let step1 = -12.79 + elevation * 0.711
    let step2 = 103.4 + elevation * step1
    let step3 = -518.2 + elevation * step2
    refractionCorrection = 1735.0 + elevation * step3
  } else {
    refractionCorrection = -20.774 / te
  }
  
  refractionCorrection = refractionCorrection / 3600.0
  
  return refractionCorrection
}
