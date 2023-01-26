//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 26/1/23.
//

import Foundation

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
  return 357.52911 + juliancentury * (35999.05029 - 0.0001537 * juliancentury)
}

/// Calculate the eccentricity of Earth's orbit
/// - Parameter juliancentury: <#juliancentury description#>
/// - Returns: <#description#>
func eccentric_location_earth_orbit(juliancentury: Double) -> Double {
  return 0.016708634 - juliancentury * (0.000042037 + 0.0000001267 * juliancentury)
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
    + sin3m * 0.000289
  )
  
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

func sun_apparent_long(juliancentury: Double) -> Double{
  let true_long = sun_true_long(juliancentury: juliancentury)
  
  let omega = 125.04 - 1934.136 * juliancentury
  return true_long - 0.00569 - 0.00478 * sin(radians(omega))
}

func mean_obliquity_of_ecliptic(juliancentury: Double) -> Double{
  let seconds = 21.448 - juliancentury * (
    46.815 + juliancentury * (0.00059 - juliancentury * (0.001813))
  )
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
    - 1.25 * e * e * sin2m
  )
  
  return degrees(Etime) * 4.0
}

/**
 Calculate the hour angle of the sun
 See https://en.wikipedia.org/wiki/Hour_angle#Solar_hour_angle
 Args:
 latitude: The latitude of the obersver
 declination: The declination of the sun
 zenith: The zenith angle of the sun
 direction: The direction of traversal of the sun
 Raises:
 ValueError
 */
func hour_angle(
  latitude: Double, declination: Double, zenith: Double, direction: SunDirection
) -> Double {
  
  
  let latitude_rad = radians(latitude)
  let declination_rad = radians(declination)
  let zenith_rad = radians(zenith)
  
  let h = (cos(zenith_rad) - sin(latitude_rad) * sin(declination_rad)) / (
    cos(latitude_rad) * cos(declination_rad)
  )
  
  var hour_angle = acos(h)
  if direction == SunDirection.setting{
    hour_angle = -hour_angle
  }
  return hour_angle
}

/**
 Calculate the extra degrees of depression that you can see round the earth
 due to the increase in elevation.
 Args:
 elevation: Elevation above the earth in metres
 Returns:
 A number of degrees to add to adjust for the elevation of the observer
 */
func adjust_to_horizon(elevation: Double) -> Double {
  if elevation <= 0 {
    return 0
  }
  
  let r = 6356900  // radius of the earth
  let a1 = r
  let h1 = r.double + elevation
  let theta1 = acos(a1 / h1)
  return degrees(theta1)
}


/// Calculate the number of degrees to adjust for an obscuring feature
/// - Parameter elevation: <#elevation description#>
/// - Returns: <#description#>
func adjust_to_obscuring_feature(elevation: (Double, Double)) -> Double {
  if elevation.0 == 0.0{
    return 0.0
  }
  
  let sign = elevation.0 < 0.0 ? -1 : 1
  
  return sign * degrees(
    acos(fabs(elevation.0) / sqrt(pow(elevation.0, 2) + pow(elevation.1, 2)))
  )
}

/**
 Calculate the time in the UTC timezone when the sun transits the
 specificed zenith
 Args:
 observer: An observer viewing the sun at a specific, latitude, longitude
 and elevation
 date: The date to calculate for
 zenith: The zenith angle for which to calculate the transit time
 direction: The direction that the sun is traversing
 Raises:
 ValueError if the zenith is not transitted by the sun
 Returns:
 the time when the sun transits the specificed zenith
 */
func time_of_transit(
  observer: Observer,
  date: DateComponents,
  zenith: Double,
  direction: SunDirection,
  with_refraction: Bool = true
) -> DateComponents {
  let latitude: Double
  if observer.latitude > 89.8{
    latitude = 89.8
  }
  else if observer.latitude < -89.8{
    latitude = -89.8
  }
  else{
    latitude = observer.latitude
  }
  
  var adjustment_for_elevation = 0.0
  
  if case let Elevetion.double(elevetion) = observer.elevation, elevetion > 0 {
    adjustment_for_elevation = adjust_to_horizon(elevation: elevetion)
  }else if case let Elevetion.tuple(elevetion) = observer.elevation {
    adjustment_for_elevation = adjust_to_obscuring_feature(elevation: elevetion)
  }
  
  var adjustment_for_refraction: Double
  if with_refraction{
    adjustment_for_refraction = refractionAtZenith(
      zenith + adjustment_for_elevation
    )
  }
  else{
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
      direction: direction
    )
    
    let delta = -observer.longitude - degrees(hourangle)
    
    let eqtime = eq_of_time(juliancentury: jc)
    var offset = delta * 4.0 - eqtime
    
    if offset < -720.0{
      offset += 1440
    }
    
    timeUTC = 720.0 + offset
    adjustment = timeUTC / 1440.0
  }
  
  let td = minutes_to_timedelta(minutes: timeUTC)
  
  return DateComponents(timeZone: .utc , year:  date.year, month: date.month, day: date.day + td.day , second: td.second, nanosecond: td.nanosecond)
}


/**
 Calculates the time when the sun is at the specified elevation on the
 specified date.
 Note:
 This method uses positive elevations for those above the horizon.
 Elevations greater than 90 degrees are converted to a setting sun
 i.e. an elevation of 110 will calculate a setting sun at 70 degrees.
 Args:
 elevation: Elevation of the sun in degrees above the horizon to calculate for.
 observer:  Observer to calculate for
 date:      Date to calculate for. Default is today's date in the timezone
 `tzinfo`.
 direction: Determines whether the calculated time is for the sun rising
 or setting.
 Use ``SunDirection.RISING`` or ``SunDirection.SETTING``.
 Default is rising.
 tzinfo:    Timezone to return times in. Default is UTC.
 Returns:
 Date and time at which the sun is at the specified elevation.
 */
func time_at_elevation(
  observer: Observer,
  elevation: Double,
  date: DateComponents = Date().components(),
  direction: SunDirection = SunDirection.rising,
  tzinfo: TimeZone = .utc,
  with_refraction: Bool = true
) -> DateComponents{
  var adjustedElevation: Double = elevation
  var direction: SunDirection = .rising
  
  if elevation > 90.0{
    adjustedElevation = 180.0 - elevation
    direction = SunDirection.setting
  }
  
  let zenith = 90 - adjustedElevation
  
  return time_of_transit(observer: observer, date: date, zenith: zenith, direction: direction, with_refraction: with_refraction)
    .astimezone(tzinfo)
}
