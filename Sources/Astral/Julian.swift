//
//  Julian.swift
//
//  Created by Xiangyu Sun on 19/1/23.
//  Revised for improved accuracy on 01/02/2025.
//

import Foundation

// MARK: - Constants

/// J2000.0 epoch: Julian Day for January 1, 2000 at 12:00 UT.
let julianDayEpoch = 2451545.0
/// Number of days per Julian century.
let julianEC = 36525.0

// MARK: - Helpers

/// Converts a fractional day (0.0–1.0) into DateComponents representing hours, minutes, and seconds.
func datFractionToTime(_ fraction: Double) -> DateComponents {
  let totalSeconds = fraction * (24 * 60 * 60)
  let hours = totalSeconds / 3600
  let remainingSecondsAfterHours = totalSeconds - floor(hours) * 3600
  let minutes = remainingSecondsAfterHours / 60
  let seconds = remainingSecondsAfterHours - floor(minutes) * 60
  
  return DateComponents(hour: Int(floor(hours)),
                        minute: Int(floor(minutes)),
                        second: Int(floor(seconds)))
}

// MARK: - Julian Day Calculations

/// Calculate the Julian Day (JD) for the specified date/time.
/// The algorithm uses the standard method with corrections for the Gregorian calendar.
/// - Parameters:
///   - at: DateComponents for the date (the time portion is used to compute a day fraction).
///   - calendar: The calendar to use (default is Gregorian).
/// - Returns: The Julian Day as a Double.
func julianDay(at: DateComponents, calendar: Calendar = .init(identifier: .gregorian)) -> Double {
  // Ensure we have a valid year, month, and day.
  guard var year = at.year?.double,
        var month = at.month?.double,
        let day = at.day?.double else {
    fatalError("Invalid date components provided to julianDay(at:)")
  }
  
  // Compute the fraction of the day from the time components.
  let t = timeToSeconds(dateComponent: at)
  let dayFraction = t / (24 * 60 * 60)
  
  // Adjust months January and February.
  if month <= 2 {
    year -= 1
    month += 12
  }
  
  // Calculate the terms for the Gregorian calendar correction.
  let A = floor(year / 100)
  let B: Double
  if calendar.identifier == .gregorian {
    B = 2 - A + floor(A / 4)
  } else {
    B = 0
  }
  
  // Compute the Julian Day using floor (which is equivalent to the mathematical "floor" function).
  let jd = floor(365.25 * (year + 4716))
         + floor(30.6001 * (month + 1))
         + day + dayFraction + B - 1524.5
  return jd
}

/// Calculate the Modified Julian Date (MJD) for the specified date/time.
/// Standard definition: MJD = JD - 2400000.5
/// - Parameter at: The date as DateComponents.
/// - Returns: The Modified Julian Date as a Double.
func julianDayModified(at: DateComponents) -> Double {
  return julianDay(at: at) - 2400000.5
}

/// Convert a Julian Day number back into calendar date components.
/// - Parameter jd: The Julian Day number.
/// - Returns: A DateComponents representing the date and time (in UTC).
func julianDayToComponent(jd: Double) -> DateComponents {
  // The algorithm uses the standard inverse method.
  let newJD = jd + 0.5
  let Z = Int(floor(newJD))
  let F = newJD - Double(Z)
  
  var A: Int
  if Z < 2299161 {
    A = Z
  } else {
    let alpha = Int(floor((Double(Z) - 1867216.25) / 36524.25))
    A = Z + 1 + alpha - Int(floor(Double(alpha) / 4.0))
  }
  
  let B = A + 1524
  let C = Int(floor((Double(B) - 122.1) / 365.25))
  let D = Int(floor(365.25 * Double(C)))
  let E = Int(floor((Double(B) - Double(D)) / 30.6001))
  
  let dayFraction = Double(B) - Double(D) - floor(30.6001 * Double(E)) + F
  let day = Int(floor(dayFraction))
  let fractionOfDay = dayFraction - Double(day)
  let totalSeconds = fractionOfDay * 86400
  let hour = Int(totalSeconds / 3600)
  let minute = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
  let second = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
  
  let month: Int
  if E < 14 {
    month = E - 1
  } else {
    month = E - 13
  }
  
  let year: Int
  if month > 2 {
    year = C - 4716
  } else {
    year = C - 4715
  }
  
  return DateComponents(timeZone: TimeZone(secondsFromGMT: 0),
                        year: year,
                        month: month,
                        day: day,
                        hour: hour,
                        minute: minute,
                        second: second)
}

/// Convert a Julian Day to a Julian Century.
/// - Parameter julianDay: The Julian Day number.
/// - Returns: The Julian Century as a Double.
func julianDayToCentury(julianDay: Double) -> Double {
  return (julianDay - julianDayEpoch) / julianEC
}

/// Convert a Julian Century value back to a Julian Day.
/// - Parameter julianCentury: The number of Julian centuries since J2000.0.
/// - Returns: The corresponding Julian Day.
func julianDCenturyToDay(julianCentury: Double) -> Double {
  return (julianCentury * julianEC) + julianDayEpoch
}

/// Calculate the number of Julian Days since the J2000 epoch for the specified date.
/// - Parameter at: The date as DateComponents.
/// - Returns: The number of days (as a Double) since J2000.0.
func julianDay2000(at dateComponent: DateComponents) -> Double {
  return julianDay(at: dateComponent) - julianDayEpoch
}
