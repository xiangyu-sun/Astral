//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation
import Accelerate

enum MoonError : Error {
  case invalidData(String)
}

let moonApparentRadius = 1896.0 / (60.0 * 60.0)
typealias Revolutions = Double


struct NoTransit {
  let parallax: Double
}


struct TransitEvent {
  let event: String
  let when: DateComponents
  let azimuth: Double
  let distance: Double
}

enum Transit {
  case noTransit(NoTransit)
  case transitEvent(TransitEvent)
}


/// 3-point interpolation
/// - Parameters:
///   - f0: <#f0 description#>
///   - f1: <#f1 description#>
///   - f2: <#f2 description#>
///   - p: <#p description#>
/// - Returns: <#description#>
func interpolate(_ f0: Double, _ f1: Double, _ f2: Double, _ p: Double) -> Double {
  let a = f1 - f0
  let b = f2 - f1 - a
  let f = f0 + p * (2 * a + b * (2 * p - 1))
  return f
}


func moon_mean_longitude(jd2000: Double) -> Revolutions {
  var _mean_longitude = 0.606434 + 0.03660110129 * jd2000
  _mean_longitude = _mean_longitude - Int(_mean_longitude).double
  return _mean_longitude
}


func moon_mean_anomoly(jd2000: Double) -> Revolutions {
  var _mean_anomoly = 0.374897 + 0.03629164709 * jd2000
  _mean_anomoly = _mean_anomoly - Int(_mean_anomoly).double
  return _mean_anomoly
}

func moon_argument_of_latitude(jd2000: Double) -> Revolutions {
  var _argument_of_latitude = 0.259091 + 0.03674819520 * jd2000
  _argument_of_latitude = _argument_of_latitude - Int(_argument_of_latitude).double
  return _argument_of_latitude
}

func moon_mean_elongation_from_sun(jd2000: Double) -> Revolutions {
  var _mean_elongation_from_sun = 0.827362 + 0.03386319198 * jd2000
  _mean_elongation_from_sun = _mean_elongation_from_sun - Int(
    _mean_elongation_from_sun
  ).double
  return _mean_elongation_from_sun
}

func longitude_lunar_ascending_node(jd2000: Double) -> Revolutions {
  let _longitude_lunar_ascending_node = moon_mean_longitude(
    jd2000: jd2000
  ) - moon_argument_of_latitude(jd2000: jd2000)
  return _longitude_lunar_ascending_node
}


func sun_mean_longitude(jd2000: Double) -> Revolutions {
  var _sun_mean_longitude = 0.779072 + 0.00273790931 * jd2000
  _sun_mean_longitude = _sun_mean_longitude - Int(_sun_mean_longitude).double
  return _sun_mean_longitude
}

func sun_mean_anomoly(jd2000: Double) -> Revolutions {
  var _sun_mean_anomoly = 0.993126 + 0.00273777850 * jd2000
  _sun_mean_anomoly = _sun_mean_anomoly - Int(_sun_mean_anomoly).double
  return _sun_mean_anomoly
}

func venus_mean_longitude(jd2000: Double) -> Revolutions{
  var _venus_mean_longitude = 0.505498 + 0.00445046867 * jd2000
  _venus_mean_longitude = _venus_mean_longitude - Int(_venus_mean_longitude).double
  return _venus_mean_longitude
}


/// Calculate right ascension, declination and geocentric distance for the moon
func moonPosition(jd2000: Double) -> AstralBodyPosition {
  let argument_values: [Double?] = [
    moon_mean_longitude(jd2000: jd2000),  // 1 = Lm
    moon_mean_anomoly(jd2000: jd2000),  // 2 = Gm
    moon_argument_of_latitude(jd2000: jd2000),  // 3 = Fm
    moon_mean_elongation_from_sun(jd2000: jd2000),  // 4 = D
    longitude_lunar_ascending_node(jd2000: jd2000),  // 5 = Om
    nil,  // 6
    sun_mean_longitude(jd2000: jd2000),  // 7 = Ls
    sun_mean_anomoly(jd2000: jd2000),  // 8 = Gs
    nil,  // 9
    nil,  // 10
    nil,  // 11
    venus_mean_longitude(jd2000: jd2000),  // 12 = L2
  ]
  let T = jd2000 / 36525 + 1
  
  func _calc_value(_ table: [Table4Row]) -> Double {
    var result = 0.0
    for row in table{
      var revolutions: Double = 0.0
      for (arg_number, multiplier) in row.argument_multiplers {
        if multiplier != 0 {
          let arg_value = argument_values[arg_number - 1]
          if let arg_value {
            let value = arg_value * multiplier.double
            revolutions += value
          }
          else {
            fatalError()
          }
        }
      }
      
      let t_multipler = row.t ? T : 1
      result += row.coefficient * t_multipler * row.sincos(revolutions * 2 * .pi)
    }
    return result
  }
  
  let v = _calc_value(table4_v)
  let u = _calc_value(table4_u)
  let w = _calc_value(table4_w)
  
  var s = w / sqrt(u - v * v)
  let right_ascension = asin(s) + (argument_values[0] ?? 0) * 2 * .pi  // In radians
  
  s = v / sqrt(u)
  let declination = asin(s)  // In radians
  
  let distance = 60.40974 * sqrt(u)  // In Earth radii (≈6378km)
  
  return AstralBodyPosition(right_ascension: right_ascension, declination: declination, distance: distance)
}


/**
 Check if the moon transits the horizon within the window.
 Args:
 hour: Hour of the day
 lmst: Local mean sidereal time in degrees
 latitude: Observer latitude
 distance: Distance to the moon
 window: Sliding window of moon positions that covers a part of the day
 */
func moon_transit_event(
  hour: Double,
  lmst: Degrees,
  latitude: Degrees,
  distance: Double,
  window: [AstralBodyPosition]
) -> Transit {
  var newWindow = window
  
  let mst = Angle.deg2rad(lmst)
  var hour_angle = [0.0, 0.0, 0.0]
  
  let k1 = Angle.deg2rad(15 * 1.0027379097096138907193594760917)
  
  if newWindow[2].right_ascension < newWindow[0].right_ascension {
    newWindow[2].right_ascension = newWindow[2].right_ascension + 2 * .pi
  }
  
  hour_angle[0] = mst - newWindow[0].right_ascension + (hour * k1)
  hour_angle[2] = mst - newWindow[2].right_ascension + (hour * k1) + k1
  hour_angle[1] = (hour_angle[2] + hour_angle[0]) / 2
  
  newWindow[1].declination = (window[2].declination + window[0].declination) / 2
  
  let sl = sin(radians(latitude))
  let cl = cos(radians(latitude))
  
  // moon apparent radius + parallax correction
  let z = cos(radians(90 + moonApparentRadius - (41.685 / distance)))
  
  if hour == 0{
    newWindow[0].distance = (
      sl * sin(window[0].declination)
      + cl * cos(window[0].declination) * cos(hour_angle[0])
      - z
    )
    newWindow[2].distance = (
      sl * sin(newWindow[2].declination)
      + cl * cos(newWindow[2].declination) * cos(hour_angle[2])
      - z
    )
  }
  
  
  
  if window[0].distance.sign == newWindow[2].distance.sign{
    return .noTransit(NoTransit(parallax: newWindow[2].distance))
  }
  
  newWindow[1].distance = (
    sl * sin(newWindow[1].declination)
    + cl * cos(newWindow[1].declination) * cos(hour_angle[1])
    - z
  )
  
  let a = 2 * newWindow[2].distance - 4 * newWindow[1].distance + 2 * newWindow[0].distance
  let b = 4 * newWindow[1].distance - 3 * newWindow[0].distance - newWindow[2].distance
  var discriminant = b * b - 4 * a * newWindow[0].distance
  
  if discriminant < 0 {
    return .noTransit(NoTransit(parallax: newWindow[2].distance))
  }
  
  discriminant = sqrt(discriminant)
  
  var e = (-b + discriminant) / (2 * a)
  if e > 1 || e < 0 {
    e = (-b - discriminant) / (2 * a)
  }
  
  let time = hour + e + 1 / 120
  
  let h = Int(time)
  let m = Int((time - h.double) * 60)
  
  let sd = sin(window[1].declination)
  let cd = cos(window[1].declination)
  
  let hour_angle_crossing = hour_angle[0] + e * (hour_angle[2] - hour_angle[0])
  let sh = sin(hour_angle_crossing)
  let ch = cos(hour_angle_crossing)
  
  let x = cl * sd - sl * cd * ch
  let y = -cd * sh
  
  var az = degrees(atan2(y, x))
  if az < 0{
    az += 360
  }
  if az > 360{
    az -= 360
  }
  
  let event_time = DateComponents(hour: h, minute: m)
  if newWindow[0].distance < 0 && newWindow[2].distance > 0{
    return .transitEvent(TransitEvent(event: "rise", when: event_time, azimuth: az, distance: newWindow[2].distance))
  }
  if newWindow[0].distance > 0 && newWindow[2].distance < 0{
    return .transitEvent(TransitEvent(event: "set", when: event_time, azimuth: az, distance: newWindow[2].distance))
  }
  return .noTransit(NoTransit(parallax: newWindow[2].distance))
}



/// Calculate rise and set times
/// - Parameters:
///   - on: <#on description#>
///   - observer: <#observer description#>
func riseset(
  on: DateComponents,
  observer: Observer
) -> (rise: DateComponents?, set: DateComponents?) {
  let jd2000 = julianDay2000(at: on)
  let t0 = lmst(
    dateComponents: on,
    longitude: observer.coordinate2D.longitude
  )
  
  var m: [AstralBodyPosition] = []
  
  for interval in 0..<3 {
    let pos = moonPosition(jd2000: jd2000 + (interval * 0.5))
    m.append(pos)
  }
  
  for interval in 1..<3 {
    if m[interval].right_ascension <= m[interval - 1].right_ascension {
      m[interval].right_ascension = m[interval].right_ascension + 2 * .pi
    }
  }
  
  var moon_position_window: [AstralBodyPosition] = [
    m[0],  // copy m[0]
    AstralBodyPosition.zero,
    AstralBodyPosition.zero,
  ]
  
  var rise_time: DateComponents? = nil
  var set_time:DateComponents? = nil
  
  // events = []
  for hour in 0..<24{
    let ph = (hour + 1) / 24
    moon_position_window[2].right_ascension = interpolate(
      m[0].right_ascension,
      m[1].right_ascension,
      m[2].right_ascension,
      ph.double
    )
    moon_position_window[2].declination = interpolate(
      m[0].declination,
      m[1].declination,
      m[2].declination,
      ph.double
    )
    
    let transit_info = moon_transit_event(
      hour: hour.double, lmst: t0, latitude: observer.coordinate2D.latitude, distance: m[1].distance, window: moon_position_window
    )
    
    if case let .noTransit(noTransit) = transit_info {
      moon_position_window[2].distance = noTransit.parallax
    } else if case let .transitEvent(transit) = transit_info {
      let query_time = DateComponents(timeZone: .utc, year: on.year, month: on.month)
      
      if transit.event == "rise" {
        let event_time = transit.when
        let event = DateComponents(timeZone: .utc, year: on.year, month: on.month, day: on.day, hour: event_time.hour, minute: event_time.minute)
        
        if rise_time == nil{
          rise_time = event
        }
        else{
          
          let rq_diff = query_time.date!.distance(to: rise_time!.date!)
          let eq_diff = query_time.date!.distance(to: event.date!)
          
          var sq_diff: TimeInterval
          if set_time != nil {
            sq_diff = query_time.date!.distance(to: set_time!.date!)
          }
          else {
            sq_diff = 0
          }
          
          var update_rise_time = rq_diff.sign == eq_diff.sign && fabs(rq_diff) > fabs(eq_diff)
          update_rise_time = update_rise_time || rq_diff.sign != eq_diff.sign && (set_time != nil && rq_diff.sign == sq_diff.sign)
          
          if update_rise_time{
            rise_time = event
          }
        }
      }
      else if transit.event == "set"{
        let event_time = transit.when
        let event = DateComponents(timeZone: .utc, year: on.year, month: on.month, day: on.day, hour: event_time.hour, minute: event_time.minute)
        
        if set_time == nil {
          set_time = event
        }
        else{
          
          let sq_diff = query_time.date!.distance(to: set_time!.date!)
          let eq_diff = query_time.date!.distance(to: event.date!)
          
          var rq_diff: TimeInterval
          if rise_time != nil{
            rq_diff = query_time.date!.distance(to: rise_time!.date!)
          }
          else{
            rq_diff = 0
          }
          
          var update_set_time = sq_diff.sign == eq_diff.sign && fabs(sq_diff) > fabs(eq_diff)
          update_set_time = update_set_time || sq_diff.sign != eq_diff.sign && (rise_time != nil && rq_diff.sign == sq_diff.sign)
          
          if update_set_time{
            set_time = event
          }
        }
        
        moon_position_window[0].right_ascension = moon_position_window[
          2
        ].right_ascension
        moon_position_window[0].declination = moon_position_window[2].declination
        moon_position_window[0].distance = moon_position_window[2].distance
      }
    }
  }
  return (rise_time, set_time)
}


/**
 Calculate the moon rise time
 Args:
 observer: Observer to calculate moonrise for
 date:     Date to calculate for. Default is today's date in the
 timezone `tzinfo`.
 tzinfo:   Timezone to return times in. Default is UTC.
 Returns:
 Date and time at which moonrise occurs.
 */
func moonrise(
  observer: Observer,
  dateComponents: DateComponents?,
  tzinfo: TimeZone = .utc
) throws -> DateComponents? {
  var date: DateComponents
  
  if let dateComponents  {
    date = dateComponents
  }else {
    date = Calendar.current.dateComponents(in: tzinfo, from: Date())
  }
  
  var info = riseset(on: date, observer: observer)
  if let moonRise = info.rise {
    var rise = moonRise.astimezone(tzinfo)
    var rd = rise.extractYearMonthDay()
    if rd != date{
      var delta: Int
      if rd > date{
        delta = -1
      }
      else{
        delta = 1
      }
      var new_date = date
      new_date.day = date.day! + delta
      
      info = riseset(on:new_date, observer: observer)
      
      if let newRise = info.rise {
        rise = newRise.astimezone(tzinfo)
        rd = rise.extractYearMonthDay()
        if rd != date {
          return nil
        }
      }
    }
    return rise
  }
  else{
    throw MoonError.invalidData("Moon never rises on this date, at this location")
  }
}


/**
 Calculate the moon set time
 Args:
 observer: Observer to calculate moonset for
 date:     Date to calculate for. Default is today's date in the
 timezone `tzinfo`.
 tzinfo:   Timezone to return times in. Default is UTC.
 Returns:
 Date and time at which moonset occurs.
 */
func moonset(
  observer: Observer,
  dateComponents: DateComponents?,
  tzinfo: TimeZone = .utc
) throws -> DateComponents? {
  
  var date: DateComponents
  
  if let dateComponents  {
    date = dateComponents
  }else {
    date = Calendar.current.dateComponents(in: tzinfo, from: Date())
  }
  
  var info = riseset(on: date, observer: observer)
  
  if let moonSet = info.set {
    var set = moonSet.astimezone(tzinfo)
    var sd = set.extractYearMonthDay()
    if sd != date{
      var delta: Int
      if sd > date{
        delta = -1
      }
      else{
        delta = 1
      }
      var new_date = date
      new_date.day = date.day! + delta
      
      info = riseset(on:new_date, observer: observer)
      
      if let newSet = info.set {
        set = newSet.astimezone(tzinfo)
        sd = set.extractYearMonthDay()
        if sd != date {
          return nil
        }
      }
      
    }
    return set
  }
  else{
    throw MoonError.invalidData("Moon never set on this date, at this location")
  }
}

func azimuth(
  observer: Observer,
  at: DateComponents = Date.now.components()
) -> Degrees {
  let jd2000 = julianDay2000(at: at)
  let position = moonPosition(jd2000: jd2000)
  let lst0: Radians = radians(lmst(dateComponents: at, longitude: observer.coordinate2D.longitude))
  let hourangle: Radians = lst0 - position.right_ascension
  
  let sh = sin(hourangle)
  let ch = cos(hourangle)
  let sd = sin(position.declination)
  let cd = cos(position.declination)
  let sl = sin(radians(observer.coordinate2D.latitude))
  let cl = cos(radians(observer.coordinate2D.latitude))
  
  let x = -ch * cd * sl + sd * cl
  let y = -sh * cd
  let azimuth = degrees(atan2(y, x)).truncatingRemainder(dividingBy: 360)
  return azimuth
}


func elevation(
  observer: Observer,
  at: DateComponents = Date.now.components()
) -> Double {
  
  let jd2000 = julianDay2000(at: at)
  let position = moonPosition(jd2000: jd2000)
  let lst0: Radians = radians(lmst(dateComponents: at, longitude: observer.coordinate2D.longitude))
  let hourangle: Radians = lst0 - position.right_ascension
  
  let sh = sin(hourangle)
  let ch = cos(hourangle)
  let sd = sin(position.declination)
  let cd = cos(position.declination)
  let sl = sin(radians(observer.coordinate2D.latitude))
  let cl = cos(radians(observer.coordinate2D.latitude))
  
  let x = -ch * cd * sl + sd * cl
  let y = -sh * cd
  
  let z = ch * cd * cl + sd * sl
  let r = sqrt(x * x + y * y)
  let elevation = degrees(atan2(z, r))
  
  return elevation
}


func zenith(
    observer: Observer,
    at: DateComponents = Date.now.components()
) -> Double {
  return 90 - elevation(observer: observer, at: at)
}



func _phase_asfloat(date: DateComponents) -> Double {
  let jd = julianDay(at: date)
  let dt = pow((jd - 2382148), 2) / (41048480 * 86400)
  let t = (jd + dt - 2451545.0) / 36525
  let t2 = pow(t, 2)
  let t3 = pow(t, 3)
  
  var d = 297.85 + (445267.1115 * t) - (0.0016300 * t2) + (t3 / 545868)
  d = radians(d.truncatingRemainder(dividingBy: 360.0))
  
  var m = 357.53 + (35999.0503 * t)
  m = radians(m.truncatingRemainder(dividingBy: 360.0))
  
  var m1 = 134.96 + (477198.8676 * t) + (0.0089970 * t2) + (t3 / 69699)
  m1 = radians(m1.truncatingRemainder(dividingBy:  360.0))
  
  var elong = degrees(d) + 6.29 * sin(m1)
  elong -= 2.10 * sin(m)
  elong += 1.27 * sin(2 * d - m1)
  elong += 0.66 * sin(2 * d)
  elong = elong.truncatingRemainder(dividingBy: 360.0)
  elong = Int(elong).double
  let moon = ((elong + 6.43) / 360) * 28
  return moon
  
}

/**
 Calculates the phase of the moon on the specified date.
 Args:
     date: The date to calculate the phase for. Dates are always in the UTC timezone.
           If not specified then today's date is used.
 Returns:
     A number designating the phase.
     ============  ==============
     0 .. 6.99     New moon
     7 .. 13.99    First quarter
     14 .. 20.99   Full moon
     21 .. 27.99   Last quarter
     ============  ==============
 */
func phase(date: DateComponents = Date.now.components()) -> Double {
  var moon = _phase_asfloat(date: date)
  if moon >= 28.0{
    moon -= 28.0
  }
  return moon
}
