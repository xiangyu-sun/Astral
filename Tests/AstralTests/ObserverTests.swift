//
//  ObserverTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Observer Tests")
struct ObserverTests {

  @Test("Observer from string coordinates")
  func test_from_string() throws {
    let obs = try Observer(latitude: "1", longitude: "2", elevation: .double(0))
    #expect(obs.latitude == 1.0)
    #expect(obs.longitude == 2.0)
    #expect(obs.elevation == .double(0))
  }

  @Test("Observer from DMS coordinates")
  func test_from_dms() throws {
    let obs = try Observer(latitude: "24°N", longitude: "22°30'S", elevation: .double(0))
    #expect(obs.latitude == 24.0)
    #expect(obs.longitude == -22.5)
    #expect(obs.elevation == .double(0))
  }

  @Test("Observer with bad latitude")
  func test_bad_latitude() {
    #expect(throws: (any Error).self) {
      try Observer(latitude: "o", longitude: "1", elevation: .double(0))
    }
  }

  @Test("Observer with bad longitude")
  func test_bad_longitude() {
    #expect(throws: (any Error).self) {
      try Observer(latitude: "1", longitude: "o", elevation: .double(0))
    }
  }

  @Test("Observer latitude outside limits")
  func test_latitude_outside_limits() {
    var obs = Observer(latitude: 90.1, longitude: 0, elevation: .double(0))
    #expect(obs.latitude == 90.0)
    obs = Observer(latitude: -90.1, longitude: 0, elevation: .double(0))
    #expect(obs.latitude == -90.0)
  }

  @Test("Observer longitude outside limits")
  func test_longitude_outside_limits() {
    var obs = Observer(latitude: 0, longitude: 180.1, elevation: .tuple(0,0))
    #expect(obs.longitude == 180.0)
    obs = Observer(latitude: 0, longitude: -180.1, elevation: .double(0))
    #expect(obs.longitude == -180.0)
  }

}
