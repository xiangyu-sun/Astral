//
//  LocationInfoTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Testing
@testable import Astral

@Suite("LocationInfo Tests")
struct LocationInfoTests {

  @Test("Invalid latitude throws error")
  func badLatitude() {
    #expect(throws: (any Error).self) {
      try LocationInfo(
        name: "A place",
        region: "Somewhere",
        timezone: "Europe/London",
        latitudeStr: "i",
        longitudeStr: "2")
    }
  }

  @Test("Invalid longitude throws error")
  func badLongitude() {
    #expect(throws: (any Error).self) {
      try LocationInfo(
        name: "A place",
        region: "Somewhere",
        timezone: "Europe/London",
        latitudeStr: "2",
        longitudeStr: "i")
    }
  }

  @Test("Timezone group extraction")
  func timezoneGroup() {
    let li = LocationInfo(name: "", region: "", timezone: .current, latitude: 0, longitude: 0)
    #expect(li.timezoneGroup == "Europe")
  }

}
