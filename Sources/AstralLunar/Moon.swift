//
//  File.swift
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Accelerate
import Foundation
import AstralCore

// MARK: - Error Definition

/// Error types for Moon calculations.
enum MoonError: Error {
  case invalidData(String)
}

// MARK: - Constants and Type Aliases

/// The apparent radius of the Moon in degrees (using 1896″ as the full diameter).
let moonApparentRadius = 1896.0 / (60.0 * 60.0)

/// Type alias representing a fractional revolution (0 … 1).
public typealias Revolutions = Double

// MARK: - Transit Event Structures

/// Represents a situation where no transit (rise or set) event occurs.
/// Contains a parallax value.
struct NoTransit {
  let parallax: Double
}

/// Represents a transit event (either rise or set) for the Moon.
/// - Parameters:
///   - event: A string indicating the type of event ("rise" or "set").
///   - when: The time of the event as DateComponents.
///   - azimuth: The azimuth angle (in degrees) at the event.
///   - distance: The geocentric distance value used in the calculation.
struct TransitEvent {
  let event: String
  let when: DateComponents
  let azimuth: Double
  let distance: Double
}

/// Enum encapsulating either a transit event or no transit.
enum Transit {
  case noTransit(NoTransit)
  case transitEvent(TransitEvent)
}

// MARK: - Interpolation

/// Performs a 3-point interpolation over the provided values.
/// - Parameters:
///   - f0: The function value at the first point.
///   - f1: The function value at the midpoint.
///   - f2: The function value at the third point.
///   - p:  The fractional distance (0 … 1) between the first and third points.
/// - Returns: The interpolated value.
func interpolate(_ f0: Double, _ f1: Double, _ f2: Double, _ p: Double) -> Double {
  let a = f1 - f0
  let b = f2 - f1 - a
  let f = f0 + p * (2 * a + b * (2 * p - 1))
  return f
}

// MARK: - Calendar Utilities

/// A Gregorian calendar set to UTC.
let calendarUTC: Calendar = {
  var calender = Calendar(identifier: .gregorian)
  calender.timeZone = .utc
  return calender
}()

// MARK: - Lunar Orbital Elements

/// Calculates the Moon's mean longitude (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The mean longitude as a fraction of one full revolution.
func moon_mean_longitude(jd2000: Double) -> Revolutions {
  var _mean_longitude = 0.606434 + 0.03660110129 * jd2000
  _mean_longitude = _mean_longitude - Int(_mean_longitude).double
  return _mean_longitude
}

/// Calculates the Moon's mean anomoly (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The mean anomoly as a fraction of one full revolution.
func moon_mean_anomoly(jd2000: Double) -> Revolutions {
  var _mean_anomoly = 0.374897 + 0.03629164709 * jd2000
  _mean_anomoly = _mean_anomoly - Int(_mean_anomoly).double
  return _mean_anomoly
}

/// Calculates the Moon's argument of latitude (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The argument of latitude as a fraction of one full revolution.
func moon_argument_of_latitude(jd2000: Double) -> Revolutions {
  var _argument_of_latitude = 0.259091 + 0.03674819520 * jd2000
  _argument_of_latitude = _argument_of_latitude - Int(_argument_of_latitude).double
  return _argument_of_latitude
}

/// Calculates the Moon's mean elongation from the Sun (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The mean elongation from the Sun as a fraction of one full revolution.
func moon_mean_elongation_from_sun(jd2000: Double) -> Revolutions {
  var _mean_elongation_from_sun = 0.827362 + 0.03386319198 * jd2000
  _mean_elongation_from_sun = _mean_elongation_from_sun - Int(_mean_elongation_from_sun).double
  return _mean_elongation_from_sun
}

/// Calculates the longitude of the lunar ascending node (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The lunar ascending node longitude as a fraction of one full revolution.
func longitude_lunar_ascending_node(jd2000: Double) -> Revolutions {
  let _longitude_lunar_ascending_node = moon_mean_longitude(jd2000: jd2000) - moon_argument_of_latitude(jd2000: jd2000)
  return _longitude_lunar_ascending_node
}

/// Calculates the Sun's mean longitude (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The Sun's mean longitude as a fraction of one full revolution.
func sun_mean_longitude(jd2000: Double) -> Revolutions {
  var _sun_mean_longitude = 0.779072 + 0.00273790931 * jd2000
  _sun_mean_longitude = _sun_mean_longitude - Int(_sun_mean_longitude).double
  return _sun_mean_longitude
}

/// Calculates the Sun's mean anomoly (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The Sun's mean anomoly as a fraction of one full revolution.
func sun_mean_anomoly(jd2000: Double) -> Revolutions {
  var _sun_mean_anomoly = 0.993126 + 0.00273777850 * jd2000
  _sun_mean_anomoly = _sun_mean_anomoly - Int(_sun_mean_anomoly).double
  return _sun_mean_anomoly
}

/// Calculates Venus's mean longitude (in revolutions) for the given jd2000.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: Venus's mean longitude as a fraction of one full revolution.
func venus_mean_longitude(jd2000: Double) -> Revolutions {
  var _venus_mean_longitude = 0.505498 + 0.00445046867 * jd2000
  _venus_mean_longitude = _venus_mean_longitude - Int(_venus_mean_longitude).double
  return _venus_mean_longitude
}

// MARK: - Moon Position Calculation

/// Calculates the geocentric position of the Moon (right ascension, declination, and distance)
/// based on lunar series tables and orbital elements computed for the given jd2000.
/// - Parameter jd2000: The Julian Day offset from J2000.0 (in days).
/// - Returns: An `AstralBodyPosition` representing the Moon's right ascension (radians),
///            declination (radians), and distance (in Earth radii).
func moonPosition(jd2000: Double) -> AstralBodyPosition {
  // Prepare the arguments for the series (indices correspond to positions in the table)
  let argument_values: [Double?] = [
    moon_mean_longitude(jd2000: jd2000),           // 1 = Lm
    moon_mean_anomoly(jd2000: jd2000),               // 2 = Gm
    moon_argument_of_latitude(jd2000: jd2000),       // 3 = Fm
    moon_mean_elongation_from_sun(jd2000: jd2000),   // 4 = D
    longitude_lunar_ascending_node(jd2000: jd2000),  // 5 = Om
    nil,                                           // 6 (unused)
    sun_mean_longitude(jd2000: jd2000),              // 7 = Ls
    sun_mean_anomoly(jd2000: jd2000),                // 8 = Gs
    nil, nil, nil,
    venus_mean_longitude(jd2000: jd2000)             // 12 = L2
  ]
  // Calculate the time factor T (Note: T is computed as jd2000/36525 + 1)
  let T = jd2000 / 36525 + 1

  /// Internal helper function to compute series values from a given table.
  /// - Parameter table: An array of `Table4Row` entries.
  /// - Returns: The computed series value.
  func _calc_value(_ table: [Table4Row]) -> Double {
    var result = 0.0
    for row in table {
      var revolutions = 0.0
      for (arg_number, multiplier) in row.argument_multiplers {
        if multiplier != 0 {
          let arg_value = argument_values[arg_number - 1]
          if let arg_value {
            revolutions += arg_value * multiplier.double
          } else {
            fatalError("Missing argument value in series calculation")
          }
        }
      }
      let t_multipler = row.t ? T : 1
      result += row.coefficient * t_multipler * row.sincos(revolutions * 2 * .pi)
    }
    return result
  }

  // Compute series values from lunar tables
  let v = _calc_value(table4_v)
  let u = _calc_value(table4_u)
  let w = _calc_value(table4_w)

  // Compute right ascension (in radians)
  var s = w / sqrt(u - v * v)
  let right_ascension = asin(s) + (argument_values[0] ?? 0) * 2 * .pi

  // Compute declination (in radians)
  s = v / sqrt(u)
  let declination = asin(s)

  // Compute distance (in Earth radii; approximately 6378 km)
  let distance = 60.40974 * sqrt(u)

  return AstralBodyPosition(right_ascension: right_ascension, declination: declination, distance: distance)
}

// MARK: - Moon Transit Event Calculation

/// Determines whether the Moon transits (rises or sets) during a given hour interval,
/// using quadratic interpolation over a sliding window of Moon positions.
/// - Parameters:
///   - hour: The starting hour (in UT) of the interval.
///   - lmst: The local mean sidereal time (in degrees).
///   - latitude: The observer's latitude (in degrees).
///   - distance: The Moon's distance value (from series calculation).
///   - window: A sliding window (array) of three `AstralBodyPosition` values.
/// - Returns: A `Transit` value representing either a transit event or no transit.
func moon_transit_event(
  hour: Double,
  lmst: Degrees,
  latitude: Degrees,
  distance: Double,
  window: inout [AstralBodyPosition]
) -> Transit {
  let mst = radians(lmst)
  var hour_angle = [0.0, 0.0, 0.0]
  
  // Sidereal time conversion factor (radians per hour)
  let k1 = radians(15 * 1.0027379097096138907193594760917)
  
  // Ensure right ascension continuity over the window.
  if window[2].right_ascension < window[0].right_ascension {
    window[2].right_ascension += 2 * .pi
  }
  
  hour_angle[0] = mst - window[0].right_ascension + (hour * k1)
  hour_angle[2] = mst - window[2].right_ascension + (hour * k1) + k1
  hour_angle[1] = (hour_angle[0] + hour_angle[2]) / 2
  
  // Use the average declination for the midpoint.
  window[1].declination = (window[2].declination + window[0].declination) / 2
  
  let sl = sin(radians(latitude))
  let cl = cos(radians(latitude))
  
  // Apply a parallax correction using the Moon's apparent radius.
  let z = cos(radians(90 + moonApparentRadius - (41.685 / distance)))
  
  if hour == 0 {
    window[0].distance = (
      sl * sin(window[0].declination) +
      cl * cos(window[0].declination) * cos(hour_angle[0]) -
      z
    )
  }
  
  window[2].distance = (
    sl * sin(window[2].declination) +
    cl * cos(window[2].declination) * cos(hour_angle[2]) -
    z
  )
  
  // If no sign change in the distance function, then no transit occurs.
  if window[0].distance.sign == window[2].distance.sign {
    return .noTransit(NoTransit(parallax: window[2].distance))
  }
  
  window[1].distance = (
    sl * sin(window[1].declination) +
    cl * cos(window[1].declination) * cos(hour_angle[1]) -
    z
  )
  
  // Quadratic interpolation to determine the precise transit time.
  let a = 2 * window[2].distance - 4 * window[1].distance + 2 * window[0].distance
  let b = 4 * window[1].distance - 3 * window[0].distance - window[2].distance
  var discriminant = b * b - 4 * a * window[0].distance
  
  if discriminant < 0 {
    return .noTransit(NoTransit(parallax: window[2].distance))
  }
  
  discriminant = sqrt(discriminant)
  var e = (-b + discriminant) / (2 * a)
  if e > 1 || e < 0 {
    e = (-b - discriminant) / (2 * a)
  }
  
  // The term 1/120 corresponds to a 0.5-minute correction (in hours).
  let time = hour + e + 1 / 120
  let h = Int(time)
  let m = Int((time - h.double) * 60)
  
  let sd = sin(window[1].declination)
  let cd = cos(window[1].declination)
  let hour_angle_crossing = hour_angle[0] + e * (hour_angle[2] - hour_angle[0])
  let sh = sin(hour_angle_crossing)
  let ch = cos(hour_angle_crossing)
  
  // Calculate the azimuth angle from horizontal coordinates.
  let x = cl * sd - sl * cd * ch
  let y = -cd * sh
  var az = degrees(atan2(y, x))
  if az < 0 { az += 360 }
  if az > 360 { az -= 360 }
  
  let event_time = DateComponents(hour: h, minute: m)
  if window[0].distance < 0, window[2].distance > 0 {
    return .transitEvent(TransitEvent(event: "rise", when: event_time, azimuth: az, distance: window[2].distance))
  }
  if window[0].distance > 0, window[2].distance < 0 {
    return .transitEvent(TransitEvent(event: "set", when: event_time, azimuth: az, distance: window[2].distance))
  }
  return .noTransit(NoTransit(parallax: window[2].distance))
}

// MARK: - Rise and Set Times Calculation

/// Computes the Moon's rise and set times for a given date and observer.
/// - Parameters:
///   - on: The date (as DateComponents) for which to compute the times.
///   - observer: The observer's location (including latitude, longitude, etc.).
/// - Returns: A tuple with optional DateComponents for rise and set times.
func riseset(
  on: DateComponents,
  observer: Observer
) -> (rise: DateComponents?, set: DateComponents?) {
  let utcDate = on.astimezone(.utc)
  let jd2000 = julianDay2000(at: utcDate)
  
  let t0 = lmst(dateComponents: utcDate, longitude: observer.longitude)
  
  // Sample Moon positions at 0.5-day intervals.
  var m: [AstralBodyPosition] = []
  for interval in 0..<3 {
    let pos = moonPosition(jd2000: jd2000 + (Double(interval) * 0.5))
    m.append(pos)
  }
  
  // Ensure monotonic increase in right ascension.
  for interval in 1..<3 {
    if m[interval].right_ascension <= m[interval - 1].right_ascension {
      m[interval].right_ascension += 2 * .pi
    }
  }
  
  var moon_position_window: [AstralBodyPosition] = [
    m[0],
    AstralBodyPosition.zero,
    AstralBodyPosition.zero
  ]
  
  var rise_time: DateComponents? = nil
  var set_time: DateComponents? = nil
  
  // Loop over each hour to detect transit events.
  for hour in 0..<24 {
    let ph: Double = (Double(hour) + 1) / 24
    moon_position_window[2].right_ascension = interpolate(m[0].right_ascension, m[1].right_ascension, m[2].right_ascension, ph)
    moon_position_window[2].declination = interpolate(m[0].declination, m[1].declination, m[2].declination, ph)
    
    let transit_info = moon_transit_event(hour: Double(hour), lmst: t0, latitude: observer.latitude, distance: m[1].distance, window: &moon_position_window)
    
    switch transit_info {
    case .noTransit(let noTransit):
      moon_position_window[2].distance = noTransit.parallax
    case .transitEvent(let transit):
      let query_time = DateComponents(
        timeZone: .utc,
        year: utcDate.year,
        month: utcDate.month,
        day: utcDate.day,
        hour: hour,
        minute: 0,
        second: 0
      )
      
      if transit.event == "rise" {
        let event_time = transit.when
        let event = DateComponents(
          timeZone: .utc,
          year: utcDate.year,
          month: utcDate.month,
          day: utcDate.day,
          hour: utcDate.hour! + event_time.hour!,
          minute: utcDate.minute! + event_time.minute!
        )
        if rise_time == nil {
          rise_time = event
        } else {
          let rq_diff = calendarUTC.date(from: rise_time!)!.timeIntervalSince(calendarUTC.date(from: query_time)!)
          let eq_diff = calendarUTC.date(from: event)!.timeIntervalSince(calendarUTC.date(from: query_time)!)
          
          var sq_diff: TimeInterval = 0
          if let set_time = set_time {
            sq_diff = calendarUTC.date(from: set_time)!.timeIntervalSince(calendarUTC.date(from: query_time)!)
          }
          
          let update_rise_time = (rq_diff.sign == eq_diff.sign && fabs(rq_diff) > fabs(eq_diff)) ||
            (rq_diff.sign != eq_diff.sign && set_time != nil && rq_diff.sign == sq_diff.sign)
          
          if update_rise_time {
            rise_time = event
          }
        }
      }
      else if transit.event == "set" {
        let event_time = transit.when
        let event = DateComponents(
          timeZone: .utc,
          year: utcDate.year,
          month: utcDate.month,
          day: utcDate.day,
          hour: utcDate.hour! + event_time.hour!,
          minute: utcDate.minute! + event_time.minute!
        )
        if set_time == nil {
          set_time = event
        } else {
          let sq_diff = calendarUTC.date(from: set_time!)!.timeIntervalSince(calendarUTC.date(from: query_time)!)
          let eq_diff = calendarUTC.date(from: event)!.timeIntervalSince( calendarUTC.date(from: query_time)!)
          
          var rq_diff: TimeInterval = 0
          if let rise_time = rise_time {
            rq_diff = calendarUTC.date(from: rise_time)!.timeIntervalSince( calendarUTC.date(from: query_time)!)
          }
          
          let update_set_time = (sq_diff.sign == eq_diff.sign && fabs(sq_diff) > fabs(eq_diff)) ||
            (sq_diff.sign != eq_diff.sign && rise_time != nil && rq_diff.sign == sq_diff.sign)
          
          if update_set_time {
            set_time = event
          }
        }
      }
    }
    
    // Shift the window for the next iteration.
    moon_position_window[0] = moon_position_window[2]
  }
  return (rise_time, set_time)
}

// MARK: - Moon Rise and Set

/// Calculates the Moon rise time for the specified observer and date.
/// - Parameters:
///   - observer: The observer for which to calculate moonrise.
///   - dateComponents: The date as DateComponents (if nil, today's date is used).
///   - tzinfo: The desired timezone for the result (default is UTC).
/// - Returns: The DateComponents representing the moonrise time.
/// - Throws: `MoonError.invalidData` if the Moon never rises on the given date/location.
func moonrise(
  observer: Observer,
  dateComponents: DateComponents?,
  tzinfo: TimeZone = .utc
) throws -> DateComponents? {
  var date: DateComponents
  if let dateComponents {
    date = dateComponents
  } else {
    date = Calendar.current.dateComponents(in: tzinfo, from: Date())
  }
  
  var info = riseset(on: date, observer: observer)
  if let moonRise = info.rise {
    var rise = moonRise.astimezone(tzinfo)
    var rd = rise.extractYearMonthDay(timeZone: tzinfo)
    if rd != date {
      let delta = rd > date ? -1 : 1
      var new_date = date
      new_date.day = date.day! + delta
      info = riseset(on: new_date, observer: observer)
      if let newRise = info.rise {
        rise = newRise.astimezone(tzinfo)
        rd = rise.extractYearMonthDay(timeZone: tzinfo)
        if rd != date {
          return nil
        }
      }
    }
    return rise
  } else {
    throw MoonError.invalidData("Moon never rises on this date, at this location")
  }
}

/// Calculates the Moon set time for the specified observer and date.
/// - Parameters:
///   - observer: The observer for which to calculate moonset.
///   - dateComponents: The date as DateComponents (if nil, today's date is used).
///   - tzinfo: The desired timezone for the result (default is UTC).
/// - Returns: The DateComponents representing the moonset time.
/// - Throws: `MoonError.invalidData` if the Moon never sets on the given date/location.
func moonset(
  observer: Observer,
  dateComponents: DateComponents?,
  tzinfo: TimeZone = .utc
) throws -> DateComponents? {
  var date: DateComponents
  if let dateComponents {
    date = dateComponents
  } else {
    date = Calendar.current.dateComponents(in: tzinfo, from: Date())
  }
  
  var info = riseset(on: date, observer: observer)
  if let moonSet = info.set {
    var set = moonSet.astimezone(tzinfo)
    var sd = set.extractYearMonthDay(timeZone: tzinfo)
    if sd != date {
      let delta = sd > date ? -1 : 1
      var new_date = date
      new_date.day = date.day! + delta
      info = riseset(on: new_date, observer: observer)
      if let newSet = info.set {
        set = newSet.astimezone(tzinfo)
        sd = set.extractYearMonthDay(timeZone: tzinfo)
        if sd != date {
          return nil
        }
      }
    }
    return set
  } else {
    throw MoonError.invalidData("Moon never set on this date, at this location")
  }
}

// MARK: - Horizontal Coordinates

/// Calculates the Moon's azimuth (in degrees) at the specified time for the observer.
/// - Parameters:
///   - observer: The observer for which to calculate azimuth.
///   - at: The time as DateComponents (default is now).
/// - Returns: The azimuth angle (in degrees).
func azimuth(
  observer: Observer,
  at: DateComponents = Date().components()
) -> Degrees {
  let jd2000 = julianDay2000(at: at)
  let position = moonPosition(jd2000: jd2000)
  let lst0: Radians = radians(lmst(dateComponents: at, longitude: observer.longitude))
  let hourangle: Radians = lst0 - position.right_ascension

  let sh = sin(hourangle)
  let ch = cos(hourangle)
  let sd = sin(position.declination)
  let cd = cos(position.declination)
  let sl = sin(radians(observer.latitude))
  let cl = cos(radians(observer.latitude))

  let x = -ch * cd * sl + sd * cl
  let y = -sh * cd
  var azimuth = degrees(atan2(y, x)).truncatingRemainder(dividingBy: 360)
  if azimuth.sign == .minus {
    azimuth += 360
  }
  return azimuth
}

/// Calculates the Moon's elevation (in degrees) at the specified time for the observer.
/// - Parameters:
///   - observer: The observer for which to calculate elevation.
///   - at: The time as DateComponents (default is now).
/// - Returns: The elevation angle (in degrees).
func elevation(
  observer: Observer,
  at: DateComponents = Date().components()
) -> Double {
  let jd2000 = julianDay2000(at: at)
  let position = moonPosition(jd2000: jd2000)
  let lst0: Radians = radians(lmst(dateComponents: at, longitude: observer.longitude))
  let hourangle: Radians = lst0 - position.right_ascension

  let sh = sin(hourangle)
  let ch = cos(hourangle)
  let sd = sin(position.declination)
  let cd = cos(position.declination)
  let sl = sin(radians(observer.latitude))
  let cl = cos(radians(observer.latitude))

  let x = -ch * cd * sl + sd * cl
  let y = -sh * cd
  let z = ch * cd * cl + sd * sl
  let r = sqrt(x * x + y * y)
  return degrees(atan2(z, r))
}

/// Calculates the Moon's zenith angle (in degrees) for the specified time and observer.
/// - Parameters:
///   - observer: The observer for which to calculate the zenith.
///   - at: The time as DateComponents (default is now).
/// - Returns: The zenith angle (in degrees).
func zenith(
  observer: Observer,
  at: DateComponents = Date().components()
) -> Double {
  return 90 - elevation(observer: observer, at: at)
}

// MARK: - Ecliptic Coordinates

/// Calculates the mean obliquity of the ecliptic (in radians) for the given Julian date offset.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The obliquity of the ecliptic in radians.
func obliquity_of_ecliptic(jd2000: Double) -> Radians {
  let T = jd2000 / 36525
  // IAU 1980 mean obliquity in arc seconds
  let seconds = 21.448 - 46.8150 * T - 0.00059 * T * T + 0.001813 * T * T * T
  let e0 = (23.0 + (26.0 / 60.0) + (seconds / 3600.0)) * Double.pi / 180.0
  return e0
}

/// Calculates the Moon's true ecliptic longitude (in revolutions) for the given Julian date offset.
/// - Parameter jd2000: Julian Day offset from J2000.0 (in days).
/// - Returns: The true ecliptic longitude as a fraction of one full revolution.
public func moon_true_longitude(jd2000: Double) -> Revolutions {
  // Compute geocentric position (right ascension and declination)
  let pos = moonPosition(jd2000: jd2000)
  let ε = obliquity_of_ecliptic(jd2000: jd2000)
  let α = pos.right_ascension
  let δ = pos.declination
  // Ecliptic longitude λ
  let λ = atan2(sin(α) * cos(ε) + tan(δ) * sin(ε), cos(α))
  // Normalize to 0…1 revolutions
  var rev = λ / (2 * .pi)
  rev = rev - Double(Int(rev))
  if rev < 0 { rev += 1 }
  return rev
}
