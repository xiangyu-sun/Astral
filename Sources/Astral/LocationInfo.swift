//
//  LocationInfo.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import CoreLocation

/// Defines a location on Earth.
///    Latitude and longitude can be set either as a float or as a string.
///    For strings they must be of the form
///        degrees°minutes'seconds"[N|S|E|W] e.g. 51°31'N
///    `minutes’` & `seconds”` are optional.
///    Args:
///        name:       Location name (can be any string)
///        region:     Region location is in (can be any string)
///        timezone:   The location's time zone (a list of time zone names can be
///                    obtained from `zoneinfo.available_timezones`)
///        latitude:   Latitude - Northern latitudes should be positive
///        longitude:  Longitude - Eastern longitudes should be positive
public struct LocationInfo {

  // MARK: Lifecycle

  public init(name: String, region: String, timezone: String, latitudeStr: String, longitudeStr: String) throws {
    let lat = try convertDegreesMinutesSecondsToDouble(value: latitudeStr, limit: 90)

    let long = try convertDegreesMinutesSecondsToDouble(value: longitudeStr, limit: 180)

    self.name = name
    self.region = region
    self.timezone = TimeZone(identifier: timezone) ?? .current
    latitude = lat
    longitude = long
  }

  public init(name: String, region: String, timezone: TimeZone, latitude: Degrees, longitude: Degrees) {
    self.name = name
    self.region = region
    self.timezone = timezone
    self.latitude = latitude.cap(limit: 90)
    self.longitude = longitude.cap(limit: 180)
  }

  // MARK: Internal

  public let name: String
  public let region: String
  public let timezone: TimeZone
  public let latitude: Degrees
  public let longitude: Degrees

  public var observer: Observer {
    .init(latitude: latitude, longitude: longitude, elevation: .double(0))
  }

  public var timezoneGroup: String? {
    String(timezone.identifier.split(separator: "/").first ?? "")
  }
}
