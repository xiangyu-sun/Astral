//
//  LocationInfoTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
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
  func timezoneGroup() throws {
    // A fixed zone: `.current` made this depend on the machine's time zone (CI runs in GMT).
    let timezone = try #require(TimeZone(identifier: "Europe/London"))
    let li = LocationInfo(name: "", region: "", timezone: timezone, latitude: 0, longitude: 0)
    #expect(li.timezoneGroup == "Europe")
  }

}
