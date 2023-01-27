//
//  File.swift
//
//
//  Created by Xiangyu Sun on 26/1/23.
//

import Foundation

// MARK: - SunError

enum SunError: Error {
  case valueError(String)
}

// Using 32 arc minutes as sun's apparent diameter
let SUN_APPARENT_RADIUS = 32.0 / (60.0 * 2.0)

func minutes_to_timedelta(minutes: Double) -> DateComponents {
  let d = Int(minutes / 1440)
  var minutes = minutes - (d * 1440)
  minutes = minutes * 60
  let s = Int(minutes)
  let sfrac = minutes - s.double
  let ns = Int(sfrac * 3.6e+12)

  return DateComponents(day: d, second: s, nanosecond: ns)
}

/// Calculate the geometric mean longitude of the sun
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func geom_mean_long_sun(juliancentury: Double) -> Double {
  let l0 = 280.46646 + juliancentury * (36000.76983 + 0.0003032 * juliancentury)
  return l0.truncatingRemainder(dividingBy: 360.0)
}

/// Calculate the geometric mean anomaly of the sun
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func geom_mean_anomaly_sun(juliancentury: Double) -> Double {
  357.52911 + juliancentury * (35999.05029 - 0.0001537 * juliancentury)
}

/// Calculate the eccentricity of Earth's orbit
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func eccentric_location_earth_orbit(juliancentury: Double) -> Double {
  0.016708634 - juliancentury * (0.000042037 + 0.0000001267 * juliancentury)
}

/// Calculate the equation of the center of the sun
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func sun_eq_of_center(juliancentury: Double) -> Double {
  let m = geom_mean_anomaly_sun(juliancentury: juliancentury)

  let mrad = radians(m)
  let sinm = sin(mrad)
  let sin2m = sin(mrad + mrad)
  let sin3m = sin(mrad + mrad + mrad)

  let c = (
    sinm * (1.914602 - juliancentury * (0.004817 + 0.000014 * juliancentury))
      + sin2m * (0.019993 - 0.000101 * juliancentury)
      + sin3m * 0.000289)

  return c
}

/// Calculate the sun's true longitude
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func sun_true_long(juliancentury: Double) -> Double {
  let l0 = geom_mean_long_sun(juliancentury: juliancentury)
  let c = sun_eq_of_center(juliancentury: juliancentury)

  return l0 + c
}

/// Calculate the sun's true anomaly
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
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
  let true_long = sun_true_long(juliancentury: juliancentury)

  let omega = 125.04 - 1934.136 * juliancentury
  return true_long - 0.00569 - 0.00478 * sin(radians(omega))
}

func mean_obliquity_of_ecliptic(juliancentury: Double) -> Double {
  let seconds = 21.448 - juliancentury * (
    46.815 + juliancentury * (0.00059 - juliancentury * 0.001813))
  return 23.0 + (26.0 + (seconds / 60.0)) / 60.0
}

func obliquity_correction(juliancentury: Double) -> Double {
  let e0 = mean_obliquity_of_ecliptic(juliancentury: juliancentury)

  let omega = 125.04 - 1934.136 * juliancentury
  return e0 + 0.00256 * cos(radians(omega))
}

/// Calculate the sun's right ascension
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func sun_rt_ascension(juliancentury: Double) -> Double {
  let oc = obliquity_correction(juliancentury: juliancentury)
  let al = sun_apparent_long(juliancentury: juliancentury)

  let tananum = cos(radians(oc)) * sin(radians(al))
  let tanadenom = cos(radians(al))

  return degrees(atan2(tananum, tanadenom))
}

/// Calculate the sun's declination
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
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

  let Etime = (
    y * sin2l0
      - 2.0 * e * sinm
      + 4.0 * e * y * sinm * cos2l0
      - 0.5 * y * y * sin4l0
      - 1.25 * e * e * sin2m)

  return degrees(Etime) * 4.0
}

/// Calculate the hour angle of the sun
/// See https://en.wikipedia.org/wiki/Hour_angle#Solar_hour_angle
/// Args:
/// latitude: The latitude of the obersver
/// declination: The declination of the sun
/// zenith: The zenith angle of the sun
/// direction: The direction of traversal of the sun
/// Raises:
/// ValueError
func hour_angle(
  latitude: Double, declination: Double, zenith: Double, direction: SunDirection)
  -> Double
{
  let latitude_rad = radians(latitude)
  let declination_rad = radians(declination)
  let zenith_rad = radians(zenith)

  let h = (cos(zenith_rad) - sin(latitude_rad) * sin(declination_rad)) / (
    cos(latitude_rad) * cos(declination_rad))

  var hour_angle = acos(h)
  if direction == SunDirection.setting {
    hour_angle = -hour_angle
  }
  return hour_angle
}

/// Calculate the extra degrees of depression that you can see round the earth
/// due to the increase in elevation.
/// Args:
/// elevation: Elevation above the earth in metres
/// Returns:
/// A number of degrees to add to adjust for the elevation of the observer
func adjust_to_horizon(elevation: Double) -> Double {
  if elevation <= 0 {
    return 0
  }

  let r = 6356900 // radius of the earth
  let a1 = r
  let h1 = r.double + elevation
  let theta1 = acos(a1 / h1)
  return degrees(theta1)
}

/// Calculate the number of degrees to adjust for an obscuring feature
/// - Parameter elevation: <#elevation description#>
/// - Returns: <#description#>
func adjust_to_obscuring_feature(elevation: (Double, Double)) -> Double {
  if elevation.0 == 0.0 {
    return 0.0
  }

  let sign = elevation.0 < 0.0 ? -1 : 1

  return sign * degrees(
    acos(fabs(elevation.0) / sqrt(pow(elevation.0, 2) + pow(elevation.1, 2))))
}

/// Calculate the time in the UTC timezone when the sun transits the
/// specificed zenith
/// Args:
/// observer: An observer viewing the sun at a specific, latitude, longitude
/// and elevation
/// date: The date to calculate for
/// zenith: The zenith angle for which to calculate the transit time
/// direction: The direction that the sun is traversing
/// Raises:
/// ValueError if the zenith is not transitted by the sun
/// Returns:
/// the time when the sun transits the specificed zenith
func time_of_transit(
  observer: Observer,
  date: DateComponents,
  zenith: Double,
  direction: SunDirection,
  with_refraction: Bool = true)
  -> DateComponents
{
  let latitude: Double
  if observer.latitude > 89.8 {
    latitude = 89.8
  }
  else if observer.latitude < -89.8 {
    latitude = -89.8
  }
  else {
    latitude = observer.latitude
  }

  var adjustment_for_elevation = 0.0

  if case Elevetion.double(let elevetion) = observer.elevation, elevetion > 0 {
    adjustment_for_elevation = adjust_to_horizon(elevation: elevetion)
  } else if case Elevetion.tuple(let elevetion) = observer.elevation {
    adjustment_for_elevation = adjust_to_obscuring_feature(elevation: elevetion)
  }

  var adjustment_for_refraction: Double
  if with_refraction {
    adjustment_for_refraction = refractionAtZenith(
      zenith + adjustment_for_elevation)
  }
  else {
    adjustment_for_refraction = 0.0
  }

  let jd = julianDay(at: date)
  var adjustment = 0.0
  var timeUTC = 0.0

  for _ in 0..<2 {
    let jc = julianDayToCentury(julianDay: jd + adjustment)
    let declination = sun_declination(juliancentury: jc)

    let hourangle = hour_angle(
      latitude: latitude,
      declination: declination,
      zenith: zenith + adjustment_for_elevation + adjustment_for_refraction,
      direction: direction)

    let delta = -observer.longitude - degrees(hourangle)

    let eqtime = eq_of_time(juliancentury: jc)
    var offset = delta * 4.0 - eqtime

    if offset < -720.0 {
      offset += 1440
    }

    timeUTC = 720.0 + offset
    adjustment = timeUTC / 1440.0
  }

  let td = minutes_to_timedelta(minutes: timeUTC)

  return DateComponents(
    timeZone: .utc ,
    year: date.year,
    month: date.month,
    day: date.day + td.day ,
    second: td.second,
    nanosecond: td.nanosecond)
}

/// Calculates the time when the sun is at the specified elevation on the
/// specified date.
/// Note:
/// This method uses positive elevations for those above the horizon.
/// Elevations greater than 90 degrees are converted to a setting sun
/// i.e. an elevation of 110 will calculate a setting sun at 70 degrees.
/// Args:
/// elevation: Elevation of the sun in degrees above the horizon to calculate for.
/// observer:  Observer to calculate for
/// date:      Date to calculate for. Default is today's date in the timezone
/// `tzinfo`.
/// direction: Determines whether the calculated time is for the sun rising
/// or setting.
/// Use ``SunDirection.RISING`` or ``SunDirection.SETTING``.
/// Default is rising.
/// tzinfo:    Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which the sun is at the specified elevation.
func time_at_elevation(
  observer: Observer,
  elevation: Double,
  date: DateComponents = Date().components(),
  direction: SunDirection = SunDirection.rising,
  tzinfo: TimeZone = .utc,
  with_refraction: Bool = true)
  -> DateComponents
{
  var adjustedElevation: Double = elevation
  var direction: SunDirection = .rising

  if elevation > 90.0 {
    adjustedElevation = 180.0 - elevation
    direction = SunDirection.setting
  }

  let zenith = 90 - adjustedElevation

  return time_of_transit(observer: observer, date: date, zenith: zenith, direction: direction, with_refraction: with_refraction)
    .astimezone(tzinfo)
}

/// Calculate solar noon time when the sun is at its highest point.
/// Args:
/// observer: An observer viewing the sun at a specific, latitude, longitude
/// and elevation
/// date:     Date to calculate for. Default is today for the specified tzinfo.
/// tzinfo:   Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which noon occurs.
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
  }
  else if second < 0 {
    second += 60
    minute -= 1
  }

  if minute > 59 {
    minute -= 60
    hour += 1
  }
  else if minute < 0 {
    minute += 60
    hour -= 1
  }

  var copeDate = date

  if hour > 23 {
    hour -= 24
    copeDate.day = date.day + 1
  }
  else if hour < 0 {
    hour += 24
    copeDate.day = (date.day ?? 0) - 1
  }

  return DateComponents(
    timeZone: .utc,
    year: copeDate.year,
    month: copeDate.month,
    day: copeDate.day,
    hour: hour,
    minute: minute,
    second: second).astimezone(tzinfo)
}

/// Calculate solar midnight time.
/// Note:
/// This calculates the solar midnight that is closest
/// to 00:00:00 of the specified date i.e. it may return a time that is on
/// the previous day.
/// Args:
/// observer: An observer viewing the sun at a specific, latitude, longitude
/// and elevation
/// date:     Date to calculate for. Default is today for the specified tzinfo.
/// tzinfo:   Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which midnight occurs.

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
  let newt = julianDayToCentury(julianDay: jd + 0.5 + -observer.longitude / 360.0)

  let eqtime = eq_of_time(juliancentury: newt)
  var timeUTC = (-observer.longitude * 4.0) - eqtime

  timeUTC = timeUTC / 60.0
  var hour = Int(timeUTC)
  var minute = Int((timeUTC - hour.double) * 60)
  var second = Int((((timeUTC - hour.double) * 60) - minute.double) * 60)

  if second > 59 {
    second -= 60
    minute += 1
  }
  else if second < 0 {
    second += 60
    minute -= 1
  }

  if minute > 59 {
    minute -= 60
    hour += 1
  }
  else if minute < 0 {
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

func zenith_and_azimuth(
  observer: Observer,
  dateandtime: DateComponents,
  with_refraction: Bool = true) -> (Double, Double)
{
  var latitude: Double
  if observer.latitude > 89.8 {
    latitude = 89.8
  }
  else if observer.latitude < -89.8 {
    latitude = -89.8
  }
  else {
    latitude = observer.latitude
  }

  let longitude = observer.longitude

  var zone: Double
  var utc_datetime: DateComponents
  if dateandtime.timeZone == nil {
    zone = 0.0
    utc_datetime = dateandtime
  }
  else {
    zone = -dateandtime.timeZone!.secondsFromGMT() / 3600.0
    utc_datetime = dateandtime.astimezone(.utc)
  }

  let jd = julianDay(at: utc_datetime)
  let t = julianDayToCentury(julianDay: jd)
  let declination = sun_declination(juliancentury: t)
  let eqtime = eq_of_time(juliancentury: t)

  // 360deg * 4 == 1440 minutes, 60*24 = 1440 minutes == 1 rotation
  let solarTimeFix = eqtime + (4.0 * longitude) + (60 * zone)
  var trueSolarTime = (
    dateandtime.hour * 60.0
      + (dateandtime.minute?.double ?? 0)
      + dateandtime.second / 60.0
      + solarTimeFix)
  //    in minutes as a float, fractional part is seconds

  while trueSolarTime > 1440 {
    trueSolarTime = trueSolarTime - 1440
  }

  var hourangle = trueSolarTime / 4.0 - 180.0
  if hourangle < -180 {
    hourangle = hourangle + 360.0
  }

  let ch = cos(radians(hourangle))
  // sh = sin(radians(hourangle))
  let cl = cos(radians(latitude))
  let sl = sin(radians(latitude))
  let sd = sin(radians(declination))
  let cd = cos(radians(declination))

  var csz = cl * cd * ch + sl * sd

  if csz > 1.0 {
    csz = 1.0
  }
  else if csz < -1.0 {
    csz = -1.0
  }

  var zenith = degrees(acos(csz))
  var azimuth: Double

  let azDenom = cl * sin(radians(zenith))

  if abs(azDenom) > 0.001 {
    var azRad: Double
    azRad = ((sl * cos(radians(zenith))) - sd) / azDenom

    if abs(azRad) > 1.0 {
      if azRad < 0 {
        azRad = -1.0
      }
      else {
        azRad = 1.0
      }
    }
    azimuth = 180.0 - degrees(acos(azRad))

    if hourangle > 0.0 {
      azimuth = -azimuth
    }
  }
  else {
    if latitude > 0.0 {
      azimuth = 180.0
    }
    else {
      azimuth = 0.0
    }
  }

  if azimuth < 0.0 {
    azimuth = azimuth + 360.0
  }

  if with_refraction {
    zenith -= refractionAtZenith(zenith)
    // elevation = 90 - zenith
  }

  return (zenith, azimuth)
}

/// Calculate the zenith angle of the sun.
/// Args:
/// observer:    Observer to calculate the solar zenith for
/// dateandtime: The date and time for which to calculate the angle.
/// If `dateandtime` is None or is a naive Python datetime
/// then it is assumed to be in the UTC timezone.
/// with_refraction: If True adjust zenith to take refraction into account
/// Returns:
/// The zenith angle in degrees.
func zenith(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true)
  -> Double
{
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction).0
}

/// Calculate the azimuth angle of the sun.
/// Args:
/// observer:    Observer to calculate the solar azimuth for
/// dateandtime: The date and time for which to calculate the angle.
/// If `dateandtime` is None or is a naive Python datetime
/// then it is assumed to be in the UTC timezone.
/// Returns:
/// The azimuth angle in degrees clockwise from North.
/// If `dateandtime` is a naive Python datetime then it is assumed to be
/// in the UTC timezone.
func azimuth(
  observer: Observer,
  dateandtime: DateComponents = Date().components())
  -> Double
{
  zenith_and_azimuth(observer: observer, dateandtime: dateandtime).1
}

/// Calculate the sun's angle of elevation.
/// Args:
/// observer:    Observer to calculate the solar elevation for
/// dateandtime: The date and time for which to calculate the angle.
/// If `dateandtime` is None or is a naive Python datetime
/// then it is assumed to be in the UTC timezone.
/// with_refraction: If True adjust elevation to take refraction into account
/// Returns:
/// The elevation angle in degrees above the horizon.
func elevation(
  observer: Observer,
  dateandtime: DateComponents = Date().components(),
  with_refraction: Bool = true)
  -> Double
{
  90.0 - zenith(observer: observer, dateandtime: dateandtime, with_refraction: with_refraction)
}

/// Calculate dawn time.
/// Args:
/// observer:   Observer to calculate dawn for
/// date:       Date to calculate for. Default is today's date in the
/// timezone `tzinfo`.
/// depression: Number of degrees below the horizon to use to calculate dawn.
/// Default is for Civil dawn i.e. 6.0
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which dawn occurs.
/// Raises:
/// ValueError: if dawn does not occur on the specified date
func dawn(
  observer: Observer,
  date: DateComponents,
  depression: Depression = Depression.civil,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  let dep = depression.rawValue.double

  var tot = time_of_transit(
    observer: observer, date: date, zenith: 90.0 + dep,
    direction: SunDirection.rising).astimezone(
    tzinfo)

  // If the dates don't match search on either the next or previous day.
  var tot_date = tot

  if tot_date != date {
    var new_date = date

    if tot_date < date {
      new_date.setValue(date.day + 1, for: .day)
    }
    else {
      new_date.setValue(date.day! - 1, for: .day)
    }

    tot = time_of_transit(
      observer: observer,
      date: new_date,
      zenith: 90.0 + dep,
      direction: SunDirection.rising).astimezone(
      tzinfo)
    // Still can't get a time then raise the error
    tot_date = tot
    if tot_date != date {
      throw SunError.valueError("Unable to find a dawn time on the date specified")
    }
    return tot
  }
  return tot
}

/// Calculate sunrise time.
/// Args:
/// observer: Observer to calculate sunrise for
/// date:     Date to calculate for. Default is today's date in the
/// timezone `tzinfo`.
/// tzinfo:   Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which sunrise occurs.
/// Raises:
/// ValueError: if the sun does not reach the horizon on the specified date
func sunrise(
  observer: Observer,
  date: DateComponents,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + SUN_APPARENT_RADIUS,
    direction: SunDirection.rising).astimezone(
    tzinfo)

  var tot_date = tot
  if tot_date != date {
    var new_date = date

    if tot_date < date {
      new_date.setValue(date.day + 1, for: .day)
    }
    else {
      new_date.setValue(date.day! - 1, for: .day)
    }

    tot = time_of_transit(
      observer: observer,
      date: new_date,
      zenith: 90.0 + SUN_APPARENT_RADIUS,
      direction: SunDirection.rising).astimezone(
      tzinfo)

    tot_date = tot

    if tot_date != date {
      throw SunError.valueError("Unable to find a sunrise time on the date specified")
    }
    return tot
  }

  return tot
}

/// Calculate sunset time.
/// Args:
/// observer: Observer to calculate sunset for
/// date:     Date to calculate for. Default is today's date in the
/// timezone `tzinfo`.
/// tzinfo:   Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which sunset occurs.
/// Raises:
/// ValueError: if the sun does not reach the horizon
func sunset(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + SUN_APPARENT_RADIUS,
    direction: SunDirection.setting).astimezone(
    tzinfo)

  var tot_date = tot
  if tot_date != date {
    var new_date = date

    if tot_date < date {
      new_date.setValue(date.day + 1, for: .day)
    }
    else {
      new_date.setValue(date.day! - 1, for: .day)
    }

    tot = time_of_transit(
      observer: observer,
      date: new_date,
      zenith: 90.0 + SUN_APPARENT_RADIUS,
      direction: SunDirection.setting).astimezone(
      tzinfo)

    tot_date = tot

    if tot_date != date {
      throw SunError.valueError("Unable to find a sunrise time on the date specified")
    }
    return tot
  }

  return tot
}

/// Calculate dusk time.
/// Args:
/// observer:   Observer to calculate dusk for
/// date:       Date to calculate for. Default is today's date in the
/// timezone `tzinfo`.
/// depression: Number of degrees below the horizon to use to calculate dusk.
/// Default is for Civil dusk i.e. 6.0
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// Date and time at which dusk occurs.
/// Raises:
/// ValueError: if dusk does not occur on the specified date
func dusk(
  observer: Observer,
  date: DateComponents = Date().components(),
  depression: Depression = .civil,
  tzinfo: TimeZone = .utc)
  throws -> DateComponents
{
  let dep = depression.rawValue.double
  var tot = time_of_transit(
    observer: observer,
    date: date,
    zenith: 90.0 + dep,
    direction: SunDirection.setting).astimezone(
    tzinfo)

  var tot_date = tot
  if tot_date != date {
    var new_date = date

    if tot_date < date {
      new_date.setValue(date.day + 1, for: .day)
    }
    else {
      new_date.setValue(date.day! - 1, for: .day)
    }

    tot = time_of_transit(
      observer: observer,
      date: new_date,
      zenith: 90.0 + dep,
      direction: SunDirection.setting).astimezone(
      tzinfo)

    tot_date = tot

    if tot_date != date {
      throw SunError.valueError("Unable to find a sunrise time on the date specified")
    }
    return tot
  }
  return tot
}

/// Calculate daylight start and end times.
/// Args:
/// observer:   Observer to calculate daylight for
/// date:       Date to calculate for. Default is today's date in the
/// timezone `tzinfo`.
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// A tuple of the date and time at which daylight starts and ends.
/// Raises:
/// ValueError: if the sun does not rise or does not set
func daylight(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let sr = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
  let ss = try sunset(observer: observer, date: date, tzinfo: tzinfo)

  return (sr, ss)
}

/// Calculate night start and end times.
/// Night is calculated to be between astronomical dusk on the
/// date specified and astronomical dawn of the next day.
/// Args:
/// observer:   Observer to calculate night for
/// date:       Date to calculate for. Default is today's date for the
/// specified tzinfo.
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// A tuple of the date and time at which night starts and ends.
/// Raises:
/// ValueError: if dawn does not occur on the specified date or
/// dusk on the following day
func night(
  observer: Observer,
  date: DateComponents = Date().components(),
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = try dusk(observer: observer, date: date, depression: 6, tzinfo: tzinfo)

  var tomorrow = date
  tomorrow.setValue(date.day! + 1, for: .day)

  let end = try dawn(observer: observer, date: tomorrow, depression: 6, tzinfo: tzinfo)

  return (start, end)
}

/// Returns the start and end times of Twilight
/// when the sun is traversing in the specified direction.
/// This method defines twilight as being between the time
/// when the sun is at -6 degrees and sunrise/sunset.
/// Args:
/// observer:   Observer to calculate twilight for
/// date:       Date for which to calculate the times.
/// Default is today's date in the timezone `tzinfo`.
/// direction:  Determines whether the time is for the sun rising or setting.
/// Use ``astral.SunDirection.RISING`` or
/// ``astral.SunDirection.SETTING``.
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// A tuple of the date and time at which twilight starts and ends.
/// Raises:
/// ValueError: if the sun does not rise or does not set

func twilight(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = SunDirection.rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = time_of_transit(observer: observer, date: date, zenith: 90 + 6, direction: direction).astimezone(
    tzinfo)
  let end: DateComponents
  if direction == SunDirection.rising {
    end = try sunrise(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
  }
  else {
    end = try sunset(observer: observer, date: date, tzinfo: tzinfo).astimezone(tzinfo)
  }

  if direction == SunDirection.rising {
    return (start, end)
  }
  else {
    return (end, start)
  }
}

/// Returns the start and end times of the Golden Hour
/// when the sun is traversing in the specified direction.
/// This method uses the definition from PhotoPills i.e. the
/// golden hour is when the sun is between 4 degrees below the horizon
/// and 6 degrees above.
/// Args:
/// observer:   Observer to calculate the golden hour for
/// date:       Date for which to calculate the times.
/// Default is today's date in the timezone `tzinfo`.
/// direction:  Determines whether the time is for the sun rising or setting.
/// Use ``SunDirection.RISING`` or ``SunDirection.SETTING``.
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// A tuple of the date and time at which the Golden Hour starts and ends.
/// Raises:
/// ValueError: if the sun does not transit the elevations -4 & +6 degrees
func golden_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = SunDirection.rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = time_of_transit(observer: observer, date: date, zenith: 90 + 4, direction: direction).astimezone(
    tzinfo)
  let end = time_of_transit(observer: observer, date: date, zenith: 90 - 6, direction: direction).astimezone(
    tzinfo)

  if direction == SunDirection.rising {
    return (start, end)
  }
  else {
    return (end, start)
  }
}

/// Returns the start and end times of the Blue Hour
/// when the sun is traversing in the specified direction.
/// This method uses the definition from PhotoPills i.e. the
/// blue hour is when the sun is between 6 and 4 degrees below the horizon.
/// Args:
/// observer:   Observer to calculate the blue hour for
/// date:       Date for which to calculate the times.
/// Default is today's date in the timezone `tzinfo`.
/// direction:  Determines whether the time is for the sun rising or setting.
/// Use ``SunDirection.RISING`` or ``SunDirection.SETTING``.
/// tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
/// A tuple of the date and time at which the Blue Hour starts and ends.
/// Raises:
/// ValueError: if the sun does not transit the elevations -4 & -6 degrees
func blue_hour(
  observer: Observer,
  date: DateComponents = Date().components(),
  direction: SunDirection = SunDirection.rising,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  let start = time_of_transit(observer: observer, date: date, zenith: 90 + 6, direction: direction).astimezone(
    tzinfo)
  let end = time_of_transit(observer: observer, date: date, zenith: 90 + 4, direction: direction).astimezone(
    tzinfo)

  if direction == SunDirection.rising {
    return (start, end)
  }
  else {
    return (end, start)
  }
}

/// Calculate ruhakaalam times.
/// Args:
///    observer:   Observer to calculate rahukaalam for
///    date:       Date to calculate for. Default is today's date in the
///                timezone `tzinfo`.
///    daytime:    If True calculate for the day time else calculate for the
///                night time.
///    tzinfo:     Timezone to return times in. Default is UTC.
/// Returns:
///    Tuple containing the start and end times for Rahukaalam.
/// Raises:
///    ValueError: if the sun does not rise or does not set
func rahukaalam(
  observer: Observer,
  date: DateComponents = Date().components(),
  daytime: Bool = true,
  tzinfo: TimeZone = .utc) throws -> (DateComponents, DateComponents)
{
  var start: DateComponents
  var end: DateComponents

  if daytime {
    start = try sunrise(observer: observer, date: date, tzinfo: tzinfo)
    end = try sunset(observer: observer, date: date, tzinfo: tzinfo)
  }
  else {
    start = try sunset(observer: observer, date: date, tzinfo: tzinfo)

    var oneday = date
    oneday.setValue(date.day! + 1, for: .day)

    end = try sunrise(observer: observer, date: oneday, tzinfo: tzinfo)
  }

  var endDate = Calendar(identifier: .gregorian).date(from: end)!
  var startDate = Calendar(identifier: .gregorian).date(from: start)!

  let diff = Calendar(identifier: .gregorian)
    .dateComponents([.year,.month,.day,.hour,.minute,.second], from: startDate, to: endDate)

  let octant_duration = diff.second / 8

  // Mo,Sa,Fr,We,Th,Tu,Su
  let octant_index = [1, 6, 4, 5, 3, 2, 7]

  let weekday = Calendar(identifier: .iso8601).dateComponents([.weekday], from: date.date!).weekday!

  let octant = octant_index[weekday]

  startDate = Calendar(identifier: .gregorian).date(byAdding: .second, value: Int(octant_duration) * octant, to: startDate)!

  endDate = Calendar(identifier: .gregorian).date(byAdding: .second, value: Int(octant_duration), to: startDate)!

  start = Calendar(identifier: .gregorian).dateComponents(in: tzinfo, from: startDate)
  end = Calendar(identifier: .gregorian).dateComponents(in: tzinfo, from: endDate)

  return (start, end)
}

/// Calculate all the info for the sun at once.
/// Args:
///    observer:             Observer for which to calculate the times of the sun
///    date:                 Date to calculate for.
///                          Default is today's date in the timezone `tzinfo`.
///    dawn_dusk_depression: Depression to use to calculate dawn and dusk.
///                          Default is for Civil dusk i.e. 6.0
///    tzinfo:               Timezone to return times in. Default is UTC.
/// Returns:
///    Dictionary with keys ``dawn``, ``sunrise``, ``noon``, ``sunset`` and ``dusk``
///    whose values are the results of the corresponding functions.
/// Raises:
///    ValueError: if passed through from any of the functions
func sun(
  observer: Observer,
  date: DateComponents = Date().components(),
  dawn_dusk_depression: Depression = Depression.civil,
  daytime _: Bool = true,
  tzinfo: TimeZone = .utc) -> [String: DateComponents?]
{
  [
    "dawn": try? dawn(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo),
    "sunrise": try? sunrise(observer: observer, date: date, tzinfo: tzinfo),
    "noon": noon(observer: observer, date: date, tzinfo: tzinfo),
    "sunset": try? sunset(observer: observer, date: date, tzinfo: tzinfo),
    "dusk": try? dusk(observer: observer, date: date, depression: dawn_dusk_depression, tzinfo: tzinfo),
  ]
}
