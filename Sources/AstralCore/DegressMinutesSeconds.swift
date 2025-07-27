import Foundation

private let dmsRegex: NSRegularExpression = {
    // Matches degrees°minutes′seconds″[N|S|E|W], case-insensitive
    let pattern = #"(\d{1,3})°\s*(?:(\d{1,2})[′'])?\s*(?:(\d*\.?\d+)[″"])?\s*([NSEW])?"#
    return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
}()

// MARK: - ConvetionError

/// Converts as string of the form `degrees°minutes'seconds"[N|S|E|W]`,
/// or a float encoded as a string, to a float
/// N and E return positive values
/// S and W return negative values
/// Args:
/// dms: string to convert
/// limit: Limit the value between ± `limit`
/// Returns:
/// The number of degrees as a float

enum ConvetionError: Error {
  case invalidInput
}

func convertDegreesMinutesSecondsToDouble(value: Double, limit: Double?) -> Double {
  value.cap(limit: limit)
}

func convertDegreesMinutesSecondsToDouble(value: String, limit: Double?) throws -> Double {
    // Direct float string
    if let numeric = Double(value) {
        return numeric.cap(limit: limit)
    }

    let nsString = value as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    if let match = dmsRegex.firstMatch(in: value, options: [], range: fullRange) {
        let deg = Double(nsString.substring(with: match.range(at: 1))) ?? 0
        let min = match.range(at: 2).location != NSNotFound
                ? Double(nsString.substring(with: match.range(at: 2))) ?? 0
                : 0
        let sec = match.range(at: 3).location != NSNotFound
                ? Double(nsString.substring(with: match.range(at: 3))) ?? 0
                : 0
        let dir = match.range(at: 4).location != NSNotFound
                ? nsString.substring(with: match.range(at: 4))
                : "E"

        var result = deg
        result += min / 60
        result += sec / 3600
        if ["S","W"].contains(dir.uppercased()) {
            result = -result
        }
        return result.cap(limit: limit)
    } else {
        throw ConvetionError.invalidInput
    }
}

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
