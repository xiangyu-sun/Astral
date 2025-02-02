import Foundation


/// 根据当前日期（或指定日期）计算太阳的视黄经，并推算对应的二十四节气。
func currentSolarTerm(for date: Date = Date()) -> Double {
  // 将当前日期转换为 UTC 下的 DateComponents（确保天文计算的一致性）
  let utcTimeZone = TimeZone.gmt
  let components = date.components(timezone: utcTimeZone)
  
  // 计算 Julian Day 与 Julian Century
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)
  
  // 计算太阳的视黄经（单位：度）
  let apparentLong = sun_apparent_long(juliancentury: jc)
  
  // 归一化到 [0, 360) 度
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
  
  // 每个节气跨越 15°，这里假设 0° 对应某个节气边界（例如“春分”或“冬至”，具体视你采用的体系而定）。
  // 为了四舍五入到最近的节气边界，这里先加上 7.5°。
  return (normalizedLong + 7.5) / 15
}

/// Returns the number of days remaining until the next solar term boundary.
///
/// The calculation is based on:
///   - Computing the Sun’s apparent ecliptic longitude (in degrees) at the given date.
///   - Normalizing the longitude to [0, 360).
///   - Recognizing that (with an offset of 7.5°) solar term boundaries occur when:
///         normalizedLong + 7.5 = 15 * k
///     so that the next boundary (in degrees) is at:
///         nextBoundary = 15 * ceil((normalizedLong + 7.5)/15) - 7.5
///   - Converting the angular difference to days using an average solar motion of ~0.9856°/day.
func daysUntilNextSolarTerm(from date: Date = Date()) -> Double {
  // Ensure we use UTC so that our astronomical calculations remain consistent.
  let utcTimeZone = TimeZone.gmt
  let components = date.components(timezone: utcTimeZone)
  
  // Compute Julian Day and Julian Century from the date components.
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)
  
  // Compute the Sun’s apparent ecliptic longitude (in degrees).
  let apparentLong = sun_apparent_long(juliancentury: jc)
  
  // Normalize the longitude to [0, 360).
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360)
    .truncatingRemainder(dividingBy: 360)
  
  // The boundaries occur when (normalizedLong + 7.5) is an exact multiple of 15.
  // Thus, the current (continuous) solar term value is:
  let currentTermValue = currentSolarTerm()
  // The next boundary will correspond to the next integer value.
  let nextTermIndex = ceil(currentTermValue)
  
  // The boundary in “raw” degrees (before normalizing) is:
  let nextBoundary = 15.0 * nextTermIndex - 7.5
  // Normalize the boundary to [0, 360).
  let nextBoundaryNormalized = (nextBoundary.truncatingRemainder(dividingBy: 360) + 360)
    .truncatingRemainder(dividingBy: 360)
  
  // Compute the angular difference from the current longitude to the boundary,
  // adjusting for wrap-around if necessary.
  var angleDifference = nextBoundaryNormalized - normalizedLong
  if angleDifference < 0 {
    angleDifference += 360
  }
  
  // The Sun moves on average about 360° per tropical year.
  // (Using the mean tropical year 365.2422 days, that’s roughly 0.9856° per day.)
  let dailyMotion = 360.0 / 365.2422
  let days = angleDifference / dailyMotion
  return days
}
