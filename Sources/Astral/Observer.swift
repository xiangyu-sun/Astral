//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation
import CoreLocation

/**
 Defines the location of an observer on Earth.
     Latitude and longitude can be set either as a float or as a string.
     For strings they must be of the form
         degrees°minutes'seconds"[N|S|E|W] e.g. 51°31'N
     `minutes’` & `seconds”` are optional.
     Elevations are either
     * A float that is the elevation in metres above a location, if the nearest
       obscuring feature is the horizon
     * or a tuple of the elevation in metres and the distance in metres to the
       nearest obscuring feature.
     Args:
         latitude:   Latitude - Northern latitudes should be positive
         longitude:  Longitude - Eastern longitudes should be positive
         elevation:  Elevation and/or distance to nearest obscuring feature
                     in metres above/below the location.
 */
struct Observer {
  let coordinate2D: CLLocationCoordinate2D
  let elevation: Elevation?
  let elevation2D: Elevation2D?
  
  init(coordinate2D: CLLocationCoordinate2D, elevation: Elevation) {
    self.coordinate2D = coordinate2D
    self.elevation = elevation
    self.elevation2D = nil
  }
  
  init(coordinate2D: CLLocationCoordinate2D, elevation: Elevation2D) {
    self.coordinate2D = coordinate2D
    self.elevation2D = elevation
    self.elevation = nil
  }
  
  init(latitude: String, longitude: String, elevation: Elevation) {
    let lat = convertDegreesMinutesSecondsToDouble(value: latitude, limit: 90)
    let long = convertDegreesMinutesSecondsToDouble(value: longitude, limit: 180)
    
    self.coordinate2D = .init(latitude: lat, longitude: long)
    self.elevation = elevation
    self.elevation2D = nil
  }
  
  init(latitude: String, longitude: String, elevation: Elevation2D) {
    let lat = convertDegreesMinutesSecondsToDouble(value: latitude, limit: 90)
    let long = convertDegreesMinutesSecondsToDouble(value: longitude, limit: 180)
    
    self.coordinate2D = .init(latitude: lat, longitude: long)
    self.elevation2D = elevation
    self.elevation = nil
  }
}
