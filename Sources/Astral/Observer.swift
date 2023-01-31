//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import CoreLocation
import Foundation

/// Defines the location of an observer on Earth.
///    Latitude and longitude can be set either as a float or as a string.
///    For strings they must be of the form
///        degrees°minutes'seconds"[N|S|E|W] e.g. 51°31'N
///    `minutes’` & `seconds”` are optional.
///    Elevations are either
///    * A float that is the elevation in metres above a location, if the nearest
///      obscuring feature is the horizon
///    * or a tuple of the elevation in metres and the distance in metres to the
///      nearest obscuring feature.
///    Args:
///        latitude:   Latitude - Northern latitudes should be positive
///        longitude:  Longitude - Eastern longitudes should be positive
///        elevation:  Elevation and/or distance to nearest obscuring feature
///                    in metres above/below the location.
struct Observer {

  // MARK: Lifecycle

  init(latitude: Degrees, longitude: Degrees, elevation: Elevation) {
    self.latitude = latitude.cap(limit: 90)
    self.longitude = longitude.cap(limit: 180)
    self.elevation = elevation
  }

  init(latitude: String, longitude: String, elevation: Elevation) throws {
    let lat = try convertDegreesMinutesSecondsToDouble(value: latitude, limit: 90)
    let long = try convertDegreesMinutesSecondsToDouble(value: longitude, limit: 180)

    self.latitude = lat
    self.longitude = long
    self.elevation = elevation
  }

  // MARK: Internal

  static let london = Observer(latitude: 51.509865, longitude: -0.118092, elevation: .double(0))
  static let new_dheli = Observer(latitude: 28.6139, longitude: 77.2090, elevation: .double(0))
  static let riyadh = Observer(latitude: 25, longitude: 46.7, elevation: .double(620))
  static let welllington = try! Observer(
    latitude: " 41° 17' 11.256'' S",
    longitude: "174° 46' 34.4496'' E",
    elevation: .double(13.000))
  static let barcelona = try! Observer(latitude: "41° 23' 24.7380'' N", longitude: "2° 9' 14.4252'' E", elevation: .double(0))

  let latitude: Degrees
  let longitude: Degrees
  let elevation: Elevation
}
