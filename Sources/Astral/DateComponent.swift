import Foundation


extension TimeZone {
  static var utc: TimeZone {
    if #available(macOS 13, iOS 16, watchOS 9, *) {
      return .gmt
    } else {
      return TimeZone(secondsFromGMT: 0) ?? TimeZone.autoupdatingCurrent
    }
  }
}


extension Date {
  
  func components(calendar: Calendar = Calendar(identifier: .gregorian), timezone: TimeZone = .utc) -> DateComponents {
    return calendar.dateComponents(in: timezone, from: self)
  }
  
}

extension DateComponents {
  func extractYearMonthDay(timeZone: TimeZone = .utc) -> DateComponents {
    return DateComponents(timeZone: timeZone ,year: self.year, month: self.month, day: self.day)
  }
  
  func extractYearMonthDayHourMinuteSecond(timeZone: TimeZone = .utc) -> DateComponents {
    return DateComponents(timeZone: timeZone ,year: self.year, month: self.month, day: self.day, hour: self.hour, minute: self.month, second: self.month)
  }
  
  func astimezone(_ timeZone: TimeZone) -> DateComponents {
    let date = Calendar.current.date(from: self) ?? Date()
    return  Calendar.current.dateComponents(in: timeZone, from: date)
  }
  
  static func > (lhs: DateComponents, rhs: DateComponents) -> Bool {

    let calendar = lhs.calendar ?? .autoupdatingCurrent
    
    return calendar.compare(calendar.date(from: lhs)!, to: calendar.date(from: rhs)!, toGranularity: .day) == .orderedDescending
    
  }
}


/// Convert a Double number of hours
/// - Parameter hours: <#hours description#>
/// - Returns: <#description#>
func from(hours: Double) -> DateComponents {
  var reminder = hours
  
  let hour = Int(reminder)
  reminder -= hour.double
  
  reminder *= 60
  let minute = Int(reminder)
  reminder -= minute.double
  
  reminder *= 60
  let second = Int(reminder)
  reminder -= second.double
  
  let nanosecond = Int(reminder * 3.6e+12)

  return DateComponents(hour: hour, minute: minute, second: second, nanosecond: nanosecond)
}

func toHours(_ dateComponent: DateComponents) -> Double {
  var result: Double = 0
  result += dateComponent.hour
  result += dateComponent.minute / 60
  result += dateComponent.second / 3600
  result += dateComponent.nanosecond / 3.6e+12
  
  return result
}

/// Convert a datetime.time to a floating point number of seconds
/// - Parameter dateComponent: <#dateComponent description#>
/// - Returns: <#description#>
func toSeconds(dateComponent: DateComponents) -> Double {
  return toHours(dateComponent) * 3600
}

func timeToSeconds(dateComponent: DateComponents) -> Double {
  var result: Double = 0
  result += dateComponent.hour * 60 * 60
  result += dateComponent.minute * 60
  result += dateComponent.second
  
  return result
}


extension Optional where Wrapped == Int  {
  static func / (lhs: Self, rhs: Double) -> Double {
    guard let value = lhs else {
      return 0
    }
    return Double(value) / rhs
  }
  
  static func * (lhs: Self, rhs: Double) -> Double {
    guard let value = lhs else {
      return 0
    }
    return Double(value) * rhs
  }
}


extension Optional where Wrapped == Double  {
  static func += (lhs: inout Double, rhs: Int?){
    lhs += Double(rhs ?? 0)
  }
}
