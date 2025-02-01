//
//  Sun.swift
//
//  Created by Xiangyu Sun on 26/1/23.
//

import Foundation

// MARK: - SunError

enum SunError: Error {
  case valueError(String)
}

// MARK: - Constants

/// Using 32 arc minutes as the Sun's apparent diameter
let SUN_APPARENT_RADIUS = Double(32.0) / (60.0 * 2.0)

// MARK: - Fix for Inaccuracy
/// By default, the code only handled `offset < -720.0`.
/// We add a symmetric check for `offset > 720.0` as well.
func adjustOffsetForDayBoundary(_ offset: inout Double) {
  let epsilon = 1e-7
  while offset < -720.0 - epsilon { offset += 1440.0 }
  while offset >  720.0 + epsilon { offset -= 1440.0 }
}

// MARK: - Helper: minutes_to_timedelta

func minutes_to_timedelta(minutes: Double) -> DateComponents {
  // Convert total minutes to day + second + nanoseconds
  let d = Int(minutes / 1440)
  var remainder = minutes - (Double(d) * 1440)
  remainder *= 60
  // Round remainder to nearest millisecond or microsecond first:
  let sRounded = remainder.rounded(.toNearestOrAwayFromZero)
  let s = Int(sRounded)
  let sfrac = sRounded - Double(s)
  let ns = Int((sfrac * 1_000_000_000).rounded()) // nanoseconds

  return DateComponents(day: d, second: s, nanosecond: ns)
}

// MARK: - Geometric/Orbital Calculations

/// Calculate the geometric mean longitude of the sun
func geom_mean_long_sun(juliancentury: Double) -> Double {
  let l0 = 280.46646 + juliancentury * (36000.76983 + 0.0003032 * juliancentury)
  var result = l0.truncatingRemainder(dividingBy: 360.0)
  if result < 0 { result += 360 }
  return result
}

/// Calculate the geometric mean anomaly of the sun
func geom_mean_anomaly_sun(juliancentury: Double) -> Double {
  357.52911 + juliancentury * (35999.05029 - 0.0001537 * juliancentury)
}

/// Calculate the eccentricity of Earth's orbit
func eccentric_location_earth_orbit(juliancentury: Double) -> Double {
  0.016708634
  - juliancentury * (0.000042037 + 0.0000001267 * juliancentury)
}

/// Calculate the equation of the center of the sun
func sun_eq_of_center(juliancentury: Double) -> Double {
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)
  let mrad = radians(m)
  let sinm = sin(mrad)
  let sin2m = sin(mrad * 2)
  let sin3m = sin(mrad * 3)

  return sinm * (1.914602 - juliancentury * (0.004817 + 0.000014 * juliancentury))
    + sin2m * (0.019993 - 0.000101 * juliancentury)
    + sin3m * 0.000289
}

/// Calculate the sun's true longitude
func sun_true_long(juliancentury: Double) -> Double {
  geom_mean_long_sun(juliancentury: juliancentury)
  + sun_eq_of_center(juliancentury: juliancentury)
}

/// Calculate the sun's true anomaly
func sun_true_anomoly(juliancentury: Double) -> Double {
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)
  let c = sun_eq_of_center(juliancentury: juliancentury)
  return m + c
}

func sun_rad_vector(juliancentury: Double) -> Double {
  let v = sun_true_anomoly(juliancentury: juliancentury)
  let e = eccentric_location_earth_orbit(juliancentury: juliancentury)
  return (1.000001018 * (1 - e * e)) / (1 + e * cos(radians(v)))
}

func sun_apparent_long(juliancentury: Double) -> Double {
  let tLong = sun_true_long(juliancentury: juliancentury)
  let omega = 125.04 - 1934.136 * juliancentury
  return tLong - 0.00569 - 0.00478 * sin(radians(omega))
}

func mean_obliquity_of_ecliptic(juliancentury: Double) -> Double {
  let seconds = 21.448
    - juliancentury * (46.815 + juliancentury * (0.00059 - juliancentury * 0.001813))
  return 23.0 + (26.0 + seconds / 60.0) / 60.0
}

func obliquity_correction(juliancentury: Double) -> Double {
  let e0 = mean_obliquity_of_ecliptic(juliancentury: juliancentury)
  let omega = 125.04 - 1934.136 * juliancentury
  return e0 + 0.00256 * cos(radians(omega))
}

/// Calculate the sun's right ascension
func sun_rt_ascension(juliancentury: Double) -> Double {
  let oc = obliquity_correction(juliancentury: juliancentury)
  let al = sun_apparent_long(juliancentury: juliancentury)
  return degrees(atan2(
    cos(radians(oc)) * sin(radians(al)),
    cos(radians(al))
  ))
}

/// Calculate the sun's declination
func sun_declination(juliancentury: Double) -> Double {
  let e = obliquity_correction(juliancentury: juliancentury)
  let lambd = sun_apparent_long(juliancentury: juliancentury)
  let sint = sin(radians(e)) * sin(radians(lambd))
  return degrees(asin(sint))
}

func var_y(juliancentury: Double) -> Double {
  let epsilon = obliquity_correction(juliancentury: juliancentury)
  let y = tan(radians(epsilon) / 2.0)
  return y * y
}

/// Calculate the "equation of time"
func eq_of_time(juliancentury: Double) -> Double {
  let l0 = geom_mean_long_sun(juliancentury: juliancentury)
  let e = eccentric_location_earth_orbit(juliancentury: juliancentury)
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)
  let y = var_y(juliancentury: juliancentury)

  let sin2l0 = sin(2.0 * radians(l0))
  let sinm   = sin(radians(m))
  let cos2l0 = cos(2.0 * radians(l0))
  let sin4l0 = sin(4.0 * radians(l0))
  let sin2m  = sin(2.0 * radians(m))

  let Etime = y * sin2l0
    - 2.0 * e * sinm
    + 4.0 * e * y * sinm * cos2l0
    - 0.5 * y * y * sin4l0
    - 1.25 * e * e * sin2m

  return degrees(Etime) * 4.0
}

// MARK: - Hour Angle

/// Calculate the hour angle of the sun
/// See https://en.wikipedia.org/wiki/Hour_angle#Solar_hour_angle
func hour_angle(
  latitude: Double,
  declination: Double,
  zenith: Double,
  direction: SunDirection
) -> Double {
  let latRad = radians(latitude)
  let decRad = radians(declination)
  let zenRad = radians(zenith)

  // Formula: cos(H) = [cos(Z) - sin(φ) sin(δ)] / [cos(φ) cos(δ)]
  let cosH = (cos(zenRad) - sin(latRad) * sin(decRad))
               / (cos(latRad) * cos(decRad))

  // If value is out of [-1,1], it implies no sunrise/sunset
  var h = acos(cosH)
  if direction == .setting {
    h = -h
  }
  return h
}

// MARK: - Elevation Adjustments

/// Returns the dip angle (in degrees) from the horizontal to the horizon for an
/// observer at `elevation` meters above sea level, ignoring atmospheric refraction.
///
/// - Parameter elevation: Elevation above (or below) sea level in meters.
/// - Returns: Dip angle in degrees; 0 if `elevation <= 0`.
func adjust_to_horizon(elevation: Double) -> Double {
  // Return 0 if elevation is at or below sea level
    guard elevation > 0 else { return 0.0 }
    
    // Use mean Earth radius in meters (roughly 6371 km).
    // You can tweak to 6378137 (equatorial) or 6356752 (polar) if desired.
    let earthRadius = 6_371_000.0
    
    // Observed distance from Earth's center
    let observerDistance = earthRadius + elevation
    
    // Dip angle = acos(R / (R + h)) in radians; convert to degrees
    let dipRadians = acos(earthRadius / observerDistance)
    return dipRadians * (180.0 / .pi)
}


/// Calculate the degrees to adjust for an obscuring feature
func adjust_to_obscuring_feature(elevation: (Double, Double)) -> Double {
  // If there's no vertical offset, return 0
  guard elevation.0 != 0.0 else { return 0.0 }

  let sign = elevation.0 < 0.0 ? -1.0 : 1.0
  let numerator = fabs(elevation.0)
  let denominator = sqrt(pow(elevation.0, 2) + pow(elevation.1, 2))
  return sign * degrees(acos(numerator / denominator))
}

// MARK: - Transit Calculation (Core of Sunrise/Sunset)
/// Calculate the time in UTC when the sun transits a specific zenith.
func time_of_transit(
  observer: Observer,
  date: DateComponents,
  zenith: Double,
  direction: SunDirection,
  with_refraction: Bool = true
) -> DateComponents {
  // Clamp latitude to ±89.8 to avoid invalid domain for trigonometric functions
  let latitude = max(min(observer.latitude, 89.8), -89.8)

  // Elevation-based adjustments
  var horizonAdjustment = 0.0
  switch observer.elevation {
  case .double(let elev) where elev > 0:
    horizonAdjustment = adjust_to_horizon(elevation: elev)
  case .tuple(let elev):
    horizonAdjustment = adjust_to_obscuring_feature(elevation: elev)
  default:
    break
  }

  // Refraction adjustment: adjust the zenith angle to account for both horizon dip and refraction.
  let adjustedZenith: Double = with_refraction
    ? zenith + horizonAdjustment + refractionAtZenith(zenith + horizonAdjustment)
    : zenith + horizonAdjustment

  // Convert date to Julian day
  let jd = julianDay(at: date)

  // Iterative refinement of transit time:
  // Start with an initial guess of 720 minutes (12:00 UTC) and refine until convergence.
  var timeUTC = 720.0           // initial guess (in minutes)
  let tolerance = 0.001         // convergence tolerance (in minutes)
  var iteration = 0

  while iteration < 10 {
    // Compute Julian century for the current guess
    let jc = julianDayToCentury(julianDay: jd + timeUTC / 1440.0)
    // Calculate the sun's declination at the current time
    let dec = sun_declination(juliancentury: jc)
    // Determine the hour angle for the current state
    let ha = hour_angle(
      latitude: latitude,
      declination: dec,
      zenith: adjustedZenith,
      direction: direction
    )
    // Calculate the angular difference to transit
    let deltaAngle = -observer.longitude - degrees(ha)
    // Get the equation of time (in minutes) for the current time
    let eqtime = eq_of_time(juliancentury: jc)
    // Compute the offset in minutes
    var offset = deltaAngle * 4.0 - eqtime
    adjustOffsetForDayBoundary(&offset)

    let newTimeUTC = 720.0 + offset

    // If the change is within our tolerance, accept the value.
    if abs(newTimeUTC - timeUTC) < tolerance {
      timeUTC = newTimeUTC
      break
    }
    timeUTC = newTimeUTC
    iteration += 1
  }

  let td = minutes_to_timedelta(minutes: timeUTC)

  return DateComponents(
    timeZone: .utc,
    year: date.year,
    month: date.month,
    day: (date.day ?? 0) + (td.day ?? 0),
    second: td.second,
    nanosecond: td.nanosecond
  )
}

// MARK: - Utility to get solar angles at a specific time

func zenith_and_azimuth(
  observer: Observer,
  dateandtime: DateComponents,
  with_refraction: Bool = true
) -> (Double, Double) {
  let latitude = max(min(observer.latitude, 89.8), -89.8)
  let longitude = observer.longitude

  // Derive local time offset from the date’s timeZone
  let zone: Double
  let utcDatetime: DateComponents
  if let tz = dateandtime.timeZone {
    zone = -tz.secondsFromGMT() / 3600.0
    utcDatetime = dateandtime.astimezone(.utc)
  } else {
    zone = 0.0
    utcDatetime = dateandtime
  }

  let jd = julianDay(at: utcDatetime)
  let t = julianDayToCentury(julianDay: jd)
  let declination = sun_declination(juliancentury: t)
  let eqtime = eq_of_time(juliancentury: t)

  // solarTimeFix = eqtime + 4 * longitude + 60 * zone
  let solarTimeFix = eqtime + (4.0 * longitude) + (60.0 * zone)

  let totalMinutes = Double(
    (dateandtime.hour ?? 0) * 60 + (dateandtime.minute ?? 0)
  ) + (Double(dateandtime.second ?? 0) / 60.0)

  // True Solar Time in minutes
  var trueSolarTime = totalMinutes + solarTimeFix
  while trueSolarTime > 1440 { trueSolarTime -= 1440 }
  while trueSolarTime < 0 { trueSolarTime += 1440 }

  var hourangle = trueSolarTime / 4.0 - 180.0
  if hourangle < -180.0 { hourangle += 360.0 }

  let ch = cos(radians(hourangle))
  let cl = cos(radians(latitude))
  let sl = sin(radians(latitude))
  let sd = sin(radians(declination))
  let cd = cos(radians(declination))

  var csz = cl * cd * ch + sl * sd
  if csz > 1.0 { csz = 1.0 }
  else if csz < -1.0 { csz = -1.0 }

  var zen = degrees(acos(csz))
  var az: Double

  let azDenom = cl * sin(radians(zen))
  if abs(azDenom) > 0.001 {
    var azRad = (sl * cos(radians(zen)) - sd) / azDenom
    if abs(azRad) > 1.0 { azRad = azRad < 0 ? -1.0 : 1.0 }
    az = 180.0 - degrees(acos(azRad))
    if hourangle > 0.0 { az = -az }
  } else {
    az = (latitude > 0.0) ? 180.0 : 0.0
  }
  if az < 0.0 { az += 360.0 }

  if with_refraction {
    // Adjust zenith for refraction
    zen -= refractionAtZenith(zen)
  }

  return (zen, az)
}

// MARK: - Public Functions

func zenith(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true
) -> Double {
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction).0
}

func azimuth(
  observer: Observer,
  dateandtime: DateComponents = Date().components()
) -> Double {
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime).1
}

func elevation(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true
) -> Double {
  90.0 - zenith(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction)
}

// MARK: - Core Sunrise/Sunset Routines

func dawn(
  observer: Observer,
  date: DateComponents,
  depression: Depression = .civil,
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  let dep = depression.rawValue.double
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + dep,
    direction: .rising
  ).astimezone(tzinfo)

  // If the transit date differs, try next/previous day
  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date {
      newDate.setValue((date.day ?? 0) + 1, for: .day)
    } else {
      newDate.setValue((date.day ?? 0) - 1, for: .day)
    }

    tot = time_of_transit(
      observer: observer,
      date: newDate,
      zenith: 90.0 + dep,
      direction: .rising
    ).astimezone(tzinfo)

    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a dawn time on the date specified")
    }
  }
  return tot
}

func sunrise(
  observer: Observer,
  date: DateComponents,
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + SUN_APPARENT_RADIUS,
    direction: .rising
  ).astimezone(tzinfo)

  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else         { newDate.setValue((date.day ?? 0) - 1, for: .day) }

    tot = time_of_transit(
      observer: observer,
      date: newDate,
      zenith: 90.0 + SUN_APPARENT_RADIUS,
      direction: .rising
    ).astimezone(tzinfo)

    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a sunrise time on the date specified")
    }
  }
  return tot
}

func sunset(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + SUN_APPARENT_RADIUS,
    direction: .setting
  ).astimezone(tzinfo)

  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else         { newDate.setValue((date.day ?? 0) - 1, for: .day) }

    tot = time_of_transit(
      observer: observer,
      date: newDate,
      zenith: 90.0 + SUN_APPARENT_RADIUS,
      direction: .setting
    ).astimezone(tzinfo)

    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a sunset time on the date specified")
    }
  }
  return tot
}

func dusk(
  observer: Observer,
  date: DateComponents = Date().components(),
  depression: Depression = .civil,
  tzinfo: TimeZone = .utc
) throws -> DateComponents {
  let dep = depression.rawValue.double
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + dep,
    direction: .setting
  ).astimezone(tzinfo)

  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else         { newDate.setValue((date.day ?? 0) - 1, for: .day) }

    tot = time_of_transit(
      observer: observer,
      date: newDate,
      zenith: 90.0 + dep,
      direction: .setting
    ).astimezone(tzinfo)

    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a dusk time on the date specified")
    }
  }
  return tot
}

// MARK: - Noon & Midnight

func noon(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) -> DateComponents {
  let jc = julianDayToCentury(julianDay: julianDay(at: date))
  let eqtime = eq_of_time(juliancentury: jc)
  let timeUTC = (720.0 - (4 * observer.longitude) - eqtime) / 60.0

  var hour = Int(timeUTC)
  var minute = Int((timeUTC - hour.double) * 60)
  var second = Int((((timeUTC - hour.double) * 60) - minute.double) * 60)

  if second > 59 {
    second -= 60
    minute += 1
  } else if second < 0 {
    second += 60
    minute -= 1
  }

  if minute > 59 {
    minute -= 60
    hour += 1
  } else if minute < 0 {
    minute += 60
    hour -= 1
  }

  var localDate = date
  if hour > 23 {
    hour -= 24
    localDate.day = (date.day ?? 0) + 1
  } else if hour < 0 {
    hour += 24
    localDate.day = (date.day ?? 0) - 1
  }

  let result = DateComponents(
    timeZone: .utc,
    year: localDate.year,
    month: localDate.month,
    day: localDate.day,
    hour: hour,
    minute: minute,
    second: second
  )
  return result.astimezone(tzinfo)
}

func midnight(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) -> DateComponents {
  var copyDate = date
  copyDate.setValue(12, for: .hour)
  copyDate.setValue(0, for: .minute)
  copyDate.setValue(0, for: .second)
  copyDate.setValue(0, for: .nanosecond)

  let jd = julianDay(at: copyDate)
  let newt = julianDayToCentury(julianDay: jd + 0.5 + -observer.longitude / 360.0)
  let eqtime = eq_of_time(juliancentury: newt)

  var timeUTC = (-observer.longitude * 4.0) - eqtime
  timeUTC /= 60.0

  var hour = Int(timeUTC)
  var minute = Int((timeUTC - hour.double) * 60)
  var second = Int((((timeUTC - hour.double) * 60) - minute.double) * 60)

  if second > 59 {
    second -= 60
    minute += 1
  } else if second < 0 {
    second += 60
    minute -= 1
  }

  if minute > 59 {
    minute -= 60
    hour += 1
  } else if minute < 0 {
    minute += 60
    hour -= 1
  }

  if hour < 0 {
    hour += 24
    copyDate.day = (copyDate.day ?? 0) - 1
  }

  return DateComponents(
    timeZone: .utc,
    year: copyDate.year,
    month: copyDate.month,
    day: copyDate.day,
    hour: hour,
    minute: minute,
    second: second
  ).astimezone(tzinfo)
}

// MARK: - Additional Times (Night, Twilight, Golden Hour, Blue Hour, etc.)

func time_at_elevation(
  observer: Observer,
  elevation: Double,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc,
  with_refraction: Bool = true
) -> DateComponents {
  // If elevation > 90 => treat as "setting" from the opposite side
  var adjustedElevation = elevation
  var adjustedDirection = direction

  if elevation > 90.0 {
    adjustedElevation = 180.0 - elevation
    adjustedDirection = .setting
  }

  let zenith = 90 - adjustedElevation
  return time_of_transit(
    observer: observer,
    date: date,
    zenith: zenith,
    direction: adjustedDirection,
    with_refraction: with_refraction
  ).astimezone(tzinfo)
}

func daylight(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  let sr = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
  let ss = try sunset(observer: observer, date: date, tzinfo: tzinfo)
  return (sr, ss)
}

func night(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  // Astronomical dusk => 18 degrees below the horizon
  let start = try dusk(observer: observer, date: date, depression: 6, tzinfo: tzinfo)
  var tomorrow = date
  tomorrow.setValue((date.day ?? 0) + 1, for: .day)
  let end = try dawn(observer: observer, date: tomorrow, depression: 6, tzinfo: tzinfo)
  return (start, end)
}

func twilight(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  // Twilight is between -6 (90+6) and horizon
  let start = time_of_transit(
    observer: observer,
    date: date,
    zenith: 96, // 90 + 6
    direction: direction
  ).astimezone(tzinfo)

  let end: DateComponents
  if direction == .rising {
    end = try sunrise(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
    return (start, end)
  } else {
    end = try sunset(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
    return (end, start)
  }
}

func golden_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  // Golden hour: between -4° and +6° according to PhotoPills
  let start = time_of_transit(
    observer: observer,
    date: date,
    zenith: 94, // 90 + 4
    direction: direction
  ).astimezone(tzinfo)

  let end = time_of_transit(
    observer: observer,
    date: date,
    zenith: 84, // 90 - 6
    direction: direction
  ).astimezone(tzinfo)

  if direction == .rising {
    return (start, end)
  } else {
    return (end, start)
  }
}

func blue_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  // Blue hour: between -6° and -4° below the horizon
  let start = time_of_transit(
    observer: observer,
    date: date,
    zenith: 96, // 90 + 6
    direction: direction
  ).astimezone(tzinfo)

  let end = time_of_transit(
    observer: observer,
    date: date,
    zenith: 94, // 90 + 4
    direction: direction
  ).astimezone(tzinfo)

  if direction == .rising {
    return (start, end)
  } else {
    return (end, start)
  }
}

// MARK: - Rahukaalam

func rahukaalam(
  observer: Observer,
  date: DateComponents = Date().components(),
  daytime: Bool = true,
  tzinfo: TimeZone = .utc
) throws -> (DateComponents, DateComponents) {
  // Grab sunrise & sunset, or sunset & next sunrise
  let start: DateComponents
  let end: DateComponents

  if daytime {
    start = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
    end   = try sunset(observer: observer, date: date, tzinfo: tzinfo)
  } else {
    start = try sunset(observer: observer, date: date, tzinfo: tzinfo)
    var nextDay = date
    nextDay.setValue((date.day ?? 0) + 1, for: .day)
    end = try sunrise(observer: observer, date: nextDay, tzinfo: tzinfo)
  }

  // Convert to Date, then calculate one-octant (1/8) of the day
  var startDate = Calendar(identifier: .gregorian).date(from: start)!
  let endDate   = Calendar(identifier: .gregorian).date(from: end)!

  let diff = Calendar(identifier: .gregorian).dateComponents(
    [.second], from: startDate, to: endDate
  )
  guard let totalSeconds = diff.second else {
    throw SunError.valueError("Error computing Rahukaalam intervals")
  }

  let octantDuration = totalSeconds / 8
  // Mo,Sa,Fr,We,Th,Tu,Su => weekday-based shift
  let octantIndex = [1, 6, 4, 5, 3, 2, 7]

  let originalDate = Calendar(identifier: .gregorian).date(from: date)!
  let weekday = Calendar(identifier: .iso8601).dateComponents([.weekday], from: originalDate).weekday!
  let octant = octantIndex[weekday % 7]  // ensure index is valid

  // Move start by `octant * octantDuration`
  startDate = Calendar(identifier: .gregorian).date(byAdding: .second, value: octant * octantDuration, to: startDate)!
  let rahuEndDate = Calendar(identifier: .gregorian).date(byAdding: .second, value: octantDuration, to: startDate)!

  let newStart = Calendar(identifier: .gregorian).dateComponents(in: tzinfo, from: startDate)
  let newEnd   = Calendar(identifier: .gregorian).dateComponents(in: tzinfo, from: rahuEndDate)

  return (newStart, newEnd)
}

// MARK: - Consolidated "sun" function

func sun(
  observer: Observer,
  date: DateComponents = Date().components(),
  dawn_dusk_depression: Depression = .civil,
  daytime _: Bool = true,
  tzinfo: TimeZone = .utc
) throws -> [String: DateComponents] {
  [
    "dawn":    try dawn(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo),
    "sunrise": try sunrise(observer: observer, date: date, tzinfo: tzinfo),
    "noon":    noon(observer: observer, date: date, tzinfo: tzinfo),
    "sunset":  try sunset(observer: observer, date: date, tzinfo: tzinfo),
    "dusk":    try dusk(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo)
  ]
}
