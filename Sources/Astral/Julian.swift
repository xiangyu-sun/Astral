//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

//One widely-used epoch is called J2000; it is the Julian Day for 1 Jan, 2000 at 12:00 noon = JD 2451545.0.
let julianDayEpoch = 2451545.0
let julianEC = 36525.0

func datFractionToTime(_ fraction: Double) -> DateComponents {
  var s = fraction * (24 * 60 * 60)
  let h = s / (60 * 60)
  s -= h * 60 * 60
  let m = s / 60
  s -= m * 60
  
  return DateComponents(hour: Int(h), minute: Int(m), second: Int(s))
}


/// Calculate the Julian Day (number) for the specified date/time julian day numbers for dates are calculated for the start of the day
/// - Parameters:
///   - at: <#at description#>
///   - calendar: <#calendar description#>
/// - Returns: <#description#>
func julianDay(at: DateComponents, calendar: Calendar = .init(identifier: .gregorian)) -> Double {
  guard var year = at.year?.double,
        var month = at.month?.double,
        let day = at.day?.double
  else {
    fatalError()
  }
  
  var dayFraction: Double = 0
  
  let t = timeToSeconds(dateComponent: at)
  
  dayFraction = t / (24 * 60 * 60)
  
  if month <= 2 {
    year -= 1
    month += 12
  }
  
  let a = Int(year / 100)
  var b: Double
  if calendar == Calendar(identifier: .gregorian) {
    b = 2 - a.double + Int(a / 4).double
  } else {
    b = 0
  }
  
  let jd = Int(365.25 * (year + 4716)).double
  + Int(30.6001 * (month + 1)).double
  + day
  + dayFraction
  + b
  - 1524.5
  
  return jd
}


/// Calculate the Modified Julian Date number
/// - Returns: <#description#>
func julianDayModified(at: DateComponents) -> Double {
  guard var year = at.year?.double,
        var month = at.month?.double,
        let day = at.day?.double
  else {
    fatalError()
  }
  
  var a = 10000 * year + 100 * month + day
  
  if year < 0{
    year += 1
  }
  
  if month <= 2{
    month += 12
    year -= 1
  }
  
  var b: Double
  if a <= 15821004.1{
    b = -2 + (year + 4716) / 4 - 1179
  }
  else{
    b = (year / 400) - (year / 100) + (year / 4)
  }
  
  a = 365 * year - 679004
  
  let mjd = a + b + (30.6001 * (month + 1)).rounded(.down) + day + at.hour / 24
  
  return mjd
}


func julianDayToCompoenent(jd: Double) -> DateComponents {
  let newJD = jd + 0.5
  let z = Int(newJD)
  let f = newJD - z.double
  
  var a: Int
  if z < 2299161{
    a = z
  }
  else {
    let alpha = Int((Double(z) - 1867216.25) / 36524.25)
    a = z + 1 + alpha + Int(alpha / 4.0)
  }
  
  let b = a + 1524
  let c = Int((Double(b) - 122.1) / 365.25)
  let d = Int(365.25 * Double(c))
  let e = Int((b - d) / 30.6001)
  
  let newd = b.double - d.double - Int(30.6001 * e.double).double + f
  let day = Int(newd)
  let t = newd - day.double
  var totalSeconds = t * (24 * 60 * 60)
  let hour = Int(totalSeconds / 3600)
  totalSeconds -= hour * 3600
  let minute = Int(totalSeconds / 60)
  totalSeconds -= minute * 60
  let seconds = Int(totalSeconds)
  
  var month: Int
  if e < 14{
    month = e - 1
  }
  else {
    month = e - 13
  }
  var year: Int
  if month > 2{
    year = c - 4716
  }
  else {
    year = c - 4715
  }
  
  return DateComponents(timeZone: .utc, year: year, month: month, day: day, hour: hour,minute: minute, second: seconds)
}


func julianDayToCentury(julianDay: Double) -> Double {
  (julianDay - julianDayEpoch) / julianEC
}

func julianDCenturyToDay(julianCentury: Double) -> Double {
  (julianCentury * julianEC) + julianDayEpoch
}


/// Calculate the numer of Julian Days since Jan 1.5, 2000
/// - Parameter dateComponent: <#dateComponent description#>
/// - Returns: <#description#>
func julianDay2000(at dateComponent: DateComponents) -> Double {
  return julianDay(at: dateComponent) - julianDayEpoch
}

