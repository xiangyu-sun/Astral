//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 19/1/23.
//

import CoreLocation

/**
 Defines a location on Earth.
     Latitude and longitude can be set either as a float or as a string.
     For strings they must be of the form
         degrees°minutes'seconds"[N|S|E|W] e.g. 51°31'N
     `minutes’` & `seconds”` are optional.
     Args:
         name:       Location name (can be any string)
         region:     Region location is in (can be any string)
         timezone:   The location's time zone (a list of time zone names can be
                     obtained from `zoneinfo.available_timezones`)
         latitude:   Latitude - Northern latitudes should be positive
         longitude:  Longitude - Eastern longitudes should be positive
 */
struct LocationInfo {
  let name: String
  let region: String
  let timezone: TimeZone
  private var coordinate: CLLocationCoordinate2D
  
  
  var latitudeStr: String {
    didSet {
      let lat = convertDegreesMinutesSecondsToDouble(value: latitudeStr, limit: 90)
      coordinate.latitude = lat
    }
  }
  
  var longitudeStr: String {
    didSet {
      let lat = convertDegreesMinutesSecondsToDouble(value: longitudeStr, limit: 180)
      coordinate.longitude = lat
    }
  }
  
  var observer: Observer {
    .init(coordinate2D: self.coordinate, elevation: 0)
  }
  
  var timezoneGroup: String? {
    String(self.timezone.identifier.split(separator: "/").first ?? "")
  }
}
