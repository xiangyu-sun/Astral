import Foundation

/**
 Converts as string of the form `degrees°minutes'seconds"[N|S|E|W]`,
 or a float encoded as a string, to a float
 N and E return positive values
 S and W return negative values
 Args:
 dms: string to convert
 limit: Limit the value between ± `limit`
 Returns:
 The number of degrees as a float
 */

enum ConvetionError: Error {
  case invalidInput
}

func convertDegreesMinutesSecondsToDouble(value: Double, limit: Double?) -> Double  {
  return value.cap(limit: limit)
}

func convertDegreesMinutesSecondsToDouble(value: String, limit: Double?) throws -> Double  {
  if let value = Double(value) {
    return value.cap(limit: limit)
  }
  
  if let match =  value.firstMatch(of: regex){
    
    let deg = Double(match.deg) ?? 0
    
    let dir = match.dir ?? "E"
    
    var res = Double(deg)
    
    if let min = Double(match.min ?? "0"){
      res += min / 60
    }
    
    if let sec = Double(match.sec ?? "0"){
      res += sec / 3600
    }
    
    if  ["S","W"].contains(dir.uppercased()) {
      res = -res
    }
    
    return res.cap(limit: limit)
  } else {
    throw ConvetionError.invalidInput
  }
}

let regex = #/(?P<deg>\d{1,3})[°]((?P<min>\d{1,2})[′'])?((?P<sec>\d{1,2})[″\"])?(?P<dir>[NSEW])?/#



extension Double {
  
  func cap(limit: Double?) -> Double {
    if let limit {
      if self > limit {
        return limit
      }
      else if self < -limit {
        return -limit
      }
      else {
        return self
      }
    } else {
      return self
    }
  }
  
}
