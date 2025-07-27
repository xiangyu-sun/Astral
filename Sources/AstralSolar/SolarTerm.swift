import Foundation
import AstralCore


/// Calculates the current solar term as a fractional index (0–24).
///
/// - Parameter date: The reference date. Defaults to `Date()`.
/// - Returns: A value between 0 and 24 where each integer boundary marks the
///   start of the next solar term.
public func currentSolarTerm(for date: Date = Date()) -> Double {
  // Convert the date to UTC components for consistent astronomical calculations.
  let utcTimeZone = TimeZone.utc
  let components = date.components(timezone: utcTimeZone)

  // Compute Julian Day and Julian Century.
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)

  // Calculate the Sun's apparent longitude (degrees).
  let apparentLong = sun_apparent_long(juliancentury: jc)

  // Normalize to [0, 360) degrees.
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)

  // Each term spans 15°. Adding 7.5° rounds to the nearest term boundary.
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

/// Computes the exact date of the next solar term using Newton iteration.
///
/// - Parameters:
///   - date: The starting date. Defaults to `Date()`.
///   - iterations: Number of Newton iterations to perform. Defaults to `5`.
/// - Returns: The `Date` at which the next solar term begins.
public func preciseNextSolarTermDate(from date: Date = Date(), iterations: Int = 5) -> Date {
  let utcTimeZone = TimeZone.utc
  let components = date.components(timezone: utcTimeZone)
  let jd = julianDay(at: components)
  let jc = julianDayToCentury(julianDay: jd)
  let apparentLong = sun_apparent_long(juliancentury: jc)
  let normalizedLong = (apparentLong.truncatingRemainder(dividingBy: 360) + 360)
                        .truncatingRemainder(dividingBy: 360)
  let nextTermIndex = floor(normalizedLong / 15.0) + 1.0
  let targetLongitude = (nextTermIndex * 15.0).truncatingRemainder(dividingBy: 360)

  
  // Average daily solar motion (degrees per day)
  let dailyMotion = 360.0 / 365.242189
  
  // Initial estimate: minimal positive angular difference to target boundary divided by motion
  let degreesDiff = (targetLongitude - normalizedLong + 360).truncatingRemainder(dividingBy: 360)
  let approxDays = degreesDiff / dailyMotion
  var t = date.addingTimeInterval(approxDays * 86400)

  // 牛顿迭代求解
  for _ in 0..<iterations {
    let compT = t.components(timezone: utcTimeZone)
    let jdT = julianDay(at: compT)
    let jcT = julianDayToCentury(julianDay: jdT)
    let lambdaT = sun_apparent_long(juliancentury: jcT)
    let normLambda = (lambdaT.truncatingRemainder(dividingBy: 360) + 360)
                      .truncatingRemainder(dividingBy: 360)

    // Compute minimal signed angular difference (±180°) to avoid huge jumps.
    var delta = (normLambda - targetLongitude).remainder(dividingBy: 360)
    if delta > 180 { delta -= 360 }
    if delta < -180 { delta += 360 }
    let dt = -delta / dailyMotion * 86400
    t = t.addingTimeInterval(dt)
  }

  return t
}

/// Returns the month number (1–12) corresponding to the current solar term.
/// Each solar term spans half a month, so two terms map to one month.
/// - Parameter date: The reference date. Defaults to now.
/// - Returns: The month (1 = January, …, 12 = December).
public func monthOfCurrentSolarTerm(for date: Date = Date()) -> Int {
    // Determine the solar term index (0–23).
    let termValue = currentSolarTerm(for: date)
    let termIndex = Int(floor(termValue)) % 24

    // Map each solar term index to its Gregorian month.
    let mapping: [Int] = [
        3, 4, 4, 5, 5, 6, 6, 7,
        7, 8, 8, 9, 9, 10, 10, 11,
        11, 12, 12, 1, 1, 2, 2, 3
    ]

    return mapping[termIndex]
}
