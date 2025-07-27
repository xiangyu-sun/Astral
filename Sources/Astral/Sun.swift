//
//  Sun.swift
//
//  Created by Xiangyu Sun on 26/1/23.
//  Revised on [Date] for improved code clarity and accuracy.
//

import Foundation

// MARK: - SunError

/// Errors related to Sun (astral) calculations.
enum SunError: Error {
  case valueError(String)
}

// MARK: - Constants

/// Using 32 arc minutes as the Sun's apparent diameter.
/// **Note:** Since the apparent radius is required (i.e. half the diameter),
/// we define SUN_APPARENT_RADIUS as 32 arc minutes divided by 2, then converted to degrees.
/// (32 arc minutes = 32/60 degrees; divided by 2 gives 16/60 ≈ 0.26667°.)
let SUN_APPARENT_RADIUS = Double(32.0) / (60.0 * 2.0)

// MARK: - Helper Functions

/// Adjusts an offset (in minutes) so that it lies within ±720 minutes.
/// This is useful to “wrap” minute offsets within half a day (1440 minutes).
func adjustOffsetForDayBoundary(_ offset: inout Double) {
  let epsilon = 1e-7
  while offset < -720.0 - epsilon { offset += 1440.0 }
  while offset > 720.0 + epsilon { offset -= 1440.0 }
}

/// Converts a minutes value into a DateComponents structure containing day, second, and nanosecond components.
func minutes_to_timedelta(minutes: Double) -> DateComponents {
  let d = Int(minutes / 1440)
  var remainder = minutes - (Double(d) * 1440)
  remainder *= 60 // convert minutes to seconds
  let sRounded = remainder.rounded(.toNearestOrAwayFromZero)
  let s = Int(sRounded)
  let sfrac = sRounded - Double(s)
  let ns = Int((sfrac * 1_000_000_000).rounded())
  return DateComponents(day: d, second: s, nanosecond: ns)
}

// MARK: - Geometric/Orbital Calculations

/// Returns the geometric mean longitude of the Sun (in degrees) for a given Julian century.
func geom_mean_long_sun(juliancentury: Double) -> Double {
  let l0 = 280.46646 + juliancentury * (36000.76983 + 0.0003032 * juliancentury)
  var result = l0.truncatingRemainder(dividingBy: 360.0)
  if result < 0 { result += 360 }
  return result
}

/// Returns the geometric mean anomaly of the Sun (in degrees) for a given Julian century.
func geom_mean_anomaly_sun(juliancentury: Double) -> Double {
  357.52911 + juliancentury * (35999.05029 - 0.0001537 * juliancentury)
}

/// Returns the eccentricity of Earth's orbit.
func eccentric_location_earth_orbit(juliancentury: Double) -> Double {
  0.016708634 - juliancentury * (0.000042037 + 0.0000001267 * juliancentury)
}

/// Returns the equation of the center of the Sun (in degrees) for a given Julian century.
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

/// Returns the Sun's true longitude (in degrees).
func sun_true_long(juliancentury: Double) -> Double {
  geom_mean_long_sun(juliancentury: juliancentury)
    + sun_eq_of_center(juliancentury: juliancentury)
}

/// Returns the Sun's true anomaly (in degrees).
func sun_true_anomoly(juliancentury: Double) -> Double {
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)
  let c = sun_eq_of_center(juliancentury: juliancentury)
  return m + c
}

/// Returns the Sun's radial vector (in astronomical units).
func sun_rad_vector(juliancentury: Double) -> Double {
  let v = sun_true_anomoly(juliancentury: juliancentury)
  let e = eccentric_location_earth_orbit(juliancentury: juliancentury)
  return (1.000001018 * (1 - e * e)) / (1 + e * cos(radians(v)))
}

/// Returns the Sun's apparent longitude (in degrees) after correcting for nutation and aberration.
func sun_apparent_long(juliancentury: Double) -> Double {
  let tLong = sun_true_long(juliancentury: juliancentury)
  let omega = 125.04 - 1934.136 * juliancentury
  return tLong - 0.00569 - 0.00478 * sin(radians(omega))
}

/// Returns the mean obliquity of the ecliptic (in degrees).
func mean_obliquity_of_ecliptic(juliancentury: Double) -> Double {
  let seconds = 21.448 - juliancentury * (46.815 + juliancentury * (0.00059 - juliancentury * 0.001813))
  return 23.0 + (26.0 + seconds / 60.0) / 60.0
}

/// Returns the corrected obliquity of the ecliptic (in degrees).
func obliquity_correction(juliancentury: Double) -> Double {
  let e0 = mean_obliquity_of_ecliptic(juliancentury: juliancentury)
  let omega = 125.04 - 1934.136 * juliancentury
  return e0 + 0.00256 * cos(radians(omega))
}

/// Returns the Sun's right ascension (in degrees).
func sun_rt_ascension(juliancentury: Double) -> Double {
  let oc = obliquity_correction(juliancentury: juliancentury)
  let al = sun_apparent_long(juliancentury: juliancentury)
  let ra = atan2(cos(radians(oc)) * sin(radians(al)), cos(radians(al)))
  var raDeg = degrees(ra)
  if raDeg < 0 { raDeg += 360 }
  return raDeg
}

/// Returns the Sun's declination (in degrees).
func sun_declination(juliancentury: Double) -> Double {
  let e = obliquity_correction(juliancentury: juliancentury)
  let lambd = sun_apparent_long(juliancentury: juliancentury)
  let sint = sin(radians(e)) * sin(radians(lambd))
  return degrees(asin(sint))
}

/// Returns an intermediate variable used in the equation of time.
func var_y(juliancentury: Double) -> Double {
  let epsilon = obliquity_correction(juliancentury: juliancentury)
  let y = tan(radians(epsilon) / 2.0)
  return y * y
}

/// Returns the equation of time (in minutes) for the given Julian century.
func eq_of_time(juliancentury: Double) -> Double {
  let l0 = geom_mean_long_sun(juliancentury: juliancentury)
  let e = eccentric_location_earth_orbit(juliancentury: juliancentury)
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)
  let y = var_y(juliancentury: juliancentury)

  let sin2l0 = sin(2.0 * radians(l0))
  let sinm = sin(radians(m))
  let cos2l0 = cos(2.0 * radians(l0))
  let sin4l0 = sin(4.0 * radians(l0))
  let sin2m = sin(2.0 * radians(m))

  let Etime = y * sin2l0 - 2.0 * e * sinm + 4.0 * e * y * sinm * cos2l0
    - 0.5 * y * y * sin4l0 - 1.25 * e * e * sin2m

  return degrees(Etime) * 4.0
}

// MARK: - Hour Angle Calculation

/// Calculates the hour angle (in radians) of the Sun for the given zenith.
/// The formula used is:
///   cos(H) = [cos(zenith) - sin(latitude)*sin(declination)] / [cos(latitude)*cos(declination)]
/// - Parameters:
///   - latitude: The observer's latitude in degrees.
///   - declination: The Sun's declination in degrees.
///   - zenith: The zenith angle (in degrees).
///   - direction: The desired direction (.rising or .setting).
/// - Returns: The hour angle in radians. For .setting, the angle is negated.
func hour_angle(
  latitude: Double,
  declination: Double,
  zenith: Double,
  direction: SunDirection)
  -> Double
{
  let latRad = radians(latitude)
  let decRad = radians(declination)
  let zenRad = radians(zenith)
  var cosH = (cos(zenRad) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad))
  // Clamp the cosine value to [-1, 1] to avoid domain errors.
  cosH = min(max(cosH, -1.0), 1.0)
  var h = acos(cosH)
  if direction == .setting { h = -h }
  return h
}

// MARK: - Elevation Adjustments

/// Returns the dip angle (in degrees) from the horizontal to the true horizon
/// for an observer at the specified elevation (in meters) above sea level.
/// Uses the formula: dip = acos(earthRadius / (earthRadius + elevation))
/// - Parameter elevation: Elevation above sea level (meters).
/// - Returns: The dip angle in degrees; returns 0 if elevation <= 0.
func adjust_to_horizon(elevation: Double) -> Double {
  guard elevation > 0 else { return 0.0 }
  let earthRadius = 6_371_000.0 // Mean Earth radius in meters.
  let observerDistance = earthRadius + elevation
  let dipRadians = acos(earthRadius / observerDistance)
  return dipRadians * (180.0 / .pi)
}

/// Returns the angular adjustment (in degrees) due to an obscuring feature,
/// given as a tuple (vertical offset, horizontal offset).
func adjust_to_obscuring_feature(elevation: (Double, Double)) -> Double {
  guard elevation.0 != 0.0 else { return 0.0 }
  let sign = elevation.0 < 0.0 ? -1.0 : 1.0
  let numerator = fabs(elevation.0)
  let denominator = sqrt(pow(elevation.0, 2) + pow(elevation.1, 2))
  return sign * degrees(acos(numerator / denominator))
}

// MARK: - Transit Calculation (Core of Sunrise/Sunset)

/// Calculates the time (in UTC, as minutes after midnight) when the Sun transits a specific zenith.
/// The function iteratively refines an initial guess (12:00 UTC) until convergence.
/// - Parameters:
///   - observer: The Observer containing latitude, longitude, and elevation info.
///   - date: The date (in UTC) as DateComponents.
///   - zenith: The zenith angle (in degrees) at which the transit occurs.
///   - direction: The transit direction (.rising or .setting).
///   - with_refraction: If true, includes atmospheric refraction in the adjusted zenith.
/// - Returns: A DateComponents object representing the transit time in UTC.
func time_of_transit(
  observer: Observer,
  date: DateComponents,
  zenith: Double,
  direction: SunDirection,
  with_refraction: Bool = true)
  -> DateComponents
{
  // Clamp latitude to avoid domain errors.
  let latitude = max(min(observer.latitude, 89.8), -89.8)

  // Elevation-based adjustment: either from elevation in meters or an obscuring feature.
  var horizonAdjustment = 0.0
  switch observer.elevation {
  case .double(let elev) where elev > 0:
    horizonAdjustment = adjust_to_horizon(elevation: elev)
  case .tuple(let elev):
    horizonAdjustment = adjust_to_obscuring_feature(elevation: elev)
  default:
    break
  }

  // Apply refraction correction if needed.
  let adjustedZenith: Double = with_refraction
    ? zenith + horizonAdjustment + refractionAtZenith(zenith + horizonAdjustment)
    : zenith + horizonAdjustment

  // Convert the date to Julian Day.
  let jd = julianDay(at: date)

  // Iteratively refine the transit time.
  var timeUTC = 720.0 // initial guess in minutes (12:00 UTC)
  let tolerance = 0.001
  var iteration = 0
  while iteration < 10 {
    let jc = julianDayToCentury(julianDay: jd + timeUTC / 1440.0)
    let dec = sun_declination(juliancentury: jc)
    let ha = hour_angle(latitude: latitude, declination: dec, zenith: adjustedZenith, direction: direction)
    let deltaAngle = -observer.longitude - degrees(ha)
    let eqtime = eq_of_time(juliancentury: jc)
    var offset = deltaAngle * 4.0 - eqtime
    adjustOffsetForDayBoundary(&offset)
    let newTimeUTC = 720.0 + offset
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
    nanosecond: td.nanosecond)
}

// MARK: - Solar Angles (Zenith and Azimuth)

/// Calculates the solar zenith and azimuth (in degrees) for the observer at a given time.
/// - Parameters:
///   - observer: The observer's location information.
///   - dateandtime: The time of observation as DateComponents.
///   - with_refraction: If true, adjusts the computed zenith for atmospheric refraction.
/// - Returns: A tuple (zenith, azimuth) in degrees.
func zenith_and_azimuth(
  observer: Observer,
  dateandtime: DateComponents,
  with_refraction: Bool = true) -> (Double, Double)
{
  let latitude = max(min(observer.latitude, 89.8), -89.8)
  let longitude = observer.longitude

  // Determine the UTC time from the provided time zone.
  let zone: Double
  let utcDatetime: DateComponents
  if let tz = dateandtime.timeZone {
    zone = -Double(tz.secondsFromGMT()) / 3600.0
    utcDatetime = dateandtime.astimezone(.utc)
  } else {
    zone = 0.0
    utcDatetime = dateandtime
  }

  let jd = julianDay(at: utcDatetime)
  let t = julianDayToCentury(julianDay: jd)
  let declination = sun_declination(juliancentury: t)
  let eqtime = eq_of_time(juliancentury: t)

  // True solar time adjustment.
  let solarTimeFix = eqtime + (4.0 * longitude) + (60.0 * zone)
  let totalMinutes = Double((utcDatetime.hour ?? 0) * 60 + (utcDatetime.minute ?? 0))
    + (Double(utcDatetime.second ?? 0) / 60.0)
  var trueSolarTime = totalMinutes + solarTimeFix
  while trueSolarTime > 1440 { trueSolarTime -= 1440 }
  while trueSolarTime < 0 { trueSolarTime += 1440 }

  var hourangle = trueSolarTime / 4.0 - 180.0
  if hourangle < -180.0 { hourangle += 360.0 }

  // Compute zenith angle.
  let haRad = radians(hourangle)
  let latRad = radians(latitude)
  let decRad = radians(declination)
  var csz = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
  csz = min(max(csz, -1.0), 1.0)
  var zen = degrees(acos(csz))

  // Compute azimuth.
  var az: Double
  let sinZenith = sin(radians(zen))
  let azDenom = cos(latRad) * sinZenith
  if abs(azDenom) > 0.001 {
    var azRad = (sin(latRad) * cos(radians(zen)) - sin(decRad)) / azDenom
    azRad = min(max(azRad, -1.0), 1.0)
    az = 180.0 - degrees(acos(azRad))
    if hourangle > 0 { az = -az }
  } else {
    az = (latitude > 0) ? 180.0 : 0.0
  }
  if az < 0 { az += 360.0 }

  if with_refraction {
    zen -= refractionAtZenith(zen)
  }
  return (zen, az)
}

// MARK: - Public Solar Time Functions

/// Returns the solar zenith (in degrees) for the given observer and time.
func zenith(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true)
  -> Double
{
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction).0
}

/// Returns the solar azimuth (in degrees) for the given observer and time.
func azimuth(
  observer: Observer,
  dateandtime: DateComponents = Date().components())
  -> Double
{
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime).1
}

/// Returns the solar elevation (in degrees) for the given observer and time.
func elevation(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true)
  -> Double
{
  90.0 - zenith(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction)
}

// MARK: - Core Sunrise/Sunset and Twilight Routines

/// Calculates dawn time for the given observer and date, using a specified depression angle.
/// - Parameters:
///   - observer: The observer's location information.
///   - date: The date (in UTC) as DateComponents.
///   - depression: The depression angle (in degrees) to define twilight (default is .civil).
///   - tzinfo: The desired time zone for the output (default is UTC).
/// - Returns: A DateComponents representing the dawn time.
/// - Throws: SunError.valueError if a dawn time cannot be determined.
func dawn(
  observer: Observer,
  date: DateComponents,
  depression: Depression = .civil,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  let dep = depression.rawValue.double
  var tot = time_of_transit(observer: observer, date: date, zenith: 90.0 + dep, direction: .rising)
    .astimezone(tzinfo)
  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date {
      newDate.setValue((date.day ?? 0) + 1, for: .day)
    } else {
      newDate.setValue((date.day ?? 0) - 1, for: .day)
    }
    tot = time_of_transit(observer: observer, date: newDate, zenith: 90.0 + dep, direction: .rising)
      .astimezone(tzinfo)
    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a dawn time on the date specified")
    }
  }
  return tot
}

/// Calculates sunrise time for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A DateComponents representing sunrise time.
/// - Throws: SunError.valueError if a sunrise time cannot be determined.
func sunrise(
  observer: Observer,
  date: DateComponents,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  var tot = time_of_transit(observer: observer, date: date, zenith: 90.0 + SUN_APPARENT_RADIUS, direction: .rising)
    .astimezone(tzinfo)
  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else { newDate.setValue((date.day ?? 0) - 1, for: .day) }
    tot = time_of_transit(observer: observer, date: newDate, zenith: 90.0 + SUN_APPARENT_RADIUS, direction: .rising)
      .astimezone(tzinfo)
    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a sunrise time on the date specified")
    }
  }
  return tot
}

/// Calculates sunset time for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A DateComponents representing sunset time.
/// - Throws: SunError.valueError if a sunset time cannot be determined.
func sunset(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  var tot = time_of_transit(observer: observer, date: date, zenith: 90.0 + SUN_APPARENT_RADIUS, direction: .setting)
    .astimezone(tzinfo)
  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else { newDate.setValue((date.day ?? 0) - 1, for: .day) }
    tot = time_of_transit(observer: observer, date: newDate, zenith: 90.0 + SUN_APPARENT_RADIUS, direction: .setting)
      .astimezone(tzinfo)
    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a sunset time on the date specified")
    }
  }
  return tot
}

/// Calculates dusk time for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - depression: The depression angle (in degrees) for twilight (default is .civil).
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A DateComponents representing dusk time.
/// - Throws: SunError.valueError if a dusk time cannot be determined.
func dusk(
  observer: Observer,
  date: DateComponents = Date().components(),
  depression: Depression = .civil,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  let dep = depression.rawValue.double
  var tot = time_of_transit(observer: observer, date: date, zenith: 90.0 + dep, direction: .setting)
    .astimezone(tzinfo)
  if tot.extractYearMonthDay() != date {
    var newDate = date
    if tot < date { newDate.setValue((date.day ?? 0) + 1, for: .day) }
    else { newDate.setValue((date.day ?? 0) - 1, for: .day) }
    tot = time_of_transit(observer: observer, date: newDate, zenith: 90.0 + dep, direction: .setting)
      .astimezone(tzinfo)
    if tot.extractYearMonthDay() != date {
      throw SunError.valueError("Unable to find a dusk time on the date specified")
    }
  }
  return tot
}

// MARK: - Noon & Midnight Calculations

/// Calculates solar noon for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A DateComponents representing solar noon.
func noon(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc)
  -> DateComponents
{
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
    second: second)
  return result.astimezone(tzinfo)
}

/// Calculates solar midnight for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A DateComponents representing solar midnight.
func midnight(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc)
  -> DateComponents
{
  var copyDate = date
  copyDate.setValue(12, for: .hour)
  copyDate.setValue(0, for: .minute)
  copyDate.setValue(0, for: .second)
  copyDate.setValue(0, for: .nanosecond)

  let jd = julianDay(at: copyDate)
  let newt = julianDayToCentury(julianDay: jd + 0.5 - observer.longitude / 360.0)
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
    second: second).astimezone(tzinfo)
}

// MARK: - Additional Times (Twilight, Golden Hour, etc.)

/// Calculates the transit time (in UTC) when the Sun reaches a specified zenith,
/// using iterative refinement. This is the core routine used for sunrise, sunset,
/// dawn, dusk, etc.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - zenith: The zenith angle (in degrees) defining the event.
///   - direction: The direction (.rising or .setting).
///   - with_refraction: If true, applies atmospheric refraction adjustments.
/// - Returns: A DateComponents representing the transit time.
func time_at_elevation(
  observer: Observer,
  elevation: Double,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc,
  with_refraction: Bool = true)
  -> DateComponents
{
  var adjustedElevation = elevation
  var adjustedDirection = direction

  // If elevation > 90, treat it as the complementary case for setting.
  if elevation > 90.0 {
    adjustedElevation = 180.0 - elevation
    adjustedDirection = .setting
  }

  let zen = 90.0 - adjustedElevation
  return time_of_transit(
    observer: observer,
    date: date,
    zenith: zen,
    direction: adjustedDirection,
    with_refraction: with_refraction)
    .astimezone(tzinfo)
}

/// Returns the daylight interval (sunrise and sunset) for the given observer and date.
func daylight(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let sr = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
  let ss = try sunset(observer: observer, date: date, tzinfo: tzinfo)
  return (sr, ss)
}

/// Returns the nighttime interval (dusk and dawn of the next day) for the given observer and date.
func night(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  // Here, we use a depression angle of 6° for the dusk/dawn calculation.
  let start = try dusk(observer: observer, date: date, depression: 6, tzinfo: tzinfo)
  var tomorrow = date
  tomorrow.setValue((date.day ?? 0) + 1, for: .day)
  let end = try dawn(observer: observer, date: tomorrow, depression: 6, tzinfo: tzinfo)
  return (start, end)
}

/// Returns the twilight interval for the given observer, date, and direction.
/// - Parameters:
///   - direction: .rising or .setting.
/// - Returns: A tuple containing the start and end times of twilight.
func twilight(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  // Twilight defined at 6° depression from the horizon (i.e., zenith = 96°).
  let start = time_of_transit(observer: observer, date: date, zenith: 96, direction: direction)
    .astimezone(tzinfo)
  let end: DateComponents
  if direction == .rising {
    end = try sunrise(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
    return (start, end)
  } else {
    end = try sunset(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
    return (end, start)
  }
}

/// Returns the golden hour interval for the given observer, date, and direction.
/// - Golden hour is defined here as the period when the Sun is between 4° above and 6° below the horizon.
func golden_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = time_of_transit(observer: observer, date: date, zenith: 94, direction: direction)
    .astimezone(tzinfo)
  let end = time_of_transit(observer: observer, date: date, zenith: 84, direction: direction)
    .astimezone(tzinfo)
  return direction == .rising ? (start, end) : (end, start)
}

/// Returns the blue hour interval for the given observer, date, and direction.
/// - Blue hour is defined as the interval when the Sun is between 6° and 4° below the horizon.
func blue_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = .rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = time_of_transit(observer: observer, date: date, zenith: 96, direction: direction)
    .astimezone(tzinfo)
  let end = time_of_transit(observer: observer, date: date, zenith: 94, direction: direction)
    .astimezone(tzinfo)
  return direction == .rising ? (start, end) : (end, start)
}

// MARK: - Rahukaalam Calculation

/// Calculates the Rahukaalam interval for the given observer and date.
/// Rahukaalam is a period defined by dividing the daytime (or nighttime) into 8 equal parts
/// and selecting a specific octant based on the weekday.
/// - Parameters:
///   - daytime: If true, computes Rahukaalam during the day; otherwise during the night.
/// - Returns: A tuple of DateComponents representing the start and end of Rahukaalam.
func rahukaalam(
  observer: Observer,
  date: DateComponents = Date().components(),
  daytime: Bool = true,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start: DateComponents
  let end: DateComponents

  if daytime {
    start = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
    end = try sunset(observer: observer, date: date, tzinfo: tzinfo)
  } else {
    start = try sunset(observer: observer, date: date, tzinfo: tzinfo)
    var nextDay = date
    nextDay.setValue((date.day ?? 0) + 1, for: .day)
    end = try sunrise(observer: observer, date: nextDay, tzinfo: tzinfo)
  }

  let calendar = Calendar(identifier: .gregorian)
  guard
    let startDate = calendar.date(from: start),
    let endDate = calendar.date(from: end) else
  {
    throw SunError.valueError("Unable to compute Rahukaalam dates")
  }
  let totalSeconds = calendar.dateComponents([.second], from: startDate, to: endDate).second ?? 0
  let octantDuration = totalSeconds / 8

  // Weekday-based shift for Rahukaalam (using a preset octant index array).
  let octantIndex = [1, 6, 4, 5, 3, 2, 7]
  let originalDate = calendar.date(from: date)!
  let weekday = Calendar(identifier: .iso8601).dateComponents([.weekday], from: originalDate).weekday!
  let octant = octantIndex[weekday % 7]

  let newStartDate = calendar.date(byAdding: .second, value: octant * octantDuration, to: startDate)!
  let rahuEndDate = calendar.date(byAdding: .second, value: octantDuration, to: newStartDate)!

  let newStart = calendar.dateComponents(in: tzinfo, from: newStartDate)
  let newEnd = calendar.dateComponents(in: tzinfo, from: rahuEndDate)
  return (newStart, newEnd)
}

// MARK: - Consolidated Sun Times

/// Returns a dictionary of key solar times (dawn, sunrise, noon, sunset, dusk) for the given observer and date.
/// - Parameters:
///   - observer: The observer's location.
///   - date: The date (in UTC) as DateComponents.
///   - dawn_dusk_depression: The depression angle (in degrees) used for calculating dawn and dusk.
///   - tzinfo: The desired time zone for the result (default is UTC).
/// - Returns: A dictionary mapping keys ("dawn", "sunrise", "noon", "sunset", "dusk") to their respective DateComponents.
func sun(
  observer: Observer,
  date: DateComponents = Date().components(),
  dawn_dusk_depression: Depression = .civil,
  daytime _: Bool = true,
  tzinfo: TimeZone = .utc) throws -> [String: DateComponents]
{
  [
    "dawn": try dawn(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo),
    "sunrise": try sunrise(observer: observer, date: date, tzinfo: tzinfo),
    "noon": noon(observer: observer, date: date, tzinfo: tzinfo),
    "sunset": try sunset(observer: observer, date: date, tzinfo: tzinfo),
    "dusk": try dusk(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo),
  ]
}
