//
//  SideRealTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Sidereal Time Tests")
struct SideRealTests {

  @Test("Greenwich Mean Sidereal Time for 1987")
  func gmstYear1987() {
    let dt = DateComponents.datetime(1987, 4, 10, 0, 0, 0)
    let meanSiderealTime = gmst(dateComponents: dt)

    let t = from(hours: meanSiderealTime / 15)
    #expect(t.hour == 13)
    #expect(t.minute == 10)
    #expect(t.second == 46)
    #expect(t.nanosecond == 1320558504769)
  }

  @Test("Greenwich Mean Sidereal Time for 2022")
  func gmstYear2022() {
    let dt = DateComponents.datetime(2022, 4, 10, 0, 0, 0)
    let meanSiderealTime = gmst(dateComponents: dt)

    let t = from(hours: meanSiderealTime / 15)
    #expect(t.hour == 13)
    #expect(t.minute == 12)
    #expect(t.second == 50)
    #expect(t.nanosecond == 695835024107)
  }

  @Test("Greenwich Mean Sidereal Time with time component")
  func gmstWithTime() {
    let dt = DateComponents.datetime(1987, 4, 10, 19, 21, 0)
    let meanSiderealTime = gmst(dateComponents: dt)
    let t = from(hours: meanSiderealTime / 15)
    #expect(t.hour == 8)
    #expect(t.minute == 34)
    #expect(t.second == 57)
    #expect(t.nanosecond == 322483102981)
  }

  @Test("Local Mean Sidereal Time")
  func localMeanSiderealTime() {
    let dt = DateComponents.datetime(1987, 4, 10, 0, 0, 0)
    let meanSiderealTime = lmst(dateComponents: dt, longitude: -0.13)
    #expect(meanSiderealTime == 197.693195090862 - 0.13)
  }
}
