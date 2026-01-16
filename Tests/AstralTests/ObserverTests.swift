//
//  ObserverTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Testing
@testable import Astral

@Suite("Observer Tests", .tags(.coordinate, .validation, .fast))
struct ObserverTests {

  @Test("Create observer from string coordinates", .tags(.unit))
  func fromString() throws {
    let obs = try Observer(latitude: "1", longitude: "2", elevation: .double(0))
    #expect(obs.latitude == 1.0)
    #expect(obs.longitude == 2.0)
    #expect(obs.elevation == .double(0))
  }

  @Test("Create observer from DMS coordinates", .tags(.unit))
  func fromDMS() throws {
    let obs = try Observer(latitude: "24°N", longitude: "22°30'S", elevation: .double(0))
    #expect(obs.latitude == 24.0)
    #expect(obs.longitude == -22.5)
    #expect(obs.elevation == .double(0))
  }

  @Test("Invalid latitude throws error", .tags(.unit, .edge))
  func badLatitude() {
    #expect(throws: (any Error).self) {
      try Observer(latitude: "o", longitude: "1", elevation: .double(0))
    }
  }

  @Test("Invalid longitude throws error", .tags(.unit, .edge))
  func badLongitude() {
    #expect(throws: (any Error).self) {
      try Observer(latitude: "1", longitude: "o", elevation: .double(0))
    }
  }

  @Test("Latitude is clamped to valid range", .tags(.unit, .edge))
  func latitudeOutsideLimits() {
    var obs = Observer(latitude: 90.1, longitude: 0, elevation: .double(0))
    #expect(obs.latitude == 90.0)
    obs = Observer(latitude: -90.1, longitude: 0, elevation: .double(0))
    #expect(obs.latitude == -90.0)
  }

  @Test("Longitude is clamped to valid range", .tags(.unit, .edge))
  func longitudeOutsideLimits() {
    var obs = Observer(latitude: 0, longitude: 180.1, elevation: .tuple(0,0))
    #expect(obs.longitude == 180.0)
    obs = Observer(latitude: 0, longitude: -180.1, elevation: .double(0))
    #expect(obs.longitude == -180.0)
  }

}
