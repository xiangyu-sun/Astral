//
//  DMSTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Testing
@testable import Astral

@Suite("DMS (Degrees-Minutes-Seconds) Conversion Tests")
struct DMSTests {

  @Test("Convert DMS north coordinate")
  func north() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "24°28'N", limit: 90)
    #expect(abs(result - 24.466666) < 0.1)
  }

  @Test("Convert whole number of degrees")
  func wholeNumberOfDegrees() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "24°", limit: 90.0)
    #expect(result == 24.0)
  }

  @Test("Convert DMS east coordinate")
  func east() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "54°22'E", limit: 180.0)
    #expect(abs(result - 54.366666) < 0.00001)
  }

  @Test("Convert DMS south coordinate")
  func south() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "37°58'S", limit: 90.0)
    #expect(abs(result - -37.966666) < 0.00001)
  }

  @Test("Convert DMS west coordinate")
  func west() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "171°50'W", limit: 180.0)
    #expect(abs(result - -171.8333333) < 0.00001)
  }

  @Test("Convert DMS west coordinate (lowercase)")
  func westLowercase() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "171°50'w", limit: 180.0)
    #expect(abs(result - -171.8333333) < 0.00001)
  }

  @Test("Convert float string")
  func floatString() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "0.2", limit: 90.0)
    #expect(result == 0.2)
  }

  @Test("Invalid string throws error")
  func notAFloat() {
    #expect(throws: (any Error).self) {
      try convertDegreesMinutesSecondsToDouble(value: "x", limit: 90.0)
    }
  }

  @Test("Coordinate outside limit is clamped")
  func latLngOutsideLimit() throws {
    let result = try convertDegreesMinutesSecondsToDouble(value: "180°50'w", limit: 180.0)
    #expect(result == -180)
  }

}
