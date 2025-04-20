import Foundation


/// 根据当前日期（或指定日期）计算太阳的视黄经，并推算对应的二十四节气。
public func currentSolarTerm(for date: Date = Date()) -> Double {
  // 将当前日期转换为 UTC 下的 DateComponents（确保天文计算的一致性）
  let utcTimeZone = TimeZone.utc
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
public func daysUntilNextSolarTerm(from date: Date = Date()) -> Double {
  // Ensure we use UTC to keep astronomical calculations consistent.
  let utcTimeZone = TimeZone.utc
  let components = date.components(timezone: utcTimeZone)
  
  // Compute Julian Day and Julian Century.
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)
  
  // Compute the Sun’s apparent ecliptic longitude (in degrees).
  let apparentLong = sun_apparent_long(juliancentury: jc)
  
  // Normalize the longitude to [0, 360).
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360)
                        .truncatingRemainder(dividingBy: 360)
  
  // Compute an offset value.
  let offset = normalizedLong + 7.5
  let epsilon = 1e-7
  
  // Compute the remainder when offset is divided by 15.
  let remainder = offset.truncatingRemainder(dividingBy: 15.0)
  
  // Compute the current term value.
  let currentTermValue = offset / 15.0
  
  // Determine the next term index.
  // If the remainder is nearly 0, we’re exactly at a boundary.
  let nextTermIndex: Double
  if abs(remainder) < epsilon {
    nextTermIndex = currentTermValue + 1.0
  } else {
    nextTermIndex = ceil(currentTermValue)
  }
  
  // Compute the next boundary in degrees.
  let nextBoundary = 15.0 * nextTermIndex - 7.5
  // Normalize the boundary to [0, 360).
  let nextBoundaryNormalized = (nextBoundary.truncatingRemainder(dividingBy: 360) + 360)
                                .truncatingRemainder(dividingBy: 360)
  
  // Calculate the angular difference from the current longitude to the boundary.
  var angleDifference = nextBoundaryNormalized - normalizedLong
  if angleDifference < 0 {
    angleDifference += 360
  }
  
  // Convert the angular difference to days using the average daily solar motion (~0.9856°/day).
  let dailyMotion = 360.0 / 365.242189
  return angleDifference / dailyMotion
}

/// 精确计算下一个节气的具体时刻，使用牛顿迭代法收敛到目标黄经边界。
public func preciseNextSolarTermDate(from date: Date = Date(), iterations: Int = 5, keepExtra7_5: Bool = false) -> Date {
  let utcTimeZone = TimeZone.utc
  let components = date.components(timezone: utcTimeZone)
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)
  let apparentLong = sun_apparent_long(juliancentury: jc)
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360)
                        .truncatingRemainder(dividingBy: 360)
  let offset = normalizedLong + 7.5
  let currentTerm = offset / 15.0
  let nextTermIndex = floor(currentTerm) + 1.0
  let targetLongitude = 15.0 * nextTermIndex - 7.5

  // 初步估计时刻
  let approxDays = daysUntilNextSolarTerm(from: date)
  var t = date.addingTimeInterval(approxDays * 86400)

  // 更精确的日运动率
  let dailyMotion = 360.0 / 365.242189

  // 牛顿迭代求解
  for _ in 0..<iterations {
    let compT = t.components(timezone: utcTimeZone)
    let jdT = julianDay(at: compT)
    let jcT = julianDayToCentury(julianDay: jdT)
    let lambdaT = sun_apparent_long(juliancentury: jcT)
    let normLambda = (lambdaT.truncatingRemainder(dividingBy: 360) + 360)
                      .truncatingRemainder(dividingBy: 360)

    var delta = (normLambda - targetLongitude).truncatingRemainder(dividingBy: 360)
    if delta < 0 { delta += 360 }
    let dt = -delta / dailyMotion * 86400
    t = t.addingTimeInterval(dt)
  }

  return t
}
