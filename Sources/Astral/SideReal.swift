//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

/// Calculate Greenwich Mean Sidereal Time in degrees
/// https://lweb.cfa.harvard.edu/~jzhao/times.html
/// - Parameter dateComponents: <#dateComponents description#>
/// - Returns: <#description#>
func gmst(dateComponents: DateComponents) -> Degrees {
  let jd2000 = julianDay2000(at: dateComponents)

  let t0 = jd2000 / 36525

  let value = (
    280.46061837
      + 360.98564736629 * jd2000
      + 0.000387933 * pow(t0, 2)
      + pow(t0, 3) / 38710000)

  var r = value.truncatingRemainder(dividingBy: 360)
  if r.sign == .minus {
    r += 360
  }
  return r
}

/// Local Mean Sidereal Time for longitude in degrees
///    Args:
///        jd2000: Julian day
///        longitude: Longitude in degrees
func lmst(dateComponents: DateComponents, longitude: Degrees) -> Degrees {
  var mst = gmst(dateComponents: dateComponents)
  mst += longitude
  return mst
}
